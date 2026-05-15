#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>   // htonl, htons
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <openssl/err.h>

#define AES_KEY_SIZE 32
#define AES_IV_SIZE  16
#define MAGIC        0x574F524D  // "WORM"

void handle_errors() {
    ERR_print_errors_fp(stderr);
    exit(EXIT_FAILURE);
}

int encrypt_file(const char *input_file, const char *output_file, EVP_PKEY *pubkey) {
    FILE *fin = NULL, *fout = NULL;
    unsigned char aes_key[AES_KEY_SIZE];
    unsigned char iv[AES_IV_SIZE];
    EVP_PKEY_CTX *ctx = NULL;
    unsigned char *enc_key = NULL;
    size_t enc_key_len = 0;
    int ret = -1;

    // 1. Generar clave AES y IV con CSPRNG
    if (!RAND_bytes(aes_key, sizeof(aes_key))) {
        fprintf(stderr, "Error generando clave AES\n");
        return -1;
    }
    if (!RAND_bytes(iv, sizeof(iv))) {
        fprintf(stderr, "Error generando IV\n");
        return -1;
    }

    // 2. Cifrar la clave AES con RSA-OAEP SHA-256
    ctx = EVP_PKEY_CTX_new(pubkey, NULL);
    if (!ctx) handle_errors();

    if (EVP_PKEY_encrypt_init(ctx) <= 0) handle_errors();
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) <= 0) handle_errors();
    if (EVP_PKEY_CTX_set_rsa_oaep_md(ctx, EVP_sha256()) <= 0) handle_errors();
    if (EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, EVP_sha256()) <= 0) handle_errors();

    // Determinar tamaño del buffer de salida
    if (EVP_PKEY_encrypt(ctx, NULL, &enc_key_len, aes_key, sizeof(aes_key)) <= 0) handle_errors();
    enc_key = OPENSSL_malloc(enc_key_len);
    if (!enc_key) {
        perror("OPENSSL_malloc");
        goto cleanup;
    }
    if (EVP_PKEY_encrypt(ctx, enc_key, &enc_key_len, aes_key, sizeof(aes_key)) <= 0) handle_errors();
    EVP_PKEY_CTX_free(ctx);
    ctx = NULL;

    // 3. Cifrar los datos con AES-256-CBC
    fin = fopen(input_file, "rb");
    if (!fin) {
        perror("fopen input");
        goto cleanup;
    }

    fout = fopen(output_file, "wb");
    if (!fout) {
        perror("fopen output");
        goto cleanup;
    }

    // Escribir cabecera
    uint32_t magic = htonl(MAGIC);
    uint16_t version = htons(1);
    uint16_t flags = 0;
    uint32_t key_blk_len = htonl((uint32_t)enc_key_len);
    fwrite(&magic, 4, 1, fout);
    fwrite(&version, 2, 1, fout);
    fwrite(&flags, 2, 1, fout);
    fwrite(&key_blk_len, 4, 1, fout);
    fwrite(enc_key, 1, enc_key_len, fout);
    fwrite(iv, 1, AES_IV_SIZE, fout);

    // Cifrado en streaming
    EVP_CIPHER_CTX *cipher_ctx = EVP_CIPHER_CTX_new();
    if (!cipher_ctx) handle_errors();
    if (!EVP_EncryptInit_ex(cipher_ctx, EVP_aes_256_cbc(), NULL, aes_key, iv)) handle_errors();

    unsigned char inbuf[4096];
    unsigned char outbuf[4096 + EVP_MAX_BLOCK_LENGTH];
    int inlen, outlen;
    while ((inlen = fread(inbuf, 1, sizeof(inbuf), fin)) > 0) {
        if (!EVP_EncryptUpdate(cipher_ctx, outbuf, &outlen, inbuf, inlen)) handle_errors();
        fwrite(outbuf, 1, outlen, fout);
    }
    if (!EVP_EncryptFinal_ex(cipher_ctx, outbuf, &outlen)) handle_errors();
    fwrite(outbuf, 1, outlen, fout);

    EVP_CIPHER_CTX_free(cipher_ctx);
    ret = 0;

cleanup:
    // Limpieza segura de material sensible
    OPENSSL_cleanse(aes_key, sizeof(aes_key));
    OPENSSL_cleanse(iv, sizeof(iv));
    if (enc_key) {
        OPENSSL_cleanse(enc_key, enc_key_len);
        OPENSSL_free(enc_key);
    }
    if (ctx) EVP_PKEY_CTX_free(ctx);
    if (fin) fclose(fin);
    if (fout) fclose(fout);
    return ret;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Uso: %s <fichero_a_cifrar> <clave_publica.pem>\n", argv[0]);
        return EXIT_FAILURE;
    }

    OpenSSL_add_all_algorithms();
    ERR_load_crypto_strings();

    FILE *fp = fopen(argv[2], "r");
    if (!fp) {
        perror("fopen public key");
        return EXIT_FAILURE;
    }
    EVP_PKEY *pubkey = PEM_read_PUBKEY(fp, NULL, NULL, NULL);
    fclose(fp);
    if (!pubkey) {
        fprintf(stderr, "Error leyendo clave pública\n");
        return EXIT_FAILURE;
    }

    // Construir nombre de salida: nombre_original + ".enc"
    char outfile[1024];
    snprintf(outfile, sizeof(outfile), "%s.enc", argv[1]);

    if (encrypt_file(argv[1], outfile, pubkey) != 0) {
        fprintf(stderr, "Fallo en el cifrado\n");
        EVP_PKEY_free(pubkey);
        return EXIT_FAILURE;
    }

    EVP_PKEY_free(pubkey);
    printf("[+] Fichero cifrado correctamente: %s\n", outfile);
    return EXIT_SUCCESS;
}