#!/bin/bash
# monitor-vpn.sh - Versión nftables
# Sale con código 1 si hay alguna ALERTA, para que cron/systemd/monitorización lo detecten.

# Números con punto decimal aunque el sistema esté en español (top/free/df).
export LC_ALL=C

LOG_FILE="${LOG_FILE:-/var/log/vpn-monitor.log}"
ALERT_EMAIL="${ALERT_EMAIL:-tu_email@ejemplo.com}"
SERVICE_NAME="${SERVICE_NAME:-openvpn@server}"
TUN_INTERFACE="${TUN_INTERFACE:-tun0}"
VPN_PORT="${VPN_PORT:-1194}"
STATUS_LOG="${STATUS_LOG:-/var/log/openvpn/status.log}"
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
MEM_THRESHOLD="${MEM_THRESHOLD:-80}"
DISK_THRESHOLD="${DISK_THRESHOLD:-80}"

ALERTS=()

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    log "ALERTA: $1"
    ALERTS+=("$1")
}

# Verificar servicio OpenVPN
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    alert "OpenVPN NO está corriendo"
    systemctl start "$SERVICE_NAME"
    sleep 5
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "OpenVPN reiniciado exitosamente"
    else
        alert "No se pudo reiniciar OpenVPN"
    fi
else
    log "OK: OpenVPN está corriendo"
fi

# Verificar nftables
if ! systemctl is-active --quiet nftables; then
    alert "nftables NO está corriendo"
    systemctl start nftables
else
    log "OK: nftables está corriendo"
fi

# Verificar reglas nftables cargadas
RULES_COUNT=$(nft list ruleset 2>/dev/null | grep -c "chain")
if [[ $RULES_COUNT -eq 0 ]]; then
    alert "No hay reglas nftables cargadas"
    nft -f /etc/nftables.conf
else
    log "OK: nftables tiene $RULES_COUNT chains cargadas"
fi

# Verificar tabla NAT
if ! nft list table ip nat &>/dev/null; then
    alert "Tabla NAT no existe"
else
    log "OK: Tabla NAT configurada"
fi

# Verificar interfaz tun
if ! ip link show "$TUN_INTERFACE" &>/dev/null; then
    alert "Interfaz $TUN_INTERFACE no existe"
else
    log "OK: Interfaz $TUN_INTERFACE existe"
fi

# Verificar puerto
if ! ss -ulnp | grep -q ":${VPN_PORT}\b"; then
    alert "Puerto $VPN_PORT no está escuchando"
else
    log "OK: Puerto $VPN_PORT escuchando"
fi

# Contar clientes conectados
CLIENTS=$(grep -c "^CLIENT_LIST" "$STATUS_LOG" 2>/dev/null || true)
CLIENTS=${CLIENTS:-0}
log "Clientes conectados: $CLIENTS"

# Verificar IP forwarding
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ $IP_FORWARD -ne 1 ]]; then
    alert "IP forwarding deshabilitado"
else
    log "OK: IP forwarding habilitado"
fi

# Uso de CPU total (100 - idle), en entero
CPU_USAGE=$(top -bn1 | awk -F',' '/Cpu\(s\)/ {for (i=1; i<=NF; i++) if ($i ~ / id/) {gsub(/[^0-9.]/, "", $i); printf "%d", 100 - $i}}')
if [[ -n $CPU_USAGE && $CPU_USAGE -gt $CPU_THRESHOLD ]]; then
    log "AVISO: Uso de CPU alto: ${CPU_USAGE}%"
fi

# Uso de memoria, en entero
MEM_USAGE=$(free | awk '/^Mem:/ {printf "%d", $3 / $2 * 100}')
if [[ -n $MEM_USAGE && $MEM_USAGE -gt $MEM_THRESHOLD ]]; then
    log "AVISO: Uso de memoria alto: ${MEM_USAGE}%"
fi

# Espacio en disco
DISK_USAGE=$(df -P / | awk 'NR==2 {sub(/%/, "", $5); print $5}')
if [[ -n $DISK_USAGE && $DISK_USAGE -gt $DISK_THRESHOLD ]]; then
    log "AVISO: Uso de disco alto: ${DISK_USAGE}%"
fi

# IPs bloqueadas en nftables
BLOCKED_COUNT=$(nft list set inet security blocklist 2>/dev/null | grep -c "elements" || true)
BLOCKED_COUNT=${BLOCKED_COUNT:-0}
log "IPs bloqueadas en firewall: $BLOCKED_COUNT"

if [[ ${#ALERTS[@]} -gt 0 ]]; then
    if command -v mail >/dev/null 2>&1; then
        printf '%s\n' "${ALERTS[@]}" | mail -s "ALERTA VPN en $(hostname)" "$ALERT_EMAIL"
    else
        log "AVISO: 'mail' no está instalado, no se envía el correo de alerta"
    fi
    exit 1
fi
exit 0
