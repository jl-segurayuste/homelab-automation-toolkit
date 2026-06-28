#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_master.sh

LOG="/mnt/backup_local/logs/backup.log"
SCRIPTS_DIR="/mnt/backup_local/scripts"
EMAIL="tu-email@ejemplo.com"

echo "========================================" | tee -a ${LOG}
echo "$(date): INICIO BACKUP AUTOMÁTICO" | tee -a ${LOG}
echo "========================================" | tee -a ${LOG}

# Función para ejecutar script y verificar
run_backup() {
    local script=$1
    local description=$2

    echo "" | tee -a ${LOG}
    echo "$(date): >>> Ejecutando: ${description}" | tee -a ${LOG}

    if bash "${SCRIPTS_DIR}/${script}"; then
        echo "$(date): [OK] ${description} completado" | tee -a ${LOG}
        return 0
    else
        echo "$(date): [X] ERROR en ${description}" | tee -a ${LOG}
        return 1
    fi
}

# Contador de errores
ERRORS=0

# Ejecutar backups en orden
run_backup "backup_etc.sh" "Backup de /etc" || ((ERRORS++))
run_backup "backup_home.sh" "Backup de /home" || ((ERRORS++))
run_backup "backup_configs.sh" "Backup de configuraciones" || ((ERRORS++))

# Solo domingos: backup completo
if [ "$(date +%u)" -eq 7 ]; then
    run_backup "backup_packages.sh" "Lista de paquetes" || ((ERRORS++))
    run_backup "backup_lvm_snapshot.sh" "Snapshot LVM" || ((ERRORS++))
fi

# Solo primer día del mes: VMs
if [ "$(date +%d)" -eq 01 ]; then
    run_backup "backup_vms_full.sh" "Backup completo de VMs" || ((ERRORS++))
else
    run_backup "backup_vms_incremental.sh" "Backup incremental de VMs" || ((ERRORS++))
fi

# Generar reporte
TOTAL_SIZE=$(du -sh /mnt/backup_local 2>/dev/null | awk '{print $1}')
DISK_USAGE=$(df -h /mnt/backup_local 2>/dev/null | tail -1 | awk '{print $5}')

echo "" | tee -a ${LOG}
echo "========================================" | tee -a ${LOG}
echo "$(date): BACKUP COMPLETADO" | tee -a ${LOG}
echo "Tamaño total backup: ${TOTAL_SIZE}" | tee -a ${LOG}
echo "Uso de disco: ${DISK_USAGE}" | tee -a ${LOG}
echo "Errores: ${ERRORS}" | tee -a ${LOG}
echo "========================================" | tee -a ${LOG}

# Enviar reporte por email
SUBJECT="Reporte Backup $(date +%Y-%m-%d)"

if [ ${ERRORS} -eq 0 ]; then
    SUBJECT="[OK] ${SUBJECT} - OK"
else
    SUBJECT="[X] ${SUBJECT} - ${ERRORS} ERRORES"
fi

# Generar cuerpo del email
EMAIL_BODY=$(cat <<EOF
Reporte de Backup Automático
============================
Fecha: $(date)
Host: $(hostname)

Estado: $([ ${ERRORS} -eq 0 ] && echo "[OK] EXITOSO" || echo "[X] CON ERRORES (${ERRORS})")

Estadísticas:
- Tamaño total: ${TOTAL_SIZE}
- Uso disco: ${DISK_USAGE}
- Errores: ${ERRORS}

Últimos 30 logs:
================
$(tail -30 ${LOG})

---
Sistema de backup automático
Este es un mensaje automático.
EOF
)

# Enviar email
if command -v msmtp &> /dev/null; then
    msmtp --from=tu-email@ejemplo.com -t <<EOF
To: ${EMAIL}
Subject: ${SUBJECT}
From: tu-email@ejemplo.com

${EMAIL_BODY}
EOF

    if [ $? -eq 0 ]; then
        echo "$(date): [OK] Email enviado a ${EMAIL}" | tee -a ${LOG}
    else
        echo "$(date): [X] Error enviando email" | tee -a ${LOG}
    fi
else
    echo "$(date): [!]  comando 'msmtp' no disponible" | tee -a ${LOG}
fi
