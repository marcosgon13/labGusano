#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/err.h>

#define MAGIC 0x574F524D

void handle_errors() {
    ERR_print_errors_fp(stderr);
    exit(EXIT_FAILURE);
}

int decrypt_file(const char *input_file, const char *output_file, EVP_PKEY *privkey) {
    FILE *fin = NULL, *fout = NULL;
    unsigned char *enc_key = NULL;
    uint32_t enc_key_len = 0;
    unsigned char iv[16];
    EVP_PKEY_CTX *ctx = NULL;
    unsigned char *aes_key = NULL;
    size_t aes_key_len;
    int ret = -1;

    fin = fopen(input_file, "rb");
    if (!fin) {
        perror("fopen input");
        return -1;
    }

    // Leer y validar cabecera
    uint32_t magic, stored_keylen;
    uint16_t version, flags;
    if (fread(&magic, 4, 1, fin) != 1) goto format_error;
    if (fread(&version, 2, 1, fin) != 1) goto format_error;
    if (fread(&flags, 2, 1, fin) != 1) goto format_error;
    if (fread(&stored_keylen, 4, 1, fin) != 1) goto format_error;

    magic = ntohl(magic);
    version = ntohs(version);
    stored_keylen = ntohl(stored_keylen);

    if (magic != MAGIC) {
        fprintf(stderr, "Error: formato no reconocido (magic inválido)\n");
        goto cleanup;
    }
    if (version != 1) {
        fprintf(stderr, "Error: versión de formato no soportada\n");
        goto cleanup;
    }
    if (stored_keylen != 256) { // RSA-2048 OAEP siempre 256 bytes
        fprintf(stderr, "Error: tamaño de clave cifrada incorrecto (esperado 256, leído %u)\n", stored_keylen);
        goto cleanup;
    }
    enc_key_len = stored_keylen;

    enc_key = OPENSSL_malloc(enc_key_len);
    if (!enc_key) {
        perror("OPENSSL_malloc");
        goto cleanup;
    }
    if (fread(enc_key, 1, enc_key_len, fin) != enc_key_len) goto format_error;
    if (fread(iv, 1, 16, fin) != 16) goto format_error;

    // Descifrar clave AES con RSA-OAEP SHA-256
    ctx = EVP_PKEY_CTX_new(privkey, NULL);
    if (!ctx) handle_errors();
    if (EVP_PKEY_decrypt_init(ctx) <= 0) handle_errors();
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) <= 0) handle_errors();
    if (EVP_PKEY_CTX_set_rsa_oaep_md(ctx, EVP_sha256()) <= 0) handle_errors();
    if (EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, EVP_sha256()) <= 0) handle_errors();

    // Obtener tamaño del buffer para clave descifrada
    if (EVP_PKEY_decrypt(ctx, NULL, &aes_key_len, enc_key, enc_key_len) <= 0) handle_errors();
    aes_key = OPENSSL_malloc(aes_key_len);
    if (!aes_key) {
        perror("OPENSSL_malloc");
        goto cleanup;
    }
    if (EVP_PKEY_decrypt(ctx, aes_key, &aes_key_len, enc_key, enc_key_len) <= 0) {
        fprintf(stderr, "Error descifrando clave AES (¿clave privada incorrecta?)\n");
        goto cleanup;
    }
    EVP_PKEY_CTX_free(ctx);
    ctx = NULL;

    // Descifrar datos con AES-256-CBC
    fout = fopen(output_file, "wb");
    if (!fout) {
        perror("fopen output");
        goto cleanup;
    }

    EVP_CIPHER_CTX *cipher_ctx = EVP_CIPHER_CTX_new();
    if (!cipher_ctx) handle_errors();
    if (!EVP_DecryptInit_ex(cipher_ctx, EVP_aes_256_cbc(), NULL, aes_key, iv)) handle_errors();

    unsigned char inbuf[4096];
    unsigned char outbuf[4096 + EVP_MAX_BLOCK_LENGTH];
    int inlen, outlen;
    while ((inlen = fread(inbuf, 1, sizeof(inbuf), fin)) > 0) {
        if (!EVP_DecryptUpdate(cipher_ctx, outbuf, &outlen, inbuf, inlen)) handle_errors();
        fwrite(outbuf, 1, outlen, fout);
    }
    if (!EVP_DecryptFinal_ex(cipher_ctx, outbuf, &outlen)) {
        fprintf(stderr, "Error en el descifrado final (posible corruptción o contraseña incorrecta)\n");
        EVP_CIPHER_CTX_free(cipher_ctx);
        goto cleanup;
    }
    fwrite(outbuf, 1, outlen, fout);
    EVP_CIPHER_CTX_free(cipher_ctx);

    ret = 0;
    goto cleanup;

format_error:
    fprintf(stderr, "Error de formato en fichero .enc\n");
cleanup:
    if (enc_key) {
        OPENSSL_cleanse(enc_key, enc_key_len);
        OPENSSL_free(enc_key);
    }
    if (aes_key) {
        OPENSSL_cleanse(aes_key, aes_key_len);
        OPENSSL_free(aes_key);
    }
    if (ctx) EVP_PKEY_CTX_free(ctx);
    if (fin) fclose(fin);
    if (fout) fclose(fout);
    return ret;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Uso: %s <fichero.enc> <clave_privada.pem>\n", argv[0]);
        return EXIT_FAILURE;
    }

    OpenSSL_add_all_algorithms();
    ERR_load_crypto_strings();

    FILE *fp = fopen(argv[2], "r");
    if (!fp) {
        perror("fopen private key");
        return EXIT_FAILURE;
    }
    EVP_PKEY *privkey = PEM_read_PrivateKey(fp, NULL, NULL, NULL);
    fclose(fp);
    if (!privkey) {
        fprintf(stderr, "Error leyendo clave privada\n");
        return EXIT_FAILURE;
    }

    // Nombre de salida: quitar .enc, si existe se sobreescribe (controlado en laboratorio)
    char outfile[1024];
    snprintf(outfile, sizeof(outfile), "%s", argv[1]);
    size_t len = strlen(outfile);
    if (len > 4 && strcmp(outfile + len - 4, ".enc") == 0) {
        outfile[len - 4] = '\0';
    } else {
        fprintf(stderr, "El fichero de entrada no tiene extensión .enc\n");
        EVP_PKEY_free(privkey);
        return EXIT_FAILURE;
    }

    if (decrypt_file(argv[1], outfile, privkey) != 0) {
        fprintf(stderr, "Fallo en el descifrado\n");
        EVP_PKEY_free(privkey);
        return EXIT_FAILURE;
    }

    EVP_PKEY_free(privkey);
    printf("[+] Fichero descifrado correctamente: %s\n", outfile);
    return EXIT_SUCCESS;
}
