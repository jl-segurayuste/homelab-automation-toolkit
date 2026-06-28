#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_lvm_snapshot.sh

SNAPSHOT_NAME="snap_root_$(date +%Y%m%d)"
SNAPSHOT_SIZE="20G"
MOUNT_POINT="/mnt/backup_local/snapshots/lvm/${SNAPSHOT_NAME}"
BACKUP_FILE="/mnt/backup_local/snapshots/root_snapshot_$(date +%Y%m%d).img.gz"

echo "$(date): Creando snapshot LVM de /" | tee -a /mnt/backup_local/logs/backup.log

# Eliminar snapshot anterior si existe
sudo lvremove -f /dev/vg_nvme/${SNAPSHOT_NAME} 2>/dev/null

# Crear snapshot
if sudo lvcreate -L ${SNAPSHOT_SIZE} -s -n ${SNAPSHOT_NAME} /dev/vg_nvme/lv_root; then
    echo "$(date): [OK] Snapshot creado: ${SNAPSHOT_NAME}" | tee -a /mnt/backup_local/logs/backup.log

    # Montar snapshot
    sudo mkdir -p "${MOUNT_POINT}"
    sudo mount -o ro /dev/vg_nvme/${SNAPSHOT_NAME} "${MOUNT_POINT}"

    # Crear imagen comprimida (opcional, consume tiempo)
    # sudo dd if=/dev/vg_nvme/${SNAPSHOT_NAME} | gzip > "${BACKUP_FILE}"

    echo "$(date): [OK] Snapshot montado en ${MOUNT_POINT}" | tee -a /mnt/backup_local/logs/backup.log
    echo "[!]  Recuerda eliminar el snapshot cuando termine el backup: sudo lvremove /dev/vg_nvme/${SNAPSHOT_NAME}"
else
    echo "$(date): [X] ERROR creando snapshot" | tee -a /mnt/backup_local/logs/backup.log
    exit 1
fi
