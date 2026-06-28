#!/bin/bash
# health-alerts.sh - chequeo de salud del host con alertas por email.
# Comprueba disco, RAM, servicios systemd y contenedores Docker; si algo falla,
# envia un correo. Pensado para ejecutarse por cron/timer (p.ej. cada 15 min).
#
# Configura por variables de entorno (o edita los valores por defecto):
#   ALERT_EMAIL        destinatario de las alertas (obligatorio para enviar)
#   DISK_THRESHOLD     % de uso de / que dispara alerta (def. 85)
#   RAM_THRESHOLD      % de uso de RAM que dispara alerta (def. 90)
#   SYSTEMD_SERVICES   lista separada por espacios de servicios systemd a vigilar
#   DOCKER_CONTAINERS  lista separada por espacios de contenedores a vigilar
#
# Requiere 'mail' (mailutils/bsd-mailx) para el envio.
set -uo pipefail

ALERT_EMAIL="${ALERT_EMAIL:-}"
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"
RAM_THRESHOLD="${RAM_THRESHOLD:-90}"
LOG="${HEALTH_LOG:-/var/log/health-alerts.log}"
read -r -a SERVICES <<< "${SYSTEMD_SERVICES:-}"
read -r -a CONTAINERS <<< "${DOCKER_CONTAINERS:-}"

{
  echo "=================================================="
  echo "Health check: $(date)"
} >> "$LOG"

ALERTS=""

# Disco
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "${DISK_USAGE:-0}" -gt "$DISK_THRESHOLD" ]; then
    ALERTS+="[!] Disco al ${DISK_USAGE}%\n"
fi

# RAM
RAM_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2*100}')
if [ "${RAM_USAGE:-0}" -gt "$RAM_THRESHOLD" ]; then
    ALERTS+="[!] RAM al ${RAM_USAGE}%\n"
fi

# Servicios systemd
for svc in "${SERVICES[@]}"; do
    [ -n "$svc" ] || continue
    systemctl is-active --quiet "$svc" || ALERTS+="[X] Servicio systemd caido: ${svc}\n"
done

# Contenedores Docker
if command -v docker >/dev/null 2>&1; then
    for c in "${CONTAINERS[@]}"; do
        [ -n "$c" ] || continue
        docker ps --format '{{.Names}}' | grep -qx "$c" || ALERTS+="[X] Contenedor caido: ${c}\n"
    done
fi

if [ -n "$ALERTS" ]; then
    echo -e "ALERTAS:\n\n${ALERTS}" >> "$LOG"
    if [ -n "$ALERT_EMAIL" ] && command -v mail >/dev/null 2>&1; then
        echo -e "Alertas del host $(hostname):\n\n${ALERTS}" | mail -s "Alertas $(hostname) $(date +%F)" "$ALERT_EMAIL"
        echo "Alertas enviadas a ${ALERT_EMAIL}" >> "$LOG"
    fi
else
    echo "[OK] Todo correcto" >> "$LOG"
fi
