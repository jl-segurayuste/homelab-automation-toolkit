#!/usr/bin/env bash
# Audita, sobre una flota de servidores via SSH, que keytabs Kerberos no contengan
# tipos de cifrado debiles (no-AES: arcfour/RC4, DES...). Solo LECTURA.
# Genera un CSV "servidor,keytab" con los hallazgos. No imprime los enctypes.
#
# Por que importa: un keytab con RC4/DES facilita Kerberoasting y ataques de
# downgrade. Lo ideal es que todas las claves sean aes256/aes128.
#
# Configura las variables o pasalas por entorno. El fichero de maquinas tiene un
# servidor por linea (admite comentarios con #).
#
# Uso:
#   MACHINES_FILE=./maquinas.txt SSH_USER=miusuario KEYTAB_DIR=/etc/security/keytabs \
#     bash audit-keytabs-noaes.sh [--dry-run] [--parallel]
set -uo pipefail

MACHINES_FILE="${MACHINES_FILE:-./maquinas.txt}"   # un servidor por linea
KEYTAB_DIR="${KEYTAB_DIR:-/etc/security/keytabs}"   # ruta a buscar keytabs en remoto
SSH_USER="${SSH_USER:-$USER}"
SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"
SSH_TIMEOUT="${SSH_TIMEOUT:-10}"
MAX_PARALLEL="${MAX_PARALLEL:-10}"

TIMESTAMP=$(date +'%Y%m%d%H%M%S')
LOG="keytabs-noaes-${TIMESTAMP}.log"
CSV="keytabs-noaes-${TIMESTAMP}.csv"
DRY_RUN=false; PARALLEL=false
TOTAL=0; TOTAL_OK=0; TOTAL_NOAES=0; TOTAL_ERROR=0

usage() {
    echo "Uso: $0 [--dry-run] [--parallel] [--help]"
    echo "  --dry-run    Lista los servidores sin ejecutar SSH"
    echo "  --parallel   Hasta MAX_PARALLEL servidores en paralelo (def: ${MAX_PARALLEL})"
    exit 0
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true ;;
        --parallel) PARALLEL=true ;;
        --help|-h)  usage ;;
        *) echo "Opcion desconocida: $1"; usage ;;
    esac; shift
done

log() { echo "$*" | tee -a "$LOG"; }

[[ -f "$MACHINES_FILE" ]] || { echo "ERROR: no existe $MACHINES_FILE" >&2; exit 1; }
echo "servidor,keytab" > "$CSV"

audit_server() {
    local server="$1" output ssh_rc
    log "Auditando $server"
    if $DRY_RUN; then log "[$server] [DRY-RUN] omitido"; return 0; fi

    output=$(ssh -q \
        -o ConnectTimeout="${SSH_TIMEOUT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        -F "${SSH_CONFIG}" -l "${SSH_USER}" "${server}" \
        "KTDIR='${KEYTAB_DIR}' bash -s" << 'EOF' 2>&1
        find "$KTDIR" -type f -name "*.keytab" 2>/dev/null | while read -r KEYTAB; do
            ENCTYPES=$(klist -kte "$KEYTAB" 2>/dev/null | grep '(' | sed 's/.*(\(.*\))/\1/' | sort -u)
            NOAES=$(echo "$ENCTYPES" | grep -vi aes || true)
            [ -n "$NOAES" ] && echo "NOAES:$KEYTAB"
        done
EOF
    )
    ssh_rc=$?
    if [[ $ssh_rc -ne 0 ]]; then
        log "[$server] ERROR: fallo SSH (rc=${ssh_rc})"
        echo "${server},ERROR SSH rc=${ssh_rc}" >> "$CSV"
        ((TOTAL_ERROR++)) || true; return 1
    fi
    if [[ -z "$output" ]]; then
        log "[$server] Sin keytabs en ${KEYTAB_DIR}"; ((TOTAL_OK++)) || true; return 0
    fi
    local found=false
    while IFS= read -r line; do
        if [[ "$line" == NOAES:* ]]; then
            found=true
            log "[$server] Keytab con cifrado no-AES: ${line#NOAES:}"
            echo "${server},${line#NOAES:}" >> "$CSV"
        fi
    done <<< "$output"
    if $found; then ((TOTAL_NOAES++)) || true
    else log "[$server] Sin cifrados no-AES"; ((TOTAL_OK++)) || true; fi
}

mapfile -t SERVERS < <(grep -Ev '^\s*(#|$)' "$MACHINES_FILE" | awk '{print $1}')
TOTAL=${#SERVERS[@]}
log "Servidores a auditar: ${TOTAL}"

if $PARALLEL; then
    job_count=0
    for server in "${SERVERS[@]}"; do
        audit_server "$server" &
        ((job_count++)) || true
        if [[ $job_count -ge $MAX_PARALLEL ]]; then wait -n 2>/dev/null || wait; ((job_count--)) || true; fi
    done
    wait
else
    for server in "${SERVERS[@]}"; do audit_server "$server"; done
fi

log "----------------------------------------"
log "Total: ${TOTAL}  OK: ${TOTAL_OK}  no-AES: ${TOTAL_NOAES}  Errores SSH: ${TOTAL_ERROR}"
log "Log: ${LOG}   CSV: ${CSV}"

# Salida: 0=todo AES  1=hay no-AES  2=errores SSH
if [[ $TOTAL_ERROR -gt 0 ]]; then exit 2
elif [[ $TOTAL_NOAES -gt 0 ]]; then exit 1
else exit 0; fi
