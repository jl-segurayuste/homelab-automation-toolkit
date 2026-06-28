#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_monitor.sh

BACKUP_DIR="/mnt/backup_local"
LOG="${BACKUP_DIR}/logs/backup.log"

echo "========================================"
echo "ESTADO DEL SISTEMA DE BACKUP"
echo "Fecha: $(date)"
echo "========================================"

# Espacio usado/disponible
echo ""
echo " ESPACIO EN DISCO:"
df -h /mnt/backup_local | tail -1 | awk '{print "Usado: "$3" / "$2" ("$5")"}'

# Tamaño por categoría
echo ""
echo " TAMAÑO POR CATEGORÍA:"
du -sh ${BACKUP_DIR}/system 2>/dev/null | awk '{print "Sistema:  "$1}'
du -sh ${BACKUP_DIR}/home 2>/dev/null | awk '{print "Home:     "$1}'
du -sh ${BACKUP_DIR}/vms 2>/dev/null | awk '{print "VMs:      "$1}'
du -sh ${BACKUP_DIR}/snapshots 2>/dev/null | awk '{print "Snapshots:"$1}'

# Último backup exitoso
echo ""
echo " ÚLTIMOS BACKUPS:"
tail -20 ${LOG} | grep "[OK]" | tail -5

# Snapshots LVM activos
echo ""
echo " SNAPSHOTS LVM ACTIVOS:"
sudo lvs | grep snap

# Advertencias de espacio
USAGE=$(df /mnt/backup_local | tail -1 | awk '{print $5}' | sed 's/%//')
if [ ${USAGE} -gt 80 ]; then
    echo ""
    echo "[!]  ADVERTENCIA: Partición de backup al ${USAGE}%"
    echo "   Considera limpiar backups antiguos"
fi

# Verificar integridad del último backup
echo ""
echo " VERIFICACIÓN DE INTEGRIDAD:"
LATEST_ETC=$(ls -t ${BACKUP_DIR}/system/etc/etc_backup_*.tar.gz 2>/dev/null | head -1)
if [ -f "${LATEST_ETC}" ]; then
    if tar -tzf "${LATEST_ETC}" >/dev/null 2>&1; then
        echo "[OK] Backup /etc íntegro"
    else
        echo "[X] ERROR: Backup /etc corrupto"
    fi
fi

echo ""
echo "========================================"
