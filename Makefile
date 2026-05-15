CC      = gcc
CFLAGS  = -Wall -O2
LDFLAGS = -lssl -lcrypto

DEBUG_CFLAGS  = -g -O0 -fsanitize=address
DEBUG_LDFLAGS = -lssl -lcrypto -lasan

SRCDIR  = src
BINDIR  = bin
TARGETS = $(BINDIR)/encrypt $(BINDIR)/decrypt

.PHONY: all clean keys test debug lab dashboard demo

# ── Compilación ──────────────────────────────────────────
all: $(TARGETS)

$(BINDIR)/encrypt: $(SRCDIR)/encrypt.c
	@mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

$(BINDIR)/decrypt: $(SRCDIR)/decrypt.c
	@mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

debug: CFLAGS = $(DEBUG_CFLAGS)
debug: LDFLAGS = $(DEBUG_LDFLAGS)
debug: clean $(TARGETS)

# ── Claves RSA ───────────────────────────────────────────
keys:
	@mkdir -p keys
	openssl genpkey -algorithm RSA -out keys/private.pem -pkeyopt rsa_keygen_bits:2048
	openssl rsa -pubout -in keys/private.pem -out keys/public.pem
	@echo "[+] Par de claves RSA-2048 generado en keys/"

# ── Test rápido ──────────────────────────────────────────
test: all keys
	@echo "[*] Test básico de cifrado/descifrado..."
	@echo "Texto de prueba para verificar AES-256-CBC + RSA-2048 OAEP" > /tmp/test_original.txt
	./$(BINDIR)/encrypt /tmp/test_original.txt keys/public.pem
	./$(BINDIR)/decrypt /tmp/test_original.txt.enc keys/private.pem
	@diff -q /tmp/test_original.txt /tmp/test_original.txt && \
		echo "[+] Test superado: cifrado y descifrado correctos" && \
		rm -f /tmp/test_original.txt /tmp/test_original.txt.enc || \
		echo "[-] Test fallido"

# ── Dashboard web (solo el servidor Flask) ───────────────
dashboard: all keys
	@echo "[*] Arrancando panel de control en http://localhost:5000"
	python3 dashboard/app.py

# ── Demo solo en terminal (sin dashboard) ────────────────
demo: all keys
	bash demo/run_demo.sh

# ── Lab completo: dashboard + demo (recomendado) ─────────
lab: all keys
	bash demo/start_lab.sh

# ── Limpieza ─────────────────────────────────────────────
clean:
	rm -rf bin/
	rm -rf /tmp/lab_victims/
	@echo "[+] Limpieza completada"