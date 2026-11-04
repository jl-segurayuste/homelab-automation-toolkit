#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_packages.sh
# Sale con código 1 si falla alguna parte (backup_master.sh lo cuenta como error).

set -o pipefail

BACKUP_DIR="/mnt/backup_local/system/packages"
DATE=$(date +%Y%m%d)
LOG="/mnt/backup_local/logs/backup.log"
FAILED=0

step() {   # step "descripción" orden...
    local desc=$1; shift
    if ! "$@"; then
        echo "$(date): [X] ERROR: ${desc}" | tee -a "${LOG}"
        FAILED=$((FAILED + 1))
    fi
}

echo "$(date): Guardando lista de paquetes..." | tee -a "${LOG}"
mkdir -p "${BACKUP_DIR}/sources_${DATE}" || exit 1

# Lista de paquetes instalados manualmente y lista completa
step "apt-mark showmanual" sh -c "apt-mark showmanual > '${BACKUP_DIR}/manual_packages_${DATE}.txt'"
step "dpkg --get-selections" sh -c "dpkg --get-selections > '${BACKUP_DIR}/all_packages_${DATE}.txt'"

# Repositorios configurados (antes el directorio destino no existía y la copia fallaba siempre)
step "copia de los orígenes APT" sudo cp -a /etc/apt/sources.list /etc/apt/sources.list.d \
    "${BACKUP_DIR}/sources_${DATE}/"

# Claves de los repositorios: apt-key ya no existe en las versiones actuales; las claves están en
# trusted.gpg.d y keyrings
for d in /etc/apt/trusted.gpg.d /etc/apt/keyrings /usr/share/keyrings; do
    [ -d "$d" ] && step "copia de $d" sudo cp -a "$d" "${BACKUP_DIR}/sources_${DATE}/"
done

# Mantener solo últimas 10 versiones
cd "${BACKUP_DIR}" || exit 1
ls -t manual_packages_*.txt | tail -n +11 | xargs -r rm
ls -t all_packages_*.txt | tail -n +11 | xargs -r rm
ls -dt sources_*/ | tail -n +11 | xargs -r sudo rm -rf --

if [ "${FAILED}" -gt 0 ]; then
    echo "$(date): [X] Lista de paquetes con ${FAILED} error(es)" | tee -a "${LOG}"
    exit 1
fi
echo "$(date): [OK] Lista de paquetes guardada" | tee -a "${LOG}"
