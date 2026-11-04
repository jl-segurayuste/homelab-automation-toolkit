#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_vms_full.sh
# Sale con código 1 si falla la copia de alguna imagen (backup_master.sh lo cuenta como error).

set -o pipefail

VM_DIR="/var/lib/libvirt/images"
BACKUP_DIR="/mnt/backup_local/vms/full"
DATE=$(date +%Y%m%d)
LOG="/mnt/backup_local/logs/backup.log"
FAILED=0

echo "$(date): Iniciando backup completo de VMs..." | tee -a "${LOG}"

# Listar VMs activas
RUNNING_VMS=$(virsh list --name)

# Reanudar las VMs pase lo que pase: antes, si el script salía a medias (p. ej. en el cd de abajo),
# las VMs se quedaban suspendidas.
resume_vms() {
    for VM in ${RUNNING_VMS}; do
        echo "$(date): Reanudando VM: ${VM}" | tee -a "${LOG}"
        virsh resume "${VM}" || echo "$(date): [X] ERROR reanudando ${VM}" | tee -a "${LOG}"
    done
}
trap resume_vms EXIT

for VM in ${RUNNING_VMS}; do
    echo "$(date): Suspendiendo VM: ${VM}" | tee -a "${LOG}"
    virsh suspend "${VM}"
done

# Backup de imágenes de disco
cd "${VM_DIR}" || exit 1
for IMG in *.qcow2 *.img; do
    [ -f "${IMG}" ] || continue

    echo "$(date): Respaldando ${IMG}..." | tee -a "${LOG}"

    # Comprimir y respaldar
    if pigz -c "${IMG}" > "${BACKUP_DIR}/${IMG}_${DATE}.gz"; then
        echo "$(date): [OK] ${IMG} respaldada" | tee -a "${LOG}"
    else
        echo "$(date): [X] ERROR respaldando ${IMG}" | tee -a "${LOG}"
        rm -f "${BACKUP_DIR}/${IMG}_${DATE}.gz"   # no dejar una copia a medias que parezca buena
        FAILED=$((FAILED + 1))
    fi
done

# Backup de definiciones XML
while read -r VM; do
    [ -z "${VM}" ] && continue
    if ! virsh dumpxml "${VM}" > "${BACKUP_DIR}/${VM}_${DATE}.xml"; then
        echo "$(date): [X] ERROR guardando la definición de ${VM}" | tee -a "${LOG}"
        FAILED=$((FAILED + 1))
    fi
done < <(virsh list --all --name)

resume_vms
trap - EXIT

# Mantener solo último backup completo (consume mucho espacio)
cd "${BACKUP_DIR}" || exit 1
find . -name "*.gz" -mtime +7 -delete

if [ "${FAILED}" -gt 0 ]; then
    echo "$(date): [X] Backup de VMs con ${FAILED} error(es)" | tee -a "${LOG}"
    exit 1
fi
echo "$(date): [OK] Backup de VMs completado" | tee -a "${LOG}"
