#!/bin/bash
# ai-dashboard.sh - panel en vivo de un stack de IA local (Ollama + Open WebUI).
# Muestra acceso, estado de servicios, modelo cargado, recursos, conexiones activas
# y bateria (si es un portatil). Solo lectura. Ctrl+C para salir.
#
# Variables: WEBUI_PORT (3000), OLLAMA_URL, WEBUI_CONTAINER (open-webui), INTERVAL (3).
set -uo pipefail

WEBUI_PORT="${WEBUI_PORT:-3000}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
WEBUI_CONTAINER="${WEBUI_CONTAINER:-open-webui}"
INTERVAL="${INTERVAL:-3}"

line() { printf '%s\n' "================================================================"; }

while true; do
    clear
    IP=$(hostname -I | awk '{print $1}')
    line
    echo "  AI Server Dashboard - $(date +'%H:%M:%S')"
    line

    echo "[ACCESO]"
    echo "  Local: http://localhost:${WEBUI_PORT}    Red: http://${IP}:${WEBUI_PORT}"
    echo

    echo "[SERVICIOS]"
    systemctl is-active --quiet ollama && echo "  Ollama:     activo" || echo "  Ollama:     inactivo"
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "${WEBUI_CONTAINER}" \
        && echo "  Open WebUI: activo" || echo "  Open WebUI: inactivo"
    echo

    echo "[MODELO]"
    MODEL=$(curl -s "${OLLAMA_URL}/api/ps" | jq -r '.models[]?.name' 2>/dev/null | head -1)
    if [ -n "${MODEL:-}" ]; then
        SIZE=$(curl -s "${OLLAMA_URL}/api/ps" | jq -r '.models[]?.size' 2>/dev/null | head -1)
        SIZE_GB=$(awk "BEGIN{printf \"%.2f\", ${SIZE:-0}/1024/1024/1024}")
        echo "  Cargado: ${MODEL} (${SIZE_GB} GB)"
    else
        echo "  Sin modelo cargado"
    fi
    echo

    echo "[RECURSOS]"
    echo "  CPU:  $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')% usado"
    echo "  RAM:  $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
    echo "  Temp: $(sensors 2>/dev/null | grep 'Package id 0:' | awk '{print $4}' || echo 'N/A')"
    echo

    echo "[CONEXIONES Open WebUI]"
    CONNS=$(sudo ss -tn state established "( dport = :${WEBUI_PORT} )" 2>/dev/null | grep -vc "^State")
    echo "  Establecidas: ${CONNS}"
    if [ "${CONNS:-0}" -gt 0 ]; then
        sudo ss -tn state established "( dport = :${WEBUI_PORT} )" 2>/dev/null | grep -v "^State" \
            | awk '{print $5}' | cut -d: -f1 | sort -u | while read -r ip; do echo "    - ${ip}"; done
    fi
    echo

    if [ -f /sys/class/power_supply/BAT0/status ]; then
        echo "[BATERIA] $(cat /sys/class/power_supply/BAT0/status) $(cat /sys/class/power_supply/BAT0/capacity)%"
        echo
    fi

    line
    echo "Ctrl+C para salir | refresco cada ${INTERVAL}s"
    sleep "${INTERVAL}"
done
