#!/bin/bash
# vaultwarden-backup.sh - backup CONSISTENTE de Vaultwarden.
#
# Vaultwarden usa SQLite en modo WAL; un tar en caliente puede quedar inconsistente.
# Estrategia: parar el contenedor (checkpoint limpio del WAL) -> tar del volumen ->
# arrancar de nuevo. Downtime de ~2-3 s. La salida queda en un directorio local que
# puedes sincronizar despues a un destino remoto (restic/borg/rsync).
#
# Requiere root (acceso al volumen de Docker y al socket de docker).
# Ajusta VOL_DATA, DEST y el nombre del contenedor a tu entorno.
set -uo pipefail

CONTAINER="${VW_CONTAINER:-vaultwarden}"
VOL_DATA="${VW_VOL_DATA:-/var/lib/docker/volumes/vaultwarden-data/_data}"
DEST="${VW_DEST:-/var/backups/vaultwarden}"
RETENTION="${VW_RETENTION:-14}"   # numero de copias a conservar
LOG="${VW_LOG:-/var/log/vaultwarden-backup.log}"

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

if [ "$(id -u)" -ne 0 ]; then echo "Necesita root" >&2; exit 1; fi
if [ ! -d "$VOL_DATA" ]; then log "ERROR: no existe $VOL_DATA"; exit 1; fi

mkdir -p "$DEST"
TS=$(date +%Y%m%d-%H%M%S)
OUT="$DEST/vaultwarden-$TS.tar.gz"

RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo "false")

log "Inicio backup Vaultwarden -> $OUT"
if [ "$RUNNING" = "true" ]; then
    docker stop "$CONTAINER" >/dev/null 2>&1 && log "$CONTAINER parado (checkpoint WAL)"
fi

tar czf "$OUT" -C "$VOL_DATA" . 2>>"$LOG"
RC=$?

if [ "$RUNNING" = "true" ]; then
    docker start "$CONTAINER" >/dev/null 2>&1 && log "$CONTAINER arrancado de nuevo"
fi

if [ $RC -ne 0 ]; then log "ERROR: tar fallo (rc=$RC)"; rm -f "$OUT"; exit 1; fi

SIZE=$(du -h "$OUT" | awk '{print $1}')
log "OK ($SIZE)"

# Retencion: conservar las RETENTION mas recientes
ls -1t "$DEST"/vaultwarden-*.tar.gz 2>/dev/null | tail -n +$((RETENTION+1)) | while read -r f; do
    rm -f "$f" && log "purga antigua: $(basename "$f")"
done
exit 0
