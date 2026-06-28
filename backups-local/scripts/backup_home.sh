#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_home.sh

SOURCE="/home"
BACKUP_DIR="/mnt/backup_local/home/incremental"
DATE=$(date +%Y%m%d)
LOG="/mnt/backup_local/logs/backup.log"

echo "$(date): Iniciando backup de /home..." | tee -a ${LOG}

# Crear directorio para hoy
mkdir -p "${BACKUP_DIR}/${DATE}"

# Rsync con exclusiones
rsync -aAXHv --delete \
    --link-dest="${BACKUP_DIR}/latest" \
    --exclude='.cache' \
    --exclude='.local/share/Trash' \
    --exclude='Downloads' \
    --exclude='.mozilla/firefox/*/Cache' \
    --exclude='.thumbnails' \
    --exclude='*.tmp' \
    "${SOURCE}/" \
    "${BACKUP_DIR}/${DATE}/" \
    >> ${LOG} 2>&1

if [ $? -eq 0 ]; then
    rm -f "${BACKUP_DIR}/latest"
    ln -s "${DATE}" "${BACKUP_DIR}/latest"

    echo "$(date): [OK] Backup de /home completado" | tee -a ${LOG}

    # Mantener últimos 14 días
    cd "${BACKUP_DIR}" || exit 1
    ls -t | grep -E '^[0-9]{8}$' | tail -n +15 | xargs -r rm -rf
else
    echo "$(date): [X] ERROR en backup de /home" | tee -a ${LOG}
fi
