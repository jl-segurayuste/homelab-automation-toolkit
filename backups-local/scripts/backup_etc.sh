#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_etc.sh

BACKUP_DIR="/mnt/backup_local/system/etc"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="etc_backup_${DATE}.tar.gz"

echo "$(date): Iniciando backup de /etc..." | tee -a /mnt/backup_local/logs/backup.log

# Crear backup comprimido
sudo tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
    --exclude='/etc/ssl/private' \
    /etc

# Verificar integridad
if [ $? -eq 0 ]; then
    echo "$(date): [OK] Backup completado: ${BACKUP_FILE}" | tee -a /mnt/backup_local/logs/backup.log

    # Mantener solo últimos 30 backups
    cd "${BACKUP_DIR}" || exit 1
    ls -t etc_backup_*.tar.gz | tail -n +31 | xargs -r rm
else
    echo "$(date): [X] ERROR en backup de /etc" | tee -a /mnt/backup_local/logs/backup.log
    exit 1
fi
