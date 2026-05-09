#!/bin/bash

# Colores para la terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pause() {
    echo ""
    read -p "Presiona Enter para continuar..." dummy
}

clean_demo() {
    echo -e "${YELLOW}[*] Limpiando ficheros de demo anterior...${NC}"
    rm -f files_to_encrypt/*.enc
    rm -f files_to_encrypt/*.txt.enc
    rm -f files_to_encrypt/*.pdf.enc
    rm -f files_to_encrypt/*.docx.enc
    rm -f /tmp/victima /tmp/ransom_note.txt
    # Restaurar originales desde backup si existen
    if [ -d files_to_encrypt.backup ]; then
        cp files_to_encrypt.backup/* files_to_encrypt/
    fi
}

# Simula la creación de ficheros de ejemplo
create_test_files() {
    mkdir -p files_to_encrypt
    echo "Informe confidencial: nooCristinoPorElCuloNo" > files_to_encrypt/informe.txt
    echo "Contrato de confidencialidad firmado" > files_to_encrypt/contrato.pdf
    echo "Notas clínicas del paciente 4523" > files_to_encrypt/notas_clinicas.txt
    echo "Propuesta de fusión con ACME Corp" > files_to_encrypt/secreto_empresa.docx
    mkdir -p files_to_encrypt.backup
    cp files_to_encrypt/* files_to_encrypt.backup/
}

# Generar par de claves si no existen
generate_keys() {
    if [ ! -f keys/public.pem ] || [ ! -f keys/private.pem ]; then
        echo -e "${BLUE}[+] Generando par de claves RSA-2048 (atacante)...${NC}"
        make keys
    fi
}

# Simula la propagación del gusano cifrando múltiples ficheros
simulate_worm() {
    echo -e "${RED}[!] El gusano comienza a cifrar ficheros en 'files_to_encrypt/' ...${NC}"
    for file in files_to_encrypt/*; do
        if [[ "$file" != *.enc ]]; then
            echo -e "    Cifrando ${YELLOW}$file${NC}"
            bin/encrypt "$file" keys/public.pem
            # Borrar original simulando que el gusano lo elimina
            rm "$file"
        fi
    done
    # También cifra en /tmp/victima (simulando otro directorio)
    mkdir -p /tmp/victima
    echo "Fichero en otro directorio: datos_financieros.csv" > /tmp/victima/datos.csv
    bin/encrypt /tmp/victima/datos.csv keys/public.pem
    rm /tmp/victima/datos.csv
}

# Genera una nota de rescate falsa con ID único
generate_ransom_note() {
    HOST_ID=$(cat /etc/hostname 2>/dev/null || echo "victima-$(date +%s)")
    echo -e "${RED}===========================================${NC}"
    echo -e "${RED}          ¡TUS FICHEROS HAN SIDO CIFRADOS!${NC}"
    echo -e "${RED}===========================================${NC}"
    echo ""
    echo "No intentes recuperarlos sin nuestra clave privada."
    echo "Para recuperarlos, envía 0.5 BTC a la dirección:"
    echo "  1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
    echo "Luego contacta con tu ID de víctima: $HOST_ID"
    echo ""
    echo "Si no pagas en 72 horas, la clave privada será destruida."
    echo ""
    echo -e "${RED}===========================================${NC}"
    # Guardar en fichero (simula nota dejada por el gusano)
    echo "ID: $HOST_ID" > /tmp/ransom_note.txt
    echo "BTC: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa" >> /tmp/ransom_note.txt
}

# Muestra el aspecto ilegible con xxd
show_encrypted_sample() {
    local sample=$(ls files_to_encrypt/*.enc 2>/dev/null | head -1)
    if [ -z "$sample" ]; then
        sample=$(ls /tmp/victima/*.enc 2>/dev/null | head -1)
    fi
    if [ -n "$sample" ]; then
        echo -e "${BLUE}--- Muestra del fichero cifrado (primeros 128 bytes) ---${NC}"
        xxd -l 128 "$sample"
    fi
}

# Simula el pago del rescate y la recuperación
simulate_payment_and_recovery() {
    echo -e "${GREEN}[+] La víctima ha pagado el rescate (simulación).${NC}"
    echo -e "${GREEN}[+] Recibe la clave privada del atacante...${NC}"
    sleep 1
    echo "Descifrando ficheros..."
    for encfile in files_to_encrypt/*.enc /tmp/victima/*.enc; do
        if [ -f "$encfile" ]; then
            echo -e "    Recuperando ${YELLOW}$encfile${NC}"
            bin/decrypt "$encfile" keys/private.pem
        fi
    done
}

# Verifica que los ficheros coinciden con los originales
verify_integrity() {
    echo ""
    echo -e "${BLUE}=== Verificación de integridad ===${NC}"
    for orig in files_to_encrypt.backup/*; do
        base=$(basename "$orig")
        recovered="files_to_encrypt/$base"
        if [ -f "$recovered" ]; then
            if diff -q "$orig" "$recovered" >/dev/null; then
                echo -e "  ${GREEN}[OK]${NC} $base recuperado correctamente."
            else
                echo -e "  ${RED}[ERROR]${NC} $base difiere del original."
            fi
        else
            echo -e "  ${YELLOW}[?]${NC} $base no encontrado (quizás no fue cifrado)."
        fi
    done
    # Verificar /tmp/victima
    if [ -f /tmp/victima/datos.csv ] && echo "Fichero en otro directorio: datos_financieros.csv" | diff -q /tmp/victima/datos.csv - >/dev/null; then
        echo -e "  ${GREEN}[OK]${NC} /tmp/victima/datos.csv recuperado."
    fi
}

# ------------------ MAIN DEMO INTERACTIVA ------------------
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   LAB RANSOMWORM - DEMOSTRACIÓN AVANZADA${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
clean_demo
create_test_files
generate_keys

pause

echo ""
echo -e "${YELLOW}[*] Paso 1: Preparación${NC}"
echo "Hemos creado ficheros de ejemplo que simularán los datos de una víctima."
ls -l files_to_encrypt/
echo -e "${YELLOW}Tamaños originales:${NC}"
wc -c files_to_encrypt/*
pause

echo ""
echo -e "${YELLOW}[*] Paso 2: El gusano se propaga y cifra${NC}"
simulate_worm
echo -e "${RED}[!] Los ficheros originales han sido borrados.${NC}"
echo "Contenido actual del directorio:"
ls -la files_to_encrypt/
ls -la /tmp/victima/
show_encrypted_sample
pause

echo ""
echo -e "${YELLOW}[*] Paso 3: Nota de rescate${NC}"
generate_ransom_note
pause

echo ""
echo -e "${YELLOW}[*] Paso 4: La víctima paga y recupera sus datos${NC}"
simulate_payment_and_recovery
echo ""
echo "Ficheros restaurados:"
ls -l files_to_encrypt/
ls -l /tmp/victima/
pause

echo ""
echo -e "${YELLOW}[*] Paso 5: Verificación de integridad${NC}"
verify_integrity
pause

echo ""
echo -e "${GREEN}[+] Demo completada.${NC}"
echo "Reflexión: sin la clave privada, los datos seguirían cifrados."
echo "Puedes realizar el lab de nuevo ejecutando: bash demo/run_demo.sh"
echo "Para salir del contenedor escribe 'exit'"