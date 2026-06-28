#!/bin/bash
# security-checklist.sh - Versión nftables

echo "=== CHECKLIST DE SEGURIDAD VPN ==="
echo ""

# 1. Servicio OpenVPN activo
if systemctl is-active --quiet openvpn@server; then
    echo "[OK] OpenVPN está corriendo"
else
    echo "[FALLO] OpenVPN NO está corriendo"
fi

# 2. nftables activo
if systemctl is-active --quiet nftables; then
    echo "[OK] nftables está activo"
    RULES_COUNT=$(nft list ruleset 2>/dev/null | grep -c "chain")
    if [[ $RULES_COUNT -gt 0 ]]; then
        echo "[OK] nftables tiene reglas cargadas ($RULES_COUNT chains)"
    else
        echo "[FALLO] nftables NO tiene reglas cargadas"
    fi
else
    echo "[FALLO] nftables NO está activo"
fi

# 3. Tabla NAT configurada
if nft list table ip nat &>/dev/null; then
    echo "[OK] Tabla NAT configurada"
else
    echo "[FALLO] Tabla NAT NO configurada"
fi

# 4. IP Forwarding habilitado
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ $IP_FORWARD -eq 1 ]]; then
    echo "[OK] IP forwarding habilitado"
else
    echo "[FALLO] IP forwarding deshabilitado"
fi

# 5. Fail2Ban activo
if systemctl is-active --quiet fail2ban; then
    echo "[OK] Fail2Ban está corriendo"
else
    echo "[FALLO] Fail2Ban NO está corriendo"
fi

# 6. Actualizaciones pendientes
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
if [[ $UPDATES -eq 0 ]]; then
    echo "[OK] Sistema actualizado"
else
    echo "[AVISO] $UPDATES actualizaciones pendientes"
    echo "        Ejecuta: sudo apt update && sudo apt upgrade"
fi

# 7. Espacio en disco
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [[ $DISK_USAGE -lt 80 ]]; then
    echo "[OK] Espacio en disco: ${DISK_USAGE}%"
else
    echo "[AVISO] Espacio en disco alto: ${DISK_USAGE}%"
fi

# 8. Certificados
CA_CERT="/etc/openvpn/ca.crt"
if [[ -f "$CA_CERT" ]]; then
    EXPIRY_DATE=$(openssl x509 -in "$CA_CERT" -noout -enddate | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
    
    if [[ $DAYS_LEFT -gt 30 ]]; then
        echo "[OK] CA expira en $DAYS_LEFT días"
    else
        echo "[AVISO] CA expira en $DAYS_LEFT días ($EXPIRY_DATE)"
    fi
else
    echo "[ERROR] Certificado CA no encontrado"
fi

# 9. IPs bloqueadas
if nft list set inet security blocklist &>/dev/null; then
    BLOCKED=$(nft list set inet security blocklist | grep -c "elements" || echo "0")
    echo "[INFO] IPs bloqueadas en firewall: $BLOCKED"
else
    echo "[INFO] Blocklist no configurada en nftables"
fi

BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
echo "[INFO] IPs baneadas por Fail2Ban (SSH): ${BANNED:-0}"

# 10. Clientes conectados
CLIENTS=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo "0")
echo "[INFO] Clientes VPN conectados: $CLIENTS"

# 11. Última actualización del sistema
if [[ -f /var/lib/apt/periodic/update-success-stamp ]]; then
    LAST_UPDATE=$(stat -c %y /var/lib/apt/periodic/update-success-stamp | cut -d' ' -f1)
    echo "[INFO] Última actualización: $LAST_UPDATE"
else
    echo "[INFO] Última actualización: Desconocida"
fi

# 12. Load average
LOAD=$(uptime | awk -F'load average:' '{print $2}')
echo "[INFO] Load average:$LOAD"

# 13. Uptime
UPTIME=$(uptime -p)
echo "[INFO] Uptime: $UPTIME"

# 14. Puerto OpenVPN accesible
if ss -ulpn | grep -q ":1194"; then
    echo "[OK] Puerto 1194/UDP escuchando"
else
    echo "[FALLO] Puerto 1194/UDP NO escucha"
fi

# 15. SSH seguro (opcional)
SSH_ROOT=$(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
if [[ "$SSH_ROOT" == "no" ]]; then
    echo "[OK] SSH: Root login deshabilitado"
else
    echo "[AVISO] SSH: Root login habilitado (considerar deshabilitar)"
fi

SSH_PASS=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
if [[ "$SSH_PASS" == "no" ]]; then
    echo "[OK] SSH: Autenticación por contraseña deshabilitada"
else
    echo "[AVISO] SSH: Autenticación por contraseña habilitada"
fi

echo ""
echo "=== FIN CHECKLIST ==="
echo ""
echo "Para ver detalles:"
echo "  sudo /usr/local/bin/quick-diag.sh"
echo ""
echo "Para monitorear:"
echo "  sudo journalctl -u openvpn@server -f"
echo "  sudo nft monitor"