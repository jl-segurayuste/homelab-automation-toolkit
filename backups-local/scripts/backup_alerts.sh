#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_alerts.sh

BACKUP_DIR="/mnt/backup_local"
LOG="${BACKUP_DIR}/logs/backup.log"
ALERT_LOG="${BACKUP_DIR}/logs/alerts.log"

# Verificar espacio crítico
USAGE=$(df /mnt/backup_local | tail -1 | awk '{print $5}' | sed 's/%//')
if [ ${USAGE} -gt 90 ]; then
    echo "$(date):  CRÍTICO: Partición backup al ${USAGE}%" | tee -a ${ALERT_LOG}
    # Enviar email o notificación
    echo "Partición de backup crítica (${USAGE}%)" | mail -s "ALERTA Backup" tu-email@ejemplo.com
fi

# Verificar backups fallidos en últimas 24h
ERRORS=$(grep -c "[X] ERROR" ${LOG})
if [ ${ERRORS} -gt 0 ]; then
    echo "$(date): [!]  ${ERRORS} errores detectados en backups" | tee -a ${ALERT_LOG}
fi

# Verificar antigüedad del último backup
LAST_BACKUP=$(stat -c %Y ${BACKUP_DIR}/home/incremental/latest 2>/dev/null)
NOW=$(date +%s)
HOURS_OLD=$(( (${NOW} - ${LAST_BACKUP}) / 3600 ))

if [ ${HOURS_OLD} -gt 48 ]; then
    echo "$(date): [!]  Último backup tiene ${HOURS_OLD} horas" | tee -a ${ALERT_LOG}
fi
