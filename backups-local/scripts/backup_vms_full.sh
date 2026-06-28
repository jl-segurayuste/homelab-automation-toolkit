#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_vms_full.sh

VM_DIR="/var/lib/libvirt/images"
BACKUP_DIR="/mnt/backup_local/vms/full"
DATE=$(date +%Y%m%d)

echo "$(date): Iniciando backup completo de VMs..." | tee -a /mnt/backup_local/logs/backup.log

# Listar VMs activas
RUNNING_VMS=$(virsh list --name)

for VM in ${RUNNING_VMS}; do
    echo "$(date): Suspendiendo VM: ${VM}" | tee -a /mnt/backup_local/logs/backup.log
    virsh suspend "${VM}"
done

# Backup de imágenes de disco
cd "${VM_DIR}" || exit 1
for IMG in *.qcow2 *.img; do
    [ -f "${IMG}" ] || continue

    echo "$(date): Respaldando ${IMG}..." | tee -a /mnt/backup_local/logs/backup.log

    # Comprimir y respaldar
    pigz -c "${IMG}" > "${BACKUP_DIR}/${IMG}_${DATE}.gz"

    if [ $? -eq 0 ]; then
        echo "$(date): [OK] ${IMG} respaldada" | tee -a /mnt/backup_local/logs/backup.log
    else
        echo "$(date): [X] ERROR respaldando ${IMG}" | tee -a /mnt/backup_local/logs/backup.log
    fi
done

# Backup de definiciones XML
virsh list --all --name | while read VM; do
    [ -z "${VM}" ] && continue
    virsh dumpxml "${VM}" > "${BACKUP_DIR}/${VM}_${DATE}.xml"
done

# Reanudar VMs
for VM in ${RUNNING_VMS}; do
    echo "$(date): Reanudando VM: ${VM}" | tee -a /mnt/backup_local/logs/backup.log
    virsh resume "${VM}"
done

# Mantener solo último backup completo (consume mucho espacio)
cd "${BACKUP_DIR}" || exit 1
find . -name "*.gz" -mtime +7 -delete

echo "$(date): [OK] Backup de VMs completado" | tee -a /mnt/backup_local/logs/backup.log
