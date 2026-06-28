#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_vms_incremental.sh

VM_DIR="/var/lib/libvirt/images"
BACKUP_DIR="/mnt/backup_local/vms/incremental"
DATE=$(date +%Y%m%d)
LOG="/mnt/backup_local/logs/backup.log"

echo "$(date): Backup incremental de VMs..." | tee -a ${LOG}

# Crear directorio para hoy
mkdir -p "${BACKUP_DIR}/${DATE}"

# Rsync incremental con hard links
rsync -aAXHv --delete \
    --link-dest="${BACKUP_DIR}/latest" \
    "${VM_DIR}/" \
    "${BACKUP_DIR}/${DATE}/" \
    >> ${LOG} 2>&1

if [ $? -eq 0 ]; then
    # Actualizar enlace 'latest'
    rm -f "${BACKUP_DIR}/latest"
    ln -s "${DATE}" "${BACKUP_DIR}/latest"

    echo "$(date): [OK] Backup incremental completado" | tee -a ${LOG}

    # Mantener últimas 7 copias incrementales
    cd "${BACKUP_DIR}" || exit 1
    ls -t | grep -E '^[0-9]{8}$' | tail -n +8 | xargs -r rm -rf
else
    echo "$(date): [X] ERROR en backup incremental" | tee -a ${LOG}
fi
