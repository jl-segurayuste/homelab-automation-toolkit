#!/bin/bash
# Dumps logicos de bases de datos que corren en contenedores Docker.
# Complementa el backup de volumenes (crash-consistent) con dumps consistentes
# que permiten restauraciones limpias por base. Pensado para lanzarse por cron/timer.
#
# Configura tus contenedores en PG_TARGETS / MYSQL_TARGETS.
# La password de MySQL se lee DENTRO del contenedor ($MYSQL_ROOT_PASSWORD),
# nunca se pasa por la linea de comandos ni se expone en el host.
set -uo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin"

# --- Configuracion (ajusta a tu entorno) ---
DEST_BASE="${DEST_BASE:-/mnt/backup_local/db-dumps}"
LOG="${LOG:-/mnt/backup_local/logs/db-dumps.log}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
NTFY_URL="${NTFY_URL:-}"   # opcional: URL ntfy para notificaciones; vacio = sin notificar

# "contenedor:superusuario"
PG_TARGETS=(
  "postgres-1:postgres"
  # "miapp-db:postgres"
)
# nombres de contenedor MySQL/MariaDB (usan $MYSQL_ROOT_PASSWORD interno)
MYSQL_TARGETS=(
  # "mariadb-1"
)
# -------------------------------------------

DEST="$DEST_BASE/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST" "$(dirname "$LOG")"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
running() { docker ps --format '{{.Names}}' | grep -qx "$1"; }
notify() { [ -n "$NTFY_URL" ] && curl -fsS -m 10 "$@" "$NTFY_URL" >/dev/null 2>&1 || true; }

ok=0; fail=0

for entry in "${PG_TARGETS[@]}"; do
  c="${entry%%:*}"; u="${entry##*:}"
  running "$c" || continue
  if docker exec "$c" pg_dumpall -U "$u" 2>/dev/null | gzip > "$DEST/${c}.sql.gz" && [ -s "$DEST/${c}.sql.gz" ]; then
    log "[OK] $c (postgres) -> $(du -h "$DEST/${c}.sql.gz" | cut -f1)"; ok=$((ok+1))
  else
    log "[FAIL] $c (postgres)"; rm -f "$DEST/${c}.sql.gz"; fail=$((fail+1))
  fi
done

for c in "${MYSQL_TARGETS[@]}"; do
  running "$c" || continue
  if docker exec "$c" sh -c 'mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases --single-transaction --quick 2>/dev/null' | gzip > "$DEST/${c}.sql.gz" && [ -s "$DEST/${c}.sql.gz" ]; then
    log "[OK] $c (mysql) -> $(du -h "$DEST/${c}.sql.gz" | cut -f1)"; ok=$((ok+1))
  else
    log "[FAIL] $c (mysql)"; rm -f "$DEST/${c}.sql.gz"; fail=$((fail+1))
  fi
done

find "$DEST_BASE" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} \; 2>/dev/null || true

log "Dumps logicos: $ok OK, $fail fallos -> $DEST"
if [ "$fail" -gt 0 ]; then
  notify -H "Priority: urgent" -H "Title: DB dumps con fallos" -d "$ok OK, $fail fallos - revisa $LOG"
  exit 1
fi
notify -H "Title: DB dumps OK" -d "$ok bases respaldadas"
