#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_cleanup.sh

BACKUP_DIR="/mnt/backup_local"
LOG="${BACKUP_DIR}/logs/backup.log"

echo "$(date): Iniciando limpieza de backups antiguos..." | tee -a ${LOG}

# Política de retención:
# - /etc: 30 días
# - /home: 14 días
# - VMs incrementales: 7 días
# - VMs completas: 1 mes
# - Snapshots LVM: 7 días

# Limpiar /etc antiguos
find ${BACKUP_DIR}/system/etc -name "*.tar.gz" -mtime +30 -delete
echo "$(date): [OK] Limpiados backups /etc >30 días" | tee -a ${LOG}

# Limpiar /home antiguos
find ${BACKUP_DIR}/home/incremental -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \;
echo "$(date): [OK] Limpiados backups /home >14 días" | tee -a ${LOG}

# Limpiar VMs incrementales
find ${BACKUP_DIR}/vms/incremental -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;
echo "$(date): [OK] Limpiados backups VMs incrementales >7 días" | tee -a ${LOG}

# Limpiar VMs completas antiguas (mantener solo la más reciente)
cd "${BACKUP_DIR}/vms/full" || exit 1
for VM in $(ls *.qcow2.gz 2>/dev/null | sed 's/_[0-9]*.qcow2.gz//' | sort -u); do
    ls -t ${VM}_*.qcow2.gz 2>/dev/null | tail -n +2 | xargs -r rm
done
echo "$(date): [OK] Limpiados backups VMs duplicados" | tee -a ${LOG}

# Eliminar snapshots LVM antiguos
for SNAP in $(sudo lvs --noheadings -o lv_name vg_nvme | grep snap); do
    SNAP_DATE=$(echo ${SNAP} | grep -oP '\d{8}')
    if [ ! -z "${SNAP_DATE}" ]; then
        DAYS_OLD=$(( ($(date +%s) - $(date -d ${SNAP_DATE} +%s)) / 86400 ))
        if [ ${DAYS_OLD} -gt 7 ]; then
            sudo umount /mnt/backup_local/snapshots/lvm/${SNAP} 2>/dev/null
            sudo lvremove -f /dev/vg_nvme/${SNAP}
            echo "$(date): [OK] Eliminado snapshot LVM: ${SNAP}" | tee -a ${LOG}
        fi
    fi
done

# Limpiar logs antiguos
find ${BACKUP_DIR}/logs -name "*.log" -mtime +60 -delete

echo "$(date): [OK] Limpieza completada" | tee -a ${LOG}

# Mostrar espacio liberado
df -h /mnt/backup_local | tail -1 | awk '{print "Espacio disponible: "$4}'
