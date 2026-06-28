#!/bin/bash
# keys-backup.sh - backup CIFRADO (GPG AES256) de claves sensibles (SSH y GnuPG).
# Manual: ejecutalo cuando lo necesites, NO en cron (pide passphrase interactiva).
# Genera un .tar.gz.gpg que debes copiar a un medio externo/seguro.
set -euo pipefail

DEST="${KEYS_BACKUP_DIR:-$HOME}/backup_keys_$(date +%Y%m%d).tar.gz.gpg"
TMP="$(mktemp --suffix=.tar.gz)"

echo "Creando backup de claves sensibles (SSH + GnuPG)..."
tar -czf "$TMP" \
    "$HOME"/.ssh/id_* \
    "$HOME"/.gnupg 2>/dev/null || true

# Cifrado simetrico AES256 (pedira passphrase)
gpg --symmetric --cipher-algo AES256 --output "$DEST" "$TMP"
rm -f "$TMP"

echo "[OK] Backup cifrado creado: $DEST"
echo "[!] Copia este fichero a un USB externo o almacenamiento seguro."
echo "Para restaurar: gpg -d \"$DEST\" | tar -xzf - -C /destino"
