#!/usr/bin/env bash
# RansomWorm Lab v2.0 – Demo interactiva avanzada
# Laboratorio educativo de ciberseguridad

set -euo pipefail

# ── Rutas ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
VICTIMS_BASE="/tmp/lab_victims"
DASHBOARD_URL="http://localhost:5000/api/event"
DASHBOARD_ACTIVE=false

# ── Colores ────────────────────────────────────────────────
R='\033[0;31m'   # rojo
BR='\033[1;31m'  # rojo negrita
G='\033[0;32m'   # verde
BG='\033[1;32m'  # verde negrita
Y='\033[1;33m'   # amarillo
B='\033[0;34m'   # azul
BB='\033[1;34m'  # azul negrita
M='\033[0;35m'   # magenta
C='\033[0;36m'   # cian
W='\033[1;37m'   # blanco negrita
D='\033[2m'      # oscuro/dim
NC='\033[0m'     # reset

# ── Definición de máquinas víctima ────────────────────────
MACHINE_IDS=(contabilidad rrhh servidor direccion backup)
declare -A M_IP M_NAME M_OS M_VULN

M_IP[contabilidad]="192.168.1.10"
M_IP[rrhh]="192.168.1.15"
M_IP[servidor]="192.168.1.100"
M_IP[direccion]="192.168.1.25"
M_IP[backup]="192.168.1.50"

M_NAME[contabilidad]="PC-CONTABILIDAD"
M_NAME[rrhh]="PC-RRHH"
M_NAME[servidor]="SRV-PRINCIPAL"
M_NAME[direccion]="PC-DIRECCION"
M_NAME[backup]="NAS-BACKUP"

M_OS[contabilidad]="Windows 10 Pro"
M_OS[rrhh]="Windows 11 Pro"
M_OS[servidor]="Windows Server 2019"
M_OS[direccion]="Windows 10 Pro"
M_OS[backup]="Windows Server 2016"

M_VULN[contabilidad]="MS17-010 EternalBlue"
M_VULN[rrhh]="CVE-2021-34527 PrintNightmare"
M_VULN[servidor]="MS17-010 EternalBlue"
M_VULN[direccion]="CVE-2021-26855 ProxyLogon"
M_VULN[backup]="MS17-010 EternalBlue"

# Ficheros por máquina (nombre:contenido simulado)
get_machine_files() {
    case "$1" in
        contabilidad) echo "nominas_mayo_2024.xlsx facturas_Q1_2024.csv presupuesto_anual.docx cuentas_bancarias.txt" ;;
        rrhh)         echo "empleados_bd.sql contratos_laborales.pdf evaluaciones_2024.xlsx" ;;
        servidor)     echo "backup_db.sql web_config.xml passwords.kdb ssl_keys.tar usuarios.json" ;;
        direccion)    echo "plan_estrategico_2024.docx fusion_ACME_confidencial.pdf presupuesto_secreto.xlsx" ;;
        backup)       echo "backup_full_20240115.tar backup_incremental.tar.gz recovery_keys_OLD.txt credenciales_sistema.txt config_vpn.ovpn" ;;
    esac
}

get_file_content() {
    local machine="$1" fname="$2"
    echo "** FICHERO DE DEMOSTRACIÓN - LAB EDUCATIVO DE CIBERSEGURIDAD **"
    echo "Máquina: ${M_NAME[$machine]}  IP: ${M_IP[$machine]}"
    echo "Fichero: $fname"
    echo ""
    case "$fname" in
        nominas_mayo_2024.xlsx)
            echo "NÓMINAS MAYO 2024 - CONFIDENCIAL"
            echo "ID    | Empleado              | Departamento   | Salario EUR"
            echo "------|----------------------|----------------|------------"
            echo "E001  | García Martínez, J.  | Contabilidad   | 2.850,00"
            echo "E002  | López Fernández, M.  | RRHH           | 3.200,00"
            echo "E003  | Rodríguez Sánchez, P.| Dirección      | 5.400,00"
            ;;
        facturas_Q1_2024.csv)
            echo "Factura,Cliente,Importe,Fecha,Estado"
            echo "FAC-001,ACME Corp,15000.00,2024-01-15,PAGADA"
            echo "FAC-002,TechSolutions SL,8750.50,2024-02-03,PENDIENTE"
            echo "FAC-003,GlobalTrade SA,22300.00,2024-03-20,PAGADA"
            ;;
        empleados_bd.sql)
            echo "-- VOLCADO BASE DE DATOS RRHH - CONFIDENCIAL"
            echo "CREATE TABLE empleados (id INT, nombre VARCHAR(100), dni VARCHAR(10));"
            echo "INSERT INTO empleados VALUES (1,'Juan García','12345678A');"
            echo "INSERT INTO empleados VALUES (2,'María López','87654321B');"
            ;;
        backup_db.sql)
            echo "-- BACKUP COMPLETO BASE DE DATOS PRODUCCIÓN"
            echo "-- Fecha: $(date '+%Y-%m-%d')  Servidor: SRV-PRINCIPAL"
            echo "CREATE DATABASE produccion; USE produccion;"
            echo "CREATE TABLE usuarios (id INT PRIMARY KEY, email VARCHAR(100), pwd_hash VARCHAR(64));"
            echo "INSERT INTO usuarios VALUES (1,'admin@empresa.com','5e884898da...');"
            ;;
        passwords.kdb)
            echo "[KEEPASS DATABASE - BINARIO SIMULADO]"
            printf 'KeePass database v2.x\x00\xFF\xFE' 2>/dev/null || true
            echo "Contiene: credenciales VPN, servidores, bases de datos"
            ;;
        ssl_keys.tar)
            echo "[ARCHIVO TAR - CERTIFICADOS SSL SERVIDOR]"
            echo "server.key - clave privada RSA 4096 bits"
            echo "server.crt - certificado X.509"
            echo "ca-bundle.crt - cadena de autoridad"
            ;;
        recovery_keys_OLD.txt)
            echo "CLAVES DE RECUPERACIÓN - SISTEMA BACKUP (ANTIGUAS)"
            echo "Key-A: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
            echo "Key-B: YYYYY-YYYYY-YYYYY-YYYYY-YYYYY"
            echo "ATENCIÓN: Renovar antes de 2024-06-01"
            ;;
        credenciales_sistema.txt)
            echo "CREDENCIALES SISTEMAS INTERNOS"
            echo "NAS-Admin: backup_admin / [DEMO-NO-REAL]"
            echo "FTP-Server: ftpuser / [DEMO-NO-REAL]"
            echo "VPN-Gateway: vpnadmin / [DEMO-NO-REAL]"
            ;;
        *)
            echo "Contenido simulado de $fname"
            echo "Datos confidenciales de la empresa - DEMO"
            ;;
    esac
}

# ── Funciones auxiliares ───────────────────────────────────
send_event() {
    if $DASHBOARD_ACTIVE; then
        curl -s --connect-timeout 2 -X POST "$DASHBOARD_URL" \
             -H "Content-Type: application/json" \
             -d "$1" >/dev/null 2>&1 || true
    fi
}

send_log() {
    local level="$1" msg="$2"
    send_event "{\"type\":\"log\",\"level\":\"$level\",\"msg\":\"$msg\"}"
}

check_dashboard() {
    if curl -s --connect-timeout 1 http://localhost:5000 >/dev/null 2>&1; then
        DASHBOARD_ACTIVE=true
        echo -e "${BG}[+] Panel de control activo → http://localhost:5000${NC}"
    else
        echo -e "${Y}[*] Panel no encontrado. Demo solo en terminal.${NC}"
        echo -e "${D}    Lanza: python3 dashboard/app.py &   para activarlo${NC}"
    fi
}

pause() {
    local msg="${1:-Presiona Enter para continuar...}"
    echo ""
    echo -e "${D}──────────────────────────────────────────${NC}"
    read -rp "$(echo -e "${Y}  ⏎  $msg${NC}")" _
    echo ""
}

section() {
    local title="$1"
    echo ""
    echo -e "${BB}╔══════════════════════════════════════════════════════════════╗${NC}"
    printf "${BB}║${NC}  ${W}%-62s${NC}${BB}║${NC}\n" "$title"
    echo -e "${BB}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

typewrite() {
    local text="$1" delay="${2:-0.025}"
    local i
    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

loading_bar() {
    local label="$1" total="${2:-20}" delay="${3:-0.08}"
    printf "${C}    %-24s [${NC}" "$label"
    local i
    for ((i=0; i<total; i++)); do
        printf "${R}█${NC}"
        sleep "$delay"
    done
    echo -e "${C}] ${BG}LISTO${NC}"
}

extract_iv_hex() {
    local f="$1"
    # IV está en el fichero .enc a partir del byte 268 (4+2+2+4+256=268)
    xxd -s 268 -l 16 -p "$f" 2>/dev/null | tr -d '\n'
}

extract_enc_key_preview() {
    local f="$1"
    # Clave AES cifrada empieza en byte 12 (tras la cabecera de 12 bytes)
    xxd -s 12 -l 32 -p "$f" 2>/dev/null | tr -d '\n'
}

# ── BANNER ─────────────────────────────────────────────────
show_banner() {
    clear
    echo ""
    echo -e "${BR}"
    echo "  ██████╗  █████╗ ███╗   ██╗███████╗ ██████╗ ███╗   ███╗██╗    ██╗ ██████╗ ██████╗ ███╗   ███╗"
    echo "  ██╔══██╗██╔══██╗████╗  ██║██╔════╝██╔═══██╗████╗ ████║██║    ██║██╔═══██╗██╔══██╗████╗ ████║"
    echo "  ██████╔╝███████║██╔██╗ ██║███████╗██║   ██║██╔████╔██║██║ █╗ ██║██║   ██║██████╔╝██╔████╔██║"
    echo "  ██╔══██╗██╔══██║██║╚██╗██║╚════██║██║   ██║██║╚██╔╝██║██║███╗██║██║   ██║██╔══██╗██║╚██╔╝██║"
    echo "  ██║  ██║██║  ██║██║ ╚████║███████║╚██████╔╝██║ ╚═╝ ██║╚███╔███╔╝╚██████╔╝██║  ██║██║ ╚═╝ ██║"
    echo "  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝ ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝"
    echo -e "${NC}"
    echo -e "${W}                   ╔══════════════════════════════════════════╗${NC}"
    echo -e "${W}                   ║    LAB v2.0 — Demo Avanzada Interactiva  ║${NC}"
    echo -e "${W}                   ║    Criptografía de Ransomworms Reales    ║${NC}"
    echo -e "${W}                   ╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${D}  ⚠ Solo para entornos controlados de aprendizaje.${NC}"
    echo -e "${D}  ⚠ Criptografía real (AES-256 + RSA-2048). Propagación simulada.${NC}"
    echo ""
}

# ── FASE 0: INICIALIZACIÓN ─────────────────────────────────
phase_init() {
    section "FASE 0: INICIALIZACIÓN DEL ENTORNO"

    send_event '{"type":"reset"}'
    send_event '{"type":"phase","phase":"INIT","desc":"Inicializando entorno del laboratorio..."}'

    cd "$LAB_DIR"

    echo -e "${C}[*] Verificando dependencias...${NC}"
    for dep in gcc openssl xxd curl; do
        if command -v "$dep" >/dev/null 2>&1; then
            echo -e "    ${BG}[✓]${NC} $dep"
        else
            echo -e "    ${R}[✗]${NC} $dep no encontrado"
        fi
    done
    sleep 0.5

    echo ""
    echo -e "${C}[*] Compilando módulos criptográficos del gusano...${NC}"
    make all -s 2>/dev/null || make all
    loading_bar "Compilando encrypt.c" 15 0.04
    loading_bar "Compilando decrypt.c" 15 0.04

    echo ""
    echo -e "${B}[+] Generando par de claves RSA-2048 del atacante...${NC}"
    make keys -s 2>/dev/null || make keys
    loading_bar "Generando private.pem" 20 0.05
    loading_bar "Extrayendo public.pem"  20 0.05
    echo -e "    ${BG}[✓]${NC} Clave pública embebida en el payload del gusano"

    echo ""
    echo -e "${C}[*] Preparando ficheros víctima en 5 máquinas...${NC}"
    rm -rf "$VICTIMS_BASE"
    for mid in "${MACHINE_IDS[@]}"; do
        local_dir="$VICTIMS_BASE/${M_NAME[$mid]}"
        mkdir -p "$local_dir"
        for fname in $(get_machine_files "$mid"); do
            get_file_content "$mid" "$fname" > "$local_dir/$fname"
        done
        echo -e "    ${D}${M_NAME[$mid]}:${NC} $(get_machine_files "$mid" | wc -w) ficheros creados"
    done

    # Restaurar ficheros locales también
    rm -f files_to_encrypt/*.enc 2>/dev/null || true
    if [ -d files_to_encrypt.backup ]; then
        cp files_to_encrypt.backup/* files_to_encrypt/ 2>/dev/null || true
    fi

    echo ""
    echo -e "${BG}[✓] Entorno listo.${NC}"
    echo -e "    Víctimas: $(find "$VICTIMS_BASE" -type f | wc -l) ficheros en 5 máquinas"
    echo -e "    Claves RSA: keys/public.pem  keys/private.pem"
    if $DASHBOARD_ACTIVE; then
        echo -e "    Panel:  ${BB}http://localhost:5000${NC}"
    fi

    send_log "success" "Entorno inicializado. $(find "$VICTIMS_BASE" -type f | wc -l) ficheros en 5 máquinas."
}

# ── FASE 1: RECONOCIMIENTO ─────────────────────────────────
phase_recon() {
    section "FASE 1: RECONOCIMIENTO DE RED (Simulado)"

    send_event '{"type":"phase","phase":"RECON","desc":"Escaneando red 192.168.1.0/24 en busca de víctimas..."}'

    echo -e "${C}[*] El gusano ejecuta un escaneo SYN en la subred local...${NC}"
    echo -e "${D}    Objetivo: 192.168.1.0/24 (254 hosts)${NC}"
    echo ""

    # Scan animation
    local found=0
    for i in $(seq 1 254); do
        printf "\r${D}    Probando 192.168.1.%-3d ...${NC}" "$i"
        sleep 0.008
        # Mostrar hits en las IPs de las víctimas
        for mid in "${MACHINE_IDS[@]}"; do
            local last_octet="${M_IP[$mid]##*.}"
            if [ "$i" -eq "$last_octet" ]; then
                printf "\r    ${Y}192.168.1.%-3d${NC} → ${BR}[ABIERTO]${NC} SMB/445 detectado!\n" "$i"
                (( found += 1 ))
                send_event "{\"type\":\"machine_scan\",\"machine_id\":\"$mid\",
                    \"ip\":\"${M_IP[$mid]}\",\"name\":\"${M_NAME[$mid]}\",\"os\":\"${M_OS[$mid]}\"}"
                sleep 0.2
            fi
        done
    done
    echo ""

    echo ""
    echo -e "${Y}[!] Escaneo completado: ${BR}5 hosts vulnerables encontrados${NC}"
    echo ""

    # Tabla de resultados
    echo -e "${W}  ┌──────────────────┬──────────────────────┬──────────────────────┬──────────────────────────┐${NC}"
    echo -e "${W}  │ IP               │ Nombre               │ Sistema Operativo    │ Vulnerabilidad           │${NC}"
    echo -e "${W}  ├──────────────────┼──────────────────────┼──────────────────────┼──────────────────────────┤${NC}"
    for mid in "${MACHINE_IDS[@]}"; do
        printf "${W}  │${NC} %-16s ${W}│${NC} %-20s ${W}│${NC} %-20s ${W}│${NC} ${R}%-24s${NC} ${W}│${NC}\n" \
            "${M_IP[$mid]}" "${M_NAME[$mid]}" "${M_OS[$mid]}" "${M_VULN[$mid]}"
        send_event "{\"type\":\"machine_vulnerable\",\"machine_id\":\"$mid\",\"vuln\":\"${M_VULN[$mid]}\"}"
        sleep 0.1
    done
    echo -e "${W}  └──────────────────┴──────────────────────┴──────────────────────┴──────────────────────────┘${NC}"

    echo ""
    echo -e "${C}[ℹ]  ${W}NOTA EDUCATIVA:${NC}"
    echo -e "${D}     MS17-010 (EternalBlue) permite ejecución remota de código en SMB sin autenticación."
    echo -e "     Fue utilizado masivamente por WannaCry (2017) afectando a +200.000 sistemas.${NC}"

    send_log "warn" "5 máquinas vulnerables identificadas en 192.168.1.0/24"
}

# ── FASE 2: PROPAGACIÓN ────────────────────────────────────
phase_propagation() {
    section "FASE 2: PROPAGACIÓN — INFECCIÓN DE MÁQUINAS"

    send_event '{"type":"phase","phase":"PROPAGACIÓN","desc":"Explotando vulnerabilidades y copiando payload..."}'

    echo -e "${R}[!] El gusano comienza a explotar vulnerabilidades y replicarse...${NC}"
    echo ""

    for mid in "${MACHINE_IDS[@]}"; do
        local name="${M_NAME[$mid]}" ip="${M_IP[$mid]}" vuln="${M_VULN[$mid]}"

        echo -e "${Y}[*] Atacando ${W}$name${NC} ${D}($ip)${NC}"
        echo -e "    ${D}Vulnerabilidad: $vuln${NC}"
        sleep 0.3

        printf "    ${D}Enviando shellcode %-35s${NC}" "..."
        sleep 0.4
        echo -e " ${BG}[OK]${NC}"

        printf "    ${D}Shell remota obtenida %-33s${NC}" "..."
        sleep 0.3
        echo -e " ${BG}[OK]${NC}"

        printf "    ${D}Elevando privilegios (NT AUTHORITY\\SYSTEM) %-12s${NC}" "..."
        sleep 0.4
        echo -e " ${BG}[OK]${NC}"

        printf "    ${D}Copiando payload ransomworm %-28s${NC}" "..."
        sleep 0.3
        echo -e " ${BG}[OK]${NC}"

        echo -e "    ${BR}⚠  $name INFECTADO${NC}"
        echo ""

        send_event "{\"type\":\"machine_infected\",\"machine_id\":\"$mid\"}"
        sleep 0.5
    done

    echo -e "${BR}[!!!] 5/5 MÁQUINAS INFECTADAS${NC}"
    echo -e "${D}      El payload está activo y en espera de orden de cifrado.${NC}"

    send_log "critical" "5/5 máquinas infectadas. Payload activo."
}

# ── FASE 3: CIFRADO ────────────────────────────────────────
phase_encryption() {
    section "FASE 3: CIFRADO MASIVO DE FICHEROS"

    send_event '{"type":"phase","phase":"CIFRADO","desc":"AES-256-CBC + RSA-2048 OAEP — cifrando ficheros..."}'

    echo -e "${BR}[!] El gusano ejecuta el módulo de cifrado en todas las máquinas...${NC}"
    echo ""

    local total_files=0 enc_count=0

    for mid in "${MACHINE_IDS[@]}"; do
        local name="${M_NAME[$mid]}"
        local dir="$VICTIMS_BASE/$name"
        echo -e "${Y}[*] Cifrando ficheros en ${W}$name${NC} ${D}(${M_IP[$mid]})${NC}"

        for fname in $(get_machine_files "$mid"); do
            local fpath="$dir/$fname"
            [ -f "$fpath" ] || continue

            local fsize
            fsize=$(stat -c%s "$fpath" 2>/dev/null || echo 0)
            local fid="${mid}_${fname}"
            (( total_files += 1 ))

            send_event "{\"type\":\"file_start\",\"file_id\":\"$fid\",
                \"name\":\"$fname\",\"machine\":\"$name\",\"size\":$fsize}"

            printf "    ${D}Cifrando ${NC}${W}%-40s${NC}" "$fname"
            sleep 0.15

            # Cifrado real con AES-256-CBC + RSA-2048 OAEP
            if bin/encrypt "$fpath" keys/public.pem >/dev/null 2>&1; then
                rm -f "$fpath"
                local encpath="${fpath}.enc"
                local encsize
                encsize=$(stat -c%s "$encpath" 2>/dev/null || echo 0)
                (( enc_count += 1 ))
                echo -e " ${R}[CIFRADO]${NC} ${D}(+$(( encsize - fsize ))B overhead)${NC}"

                # Extraer IV real y preview de clave del fichero .enc
                local iv_hex enc_preview
                iv_hex=$(extract_iv_hex "$encpath")
                enc_preview=$(extract_enc_key_preview "$encpath")

                send_event "{\"type\":\"file_encrypted\",\"file_id\":\"$fid\",
                    \"name\":\"$fname\",\"enc_size\":$encsize}"
                send_event "{\"type\":\"crypto\",\"file\":\"$fname\",
                    \"iv_hex\":\"$iv_hex\",\"enc_key_preview\":\"$enc_preview\"}"
                sleep 0.05
            else
                echo -e " ${R}[ERROR]${NC}"
            fi
        done

        send_event "{\"type\":\"machine_encrypted\",\"machine_id\":\"$mid\"}"
        echo -e "    ${BR}✓ Todos los ficheros de $name cifrados${NC}"
        echo ""
        sleep 0.3
    done

    # Cifrar también los ficheros locales (files_to_encrypt/)
    echo -e "${Y}[*] Cifrando ficheros locales en ${W}PC-LOCAL${NC} ${D}(esta máquina)${NC}"
    for fpath in files_to_encrypt/*; do
        [[ "$fpath" == *.enc ]] && continue
        [ -f "$fpath" ] || continue
        local fname="${fpath##*/}"
        local fsize
        fsize=$(stat -c%s "$fpath" 2>/dev/null || echo 0)
        printf "    ${D}Cifrando ${NC}${W}%-40s${NC}" "$fname"
        if bin/encrypt "$fpath" keys/public.pem >/dev/null 2>&1; then
            rm -f "$fpath"
            echo -e " ${R}[CIFRADO]${NC}"
            (( enc_count += 1 ))
        else
            echo -e " ${R}[ERROR]${NC}"
        fi
    done
    echo ""

    echo -e "${BR}[!!!] CIFRADO COMPLETADO: $enc_count ficheros inutilizados${NC}"
    echo ""

    # Mostrar un ejemplo con xxd
    local sample_enc
    sample_enc=$(find "$VICTIMS_BASE" -name "*.enc" | head -1)
    if [ -n "$sample_enc" ]; then
        echo -e "${C}[ℹ] Muestra del fichero cifrado (primeros 96 bytes con cabecera):${NC}"
        echo -e "${D}    Formato: MAGIC(4) + VERSION(2) + FLAGS(2) + KEY_LEN(4) + ENC_KEY(256) + IV(16) + DATOS${NC}"
        xxd -l 96 "$sample_enc" | sed 's/^/    /'
        echo ""
        local iv_real
        iv_real=$(extract_iv_hex "$sample_enc")
        echo -e "${Y}[ℹ] IV (en claro en el header): ${W}$iv_real${NC}"
        echo -e "${D}    El IV se almacena en abierto porque se necesita para descifrar (no es secreto).${NC}"
        echo -e "${D}    La clave AES SÍ está cifrada con RSA-2048 OAEP. Sin la clave privada es irrecuperable.${NC}"
    fi

    send_log "critical" "Cifrado masivo completado: $enc_count ficheros."
}

# ── FASE 4: NOTA DE RESCATE ────────────────────────────────
phase_ransom() {
    section "FASE 4: NOTA DE RESCATE"

    send_event '{"type":"phase","phase":"RESCATE","desc":"Nota de rescate desplegada en todas las máquinas..."}'

    local victim_id
    victim_id="VICTIM-$(hostname 2>/dev/null || echo KALI)-$(date +%s | tail -c 8)"
    local btc="1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"

    send_event "{\"type\":\"ransom\",\"victim_id\":\"$victim_id\",\"btc\":\"$btc\"}"

    echo -e "${BR}"
    cat << 'RANSOM'

  ██████████████████████████████████████████████████████████████
  █                                                            █
  █    ☠  TUS FICHEROS HAN SIDO CIFRADOS  ☠                   █
  █                                                            █
  █  Todos tus documentos, bases de datos y archivos           █
  █  han sido cifrados con AES-256-CBC.                        █
  █                                                            █
  █  La clave AES está protegida con RSA-2048 OAEP.           █
  █  Sin nuestra clave privada, la recuperación es             █
  █                   I M P O S I B L E                        █
  █                                                            █
  ██████████████████████████████████████████████████████████████
RANSOM
    echo -e "${NC}"

    echo -e "${Y}  Para recuperar tus ficheros:"
    echo -e "  ──────────────────────────────────"
    echo -e "  Envía ${W}0.5 BTC${Y} a la dirección:"
    echo -e "  ${W}  $btc${NC}"
    echo ""
    echo -e "${Y}  Luego contacta con tu ID de víctima:"
    echo -e "  ${W}  $victim_id${NC}"
    echo ""
    echo -e "${BR}  ⚠ Si no pagas en 72 horas, la clave privada será destruida.${NC}"
    echo ""

    # Guardar nota en cada máquina
    for mid in "${MACHINE_IDS[@]}"; do
        cat > "$VICTIMS_BASE/${M_NAME[$mid]}/LEER-ESTO-AHORA.txt" << RNOTE
TUS FICHEROS HAN SIDO CIFRADOS

ID Victima: $victim_id
Enviar:     0.5 BTC
Direccion:  $btc
Plazo:      72 horas

RNOTE
    done

    echo -e "${D}[*] Nota de rescate guardada en cada máquina víctima.${NC}"
    send_log "critical" "Nota de rescate activa. ID: $victim_id — BTC: $btc"
}

# ── FASE 5: RECUPERACIÓN ───────────────────────────────────
phase_recovery() {
    section "FASE 5: RECUPERACIÓN (tras pago del rescate)"

    send_event '{"type":"phase","phase":"RECUPERACIÓN","desc":"Descifrado en curso con clave privada RSA..."}'
    send_event '{"type":"ransom_paid"}'

    echo -e "${BG}[+] La víctima ha pagado 0.5 BTC (simulación).${NC}"
    echo -e "${BG}[+] El atacante envía la clave privada RSA...${NC}"
    echo ""
    sleep 0.8

    echo -e "${C}[*] Descifrando ficheros en todas las máquinas...${NC}"
    echo ""

    for mid in "${MACHINE_IDS[@]}"; do
        local name="${M_NAME[$mid]}" dir="$VICTIMS_BASE/${M_NAME[$mid]}"
        echo -e "${Y}[*] Recuperando ${W}$name${NC}"

        for encpath in "$dir"/*.enc; do
            [ -f "$encpath" ] || continue
            local fname="${encpath%.enc}"
            fname="${fname##*/}"
            local fid="${mid}_${fname}"

            send_event "{\"type\":\"file_recovering\",\"file_id\":\"$fid\",\"name\":\"$fname\"}"
            printf "    ${D}Descifrando ${NC}${W}%-40s${NC}" "$fname"

            if bin/decrypt "$encpath" keys/private.pem >/dev/null 2>&1; then
                rm -f "$encpath"
                local fsize
                fsize=$(stat -c%s "$dir/$fname" 2>/dev/null || echo 0)
                echo -e " ${BG}[RECUPERADO]${NC}"
                send_event "{\"type\":\"file_recovered\",\"file_id\":\"$fid\",
                    \"name\":\"$fname\",\"size\":$fsize}"
            else
                echo -e " ${R}[ERROR]${NC}"
            fi
            sleep 0.1
        done

        send_event "{\"type\":\"machine_recovered\",\"machine_id\":\"$mid\"}"
        echo ""
    done

    # Recuperar ficheros locales
    echo -e "${Y}[*] Recuperando ${W}PC-LOCAL${NC}"
    for encpath in files_to_encrypt/*.enc; do
        [ -f "$encpath" ] || continue
        printf "    ${D}Descifrando ${NC}${W}%-40s${NC}" "${encpath##*/}"
        if bin/decrypt "$encpath" keys/private.pem >/dev/null 2>&1; then
            rm -f "$encpath"
            echo -e " ${BG}[RECUPERADO]${NC}"
        else
            echo -e " ${R}[ERROR]${NC}"
        fi
    done
    echo ""

    # Verificar integridad
    echo -e "${C}[*] Verificando integridad de ficheros recuperados...${NC}"
    echo ""
    local ok=0 fail=0
    for orig in files_to_encrypt.backup/*; do
        local base="${orig##*/}"
        local rec="files_to_encrypt/$base"
        if [ -f "$rec" ]; then
            if diff -q "$orig" "$rec" >/dev/null 2>&1; then
                echo -e "    ${BG}[OK]${NC} $base — idéntico al original"
                (( ok += 1 ))
            else
                echo -e "    ${BR}[DIFF]${NC} $base — difiere del original"
                (( fail += 1 ))
            fi
        fi
    done
    echo ""
    echo -e "${BG}[✓] Verificación completada: $ok ficheros perfectos, $fail con diferencias${NC}"

    send_log "success" "Recuperación completada. $ok ficheros restaurados sin pérdida."
}

# ── FASE 6: ANÁLISIS FORENSE ───────────────────────────────
phase_forensics() {
    section "FASE 6: ANÁLISIS FORENSE Y LECCIONES"

    send_event '{"type":"phase","phase":"FORENSE","desc":"Análisis de IoCs y medidas defensivas"}'

    echo -e "${W}INDICADORES DE COMPROMISO (IoCs) detectados:${NC}"
    echo ""
    echo -e "${R}  ● Ficheros .enc${NC} apareciendo masivamente (cifrado en proceso)"
    echo -e "${R}  ● Magic bytes WORM (0x574F524D)${NC} en cabecera de ficheros"
    echo -e "${R}  ● Actividad SMB anómala${NC} en red interna (propagación)"
    echo -e "${R}  ● Eliminación masiva de ficheros originales${NC}"
    echo -e "${R}  ● Fichero LEER-ESTO-AHORA.txt${NC} en cada directorio"
    echo ""

    echo -e "${W}TÉCNICAS MITRE ATT&CK utilizadas:${NC}"
    echo ""
    printf "  ${Y}%-8s${NC}  %-35s  %s\n" "T1486"  "Data Encrypted for Impact"     "Cifrado AES-256-CBC"
    printf "  ${Y}%-8s${NC}  %-35s  %s\n" "T1210"  "Exploitation of Remote Services""EternalBlue MS17-010"
    printf "  ${Y}%-8s${NC}  %-35s  %s\n" "T1021"  "Remote Services (SMB)"         "Propagación lateral"
    printf "  ${Y}%-8s${NC}  %-35s  %s\n" "T1083"  "File and Directory Discovery"  "Enumeración de ficheros"
    printf "  ${Y}%-8s${NC}  %-35s  %s\n" "T1070"  "Indicator Removal"             "Borrado de originales"
    echo ""

    echo -e "${W}COMPARATIVA CON RANSOMWORMS REALES:${NC}"
    echo ""
    echo -e "${W}  ┌──────────────────┬────────────────────┬────────────────────┬────────────────────┐${NC}"
    echo -e "${W}  │ Característica   │ Este Lab           │ WannaCry (2017)    │ REvil/Sodinokibi   │${NC}"
    echo -e "${W}  ├──────────────────┼────────────────────┼────────────────────┼────────────────────┤${NC}"
    printf "${W}  │${NC} %-16s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC}\n" \
        "Cifrado datos"   "AES-256-CBC"      "AES-128-CBC"      "AES-256-CBC"
    printf "${W}  │${NC} %-16s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC}\n" \
        "Protec. clave"   "RSA-2048 OAEP"    "RSA-2048 PKCS#1"  "RSA-2048"
    printf "${W}  │${NC} %-16s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC}\n" \
        "Propagación"     "Simulada"         "EternalBlue real" "RDP/phishing"
    printf "${W}  │${NC} %-16s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC}\n" \
        "Nota rescate"    "Txt + Dashboard"  ".wncry/.wncryt"   "HTML/TXT"
    printf "${W}  │${NC} %-16s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC} %-18s ${W}│${NC}\n" \
        "C2"              "No incluido"      "TOR"              "TOR"
    echo -e "${W}  └──────────────────┴────────────────────┴────────────────────┴────────────────────┘${NC}"
    echo ""

    echo -e "${W}MEDIDAS DEFENSIVAS:${NC}"
    echo ""
    echo -e "${BG}  ✓${NC} Parcheo inmediato de MS17-010 (publicado en marzo 2017)"
    echo -e "${BG}  ✓${NC} Backups offline (3-2-1: 3 copias, 2 medios, 1 offsite)"
    echo -e "${BG}  ✓${NC} Segmentación de red (evita propagación lateral)"
    echo -e "${BG}  ✓${NC} Deshabilitar SMBv1"
    echo -e "${BG}  ✓${NC} EDR/XDR: detección de cifrado masivo anómalo"
    echo -e "${BG}  ✓${NC} Principio de mínimo privilegio"
    echo ""

    send_log "success" "Análisis forense completado."
}

# ── MAIN ───────────────────────────────────────────────────
main() {
    show_banner
    check_dashboard

    echo -e "${D}Esta demo simula el ciclo completo de un ransomworm:${NC}"
    echo -e "${D}  reconocimiento → propagación → cifrado → rescate → recuperación${NC}"
    echo ""

    pause "Presiona Enter para comenzar la demo..."

    phase_init
    pause "Fase 0 completada. Presiona Enter para el escaneo de red..."

    phase_recon
    pause "Reconocimiento completado. Presiona Enter para iniciar la propagación..."

    phase_propagation
    pause "Máquinas infectadas. Presiona Enter para el cifrado masivo..."

    phase_encryption
    pause "Cifrado completado. Presiona Enter para ver la nota de rescate..."

    phase_ransom
    echo ""
    pause "¿Pagar el rescate? Presiona Enter para simular el pago y recuperar ficheros..."

    phase_recovery
    pause "Ficheros recuperados. Presiona Enter para el análisis forense..."

    phase_forensics

    send_event '{"type":"phase","phase":"COMPLETADA","desc":"Demo finalizada — todos los ficheros recuperados"}'
    echo ""
    echo -e "${BG}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BG}║   Demo completada exitosamente.                              ║${NC}"
    echo -e "${BG}║   La clave privada RSA es el único mecanismo de recuperación.║${NC}"
    echo -e "${BG}║   Sin ella: los datos cifrados son matemáticamente irrecu-   ║${NC}"
    echo -e "${BG}║   perables (AES-256 + RSA-2048 OAEP/SHA-256).                ║${NC}"
    echo -e "${BG}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${D}Para repetir: bash demo/run_demo.sh${NC}"
    echo -e "${D}Panel de control: http://localhost:5000${NC}"
    echo ""
}

main
