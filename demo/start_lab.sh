#!/usr/bin/env bash
# RansomWorm Lab v2.0 — Lanzador completo
# Arranca el dashboard y la demo de forma coordinada

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$LAB_DIR"

R='\033[0;31m'; BR='\033[1;31m'; G='\033[0;32m'; BG='\033[1;32m'
Y='\033[1;33m'; B='\033[0;34m'; BB='\033[1;34m'; W='\033[1;37m'
D='\033[2m'; NC='\033[0m'

DASHBOARD_PID=""

cleanup() {
    echo ""
    echo -e "${Y}[*] Cerrando panel de control...${NC}"
    if [ -n "$DASHBOARD_PID" ] && kill -0 "$DASHBOARD_PID" 2>/dev/null; then
        kill "$DASHBOARD_PID" 2>/dev/null || true
    fi
    # también matar cualquier proceso que ocupe el puerto 5000
    fuser -k 5000/tcp 2>/dev/null || true
    echo -e "${BG}[✓] Lab cerrado.${NC}"
}
trap cleanup EXIT INT TERM

echo ""
echo -e "${BR}  ╔═══════════════════════════════════════════╗${NC}"
echo -e "${BR}  ║   🦠  RANSOMWORM LAB v2.0 — LAUNCHER      ║${NC}"
echo -e "${BR}  ╚═══════════════════════════════════════════╝${NC}"
echo ""

# ── Verificar dependencias ─────────────────────────────────
echo -e "${B}[*] Verificando dependencias...${NC}"
missing=0
for dep in python3 gcc make openssl xxd curl; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo -e "    ${R}[✗] $dep no encontrado${NC}"
        (( missing += 1 ))
    fi
done
if [ "$missing" -gt 0 ]; then
    echo -e "${R}[-] Instala las dependencias antes de continuar.${NC}"
    echo -e "${D}    sudo apt install -y gcc libssl-dev xxd curl python3-flask${NC}"
    exit 1
fi
echo -e "    ${BG}[✓] Todas las dependencias disponibles${NC}"

# ── Liberar puerto 5000 si está ocupado ───────────────────
if fuser 5000/tcp >/dev/null 2>&1; then
    echo -e "${Y}[*] Puerto 5000 en uso. Liberando...${NC}"
    fuser -k 5000/tcp 2>/dev/null || true
    sleep 1
fi

# ── Compilar si hace falta ────────────────────────────────
if [ ! -f "bin/encrypt" ] || [ ! -f "bin/decrypt" ]; then
    echo -e "${B}[*] Compilando binarios...${NC}"
    make all -s
fi
echo -e "    ${BG}[✓] Binarios listos${NC}"

# ── Arrancar dashboard en background ─────────────────────
echo -e "${B}[*] Arrancando panel de control Flask...${NC}"
python3 dashboard/app.py &
DASHBOARD_PID=$!

# Esperar a que el servidor esté listo
for i in $(seq 1 20); do
    if curl -s --connect-timeout 1 http://localhost:5000 >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

if ! curl -s --connect-timeout 1 http://localhost:5000 >/dev/null 2>&1; then
    echo -e "${R}[-] El dashboard no arrancó. Comprueba python3-flask y flask-socketio.${NC}"
    exit 1
fi
echo -e "    ${BG}[✓] Panel activo en http://localhost:5000${NC}"

# ── Abrir navegador ───────────────────────────────────────
echo -e "${B}[*] Abriendo navegador...${NC}"
(xdg-open http://localhost:5000 2>/dev/null || \
 firefox --new-tab http://localhost:5000 2>/dev/null || \
 chromium http://localhost:5000 2>/dev/null || true) &
sleep 1

# ── Lanzar demo ───────────────────────────────────────────
echo ""
echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${W}  Panel de control: ${BB}http://localhost:5000${NC}"
echo -e "${W}  Abre esa URL en el navegador y luego presiona Enter${NC}"
echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -rp "$(echo -e "${Y}  ⏎  Presiona Enter para iniciar la demo...${NC}")" _

bash demo/run_demo.sh
