#!/usr/bin/env bash
# Copia de seguridad CIFRADA con BorgBackup: create + prune + check.
# La passphrase se lee de BORG_PASSPHRASE_FILE (chmod 600); nunca se incrusta.
# Pensado para cron/systemd.timer.
#
# Variables:
#   BORG_REPO                repo borg (p.ej. /mnt/backup/borg, ssh://user@host/./repo)
#   BORG_PASSPHRASE_FILE     fichero con la passphrase (chmod 600)
#   BACKUP_PATHS             rutas a respaldar
set -euo pipefail

export BORG_REPO="${BORG_REPO:?Define BORG_REPO}"
PASS_FILE="${BORG_PASSPHRASE_FILE:?Define BORG_PASSPHRASE_FILE (fichero 600)}"
[[ -f "$PASS_FILE" ]] || { echo "[ERROR] No existe $PASS_FILE" >&2; exit 1; }
export BORG_PASSPHRASE="$(cat "$PASS_FILE")"
BACKUP_PATHS="${BACKUP_PATHS:-/etc /home /var/www}"
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"

command -v borg >/dev/null 2>&1 || { echo "[ERROR] borg no instalado." >&2; exit 1; }

# Inicializa el repo cifrado si no existe (idempotente)
if ! borg info "$BORG_REPO" >/dev/null 2>&1; then
  echo "[*] Inicializando repo borg cifrado (repokey-blake2)..."
  borg init --encryption=repokey-blake2 "$BORG_REPO"
fi

NAME="$(hostname)-$(date +%Y%m%d-%H%M%S)"
echo "[*] Creando archivo $NAME ..."
# shellcheck disable=SC2086
borg create --stats --compression zstd "::$NAME" $BACKUP_PATHS

echo "[*] Aplicando retencion..."
borg prune --stats \
  --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY"

echo "[*] Verificando integridad..."
borg check "$BORG_REPO"

unset BORG_PASSPHRASE
echo "[OK] Backup borg completado: $(date '+%F %T')"
