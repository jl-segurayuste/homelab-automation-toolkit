#!/usr/bin/env bash
# Copia de seguridad CIFRADA con restic: backup + retencion + verificacion.
# La contrasena del repo NUNCA va en el script: se lee de un fichero (modo 600)
# o de la variable RESTIC_PASSWORD_FILE. Pensado para cron/systemd.timer.
#
# Variables (por entorno o edita los defaults):
#   RESTIC_REPOSITORY        destino (p.ej. /mnt/backup, sftp:user@host:/ruta, s3:...)
#   RESTIC_PASSWORD_FILE     fichero con la passphrase del repo (chmod 600)
#   BACKUP_PATHS             rutas a respaldar (separadas por espacio)
set -euo pipefail

export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:?Define RESTIC_REPOSITORY}"
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:?Define RESTIC_PASSWORD_FILE (fichero 600)}"
BACKUP_PATHS="${BACKUP_PATHS:-/etc /home /var/www}"
EXCLUDE_FILE="${EXCLUDE_FILE:-}"
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"
TAG="${TAG:-auto}"

command -v restic >/dev/null 2>&1 || { echo "[ERROR] restic no instalado." >&2; exit 1; }

# Inicializa el repo si aun no existe (idempotente)
if ! restic snapshots >/dev/null 2>&1; then
  echo "[*] Inicializando repositorio restic cifrado..."
  restic init
fi

echo "[*] Respaldando: $BACKUP_PATHS"
EXCLUDE_ARGS=()
[[ -n "$EXCLUDE_FILE" && -f "$EXCLUDE_FILE" ]] && EXCLUDE_ARGS=(--exclude-file "$EXCLUDE_FILE")
# shellcheck disable=SC2086
restic backup $BACKUP_PATHS --tag "$TAG" --one-file-system "${EXCLUDE_ARGS[@]}"

echo "[*] Aplicando politica de retencion..."
restic forget --tag "$TAG" \
  --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" \
  --prune

echo "[*] Verificando integridad (subconjunto de datos)..."
restic check --read-data-subset=5%

echo "[OK] Backup restic completado: $(date '+%F %T')"
