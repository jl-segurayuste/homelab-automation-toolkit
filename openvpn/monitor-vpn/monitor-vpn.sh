#!/bin/bash
# monitor-vpn.sh - Versión nftables

LOG_FILE="/var/log/vpn-monitor.log"
ALERT_EMAIL="tu_email@ejemplo.com"

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Verificar servicio OpenVPN
if ! systemctl is-active --quiet openvpn@server; then
    log "ALERTA: OpenVPN NO está corriendo"
    echo "OpenVPN service is down on $(hostname)" | mail -s "ALERTA VPN" "$ALERT_EMAIL"
    systemctl start openvpn@server
    sleep 5
    if systemctl is-active --quiet openvpn@server; then
        log "OpenVPN reiniciado exitosamente"
    else
        log "ERROR: No se pudo reiniciar OpenVPN"
    fi
else
    log "OK: OpenVPN está corriendo"
fi

# Verificar nftables
if ! systemctl is-active --quiet nftables; then
    log "ALERTA: nftables NO está corriendo"
    systemctl start nftables
else
    log "OK: nftables está corriendo"
fi

# Verificar reglas nftables cargadas
RULES_COUNT=$(nft list ruleset 2>/dev/null | grep -c "chain")
if [[ $RULES_COUNT -eq 0 ]]; then
    log "ALERTA: No hay reglas nftables cargadas"
    nft -f /etc/nftables.conf
else
    log "OK: nftables tiene $RULES_COUNT chains cargadas"
fi

# Verificar tabla NAT
if ! nft list table ip nat &>/dev/null; then
    log "ALERTA: Tabla NAT no existe"
else
    log "OK: Tabla NAT configurada"
fi

# Verificar interfaz tun0
if ! ip link show tun0 &>/dev/null; then
    log "ALERTA: Interfaz tun0 no existe"
else
    log "OK: Interfaz tun0 existe"
fi

# Verificar puerto 1194
if ! ss -ulpn | grep -q ":1194"; then
    log "ALERTA: Puerto 1194 no está escuchando"
else
    log "OK: Puerto 1194 escuchando"
fi

# Contar clientes conectados
CLIENTS=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo "0")
log "Clientes conectados: $CLIENTS"

# Verificar IP forwarding
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ $IP_FORWARD -ne 1 ]]; then
    log "ALERTA: IP forwarding deshabilitado"
else
    log "OK: IP forwarding habilitado"
fi

# Verificar uso de CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    log "AVISO: Uso de CPU alto: ${CPU_USAGE}%"
fi

# Verificar memoria
MEM_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
if (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
    log "AVISO: Uso de memoria alto: ${MEM_USAGE}%"
fi

# Verificar espacio en disco
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [[ $DISK_USAGE -gt 80 ]]; then
    log "AVISO: Uso de disco alto: ${DISK_USAGE}%"
fi

# Verificar IPs bloqueadas en nftables
BLOCKED_COUNT=$(nft list set inet security blocklist 2>/dev/null | grep -c "elements" || echo "0")
log "IPs bloqueadas en firewall: $BLOCKED_COUNT"