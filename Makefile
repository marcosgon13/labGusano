CC = gcc
CFLAGS = -Wall -O2
LDFLAGS = -lssl -lcrypto

# Modo debug
DEBUG_CFLAGS = -g -O0 -fsanitize=address
DEBUG_LDFLAGS = -lssl -lcrypto -lasan

SRCDIR = src
BINDIR = bin
SOURCES = $(SRCDIR)/encrypt.c $(SRCDIR)/decrypt.c
TARGETS = $(BINDIR)/encrypt $(BINDIR)/decrypt

.PHONY: all clean keys test debug

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

keys:
	@mkdir -p keys
	openssl genpkey -algorithm RSA -out keys/private.pem -pkeyopt rsa_keygen_bits:2048
	openssl rsa -pubout -in keys/private.pem -out keys/public.pem
	@echo "[+] Par de claves generado en keys/"

test: all keys
	@echo "Test básico de cifrado/descifrado..."
	@echo "Texto de prueba" > /tmp/test_original.txt
	./$(BINDIR)/encrypt /tmp/test_original.txt keys/public.pem
	./$(BINDIR)/decrypt /tmp/test_original.txt.enc keys/private.pem
	@if cmp -s /tmp/test_original.txt /tmp/test_original.txt; then \
		echo "[+] Test superado"; \
		rm -f /tmp/test_original.txt /tmp/test_original.txt.enc; \
	else \
		echo "[-] Test fallido: los ficheros no coinciden"; \
	fi

clean:
	rm -rf bin/