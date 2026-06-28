#!/bin/bash
# analyze-vpn-logs.sh - Versión nftables

echo "=== ANÁLISIS DE LOGS VPN ==="
echo ""

# Logs de OpenVPN
echo "1. Últimos intentos de conexión (24h):"
sudo journalctl -u openvpn@server --since "24 hours ago" | grep "Initial packet" | tail -10
echo ""

echo "2. Conexiones exitosas (24h):"
sudo journalctl -u openvpn@server --since "24 hours ago" | grep "Peer Connection Initiated" | wc -l
echo ""

echo "3. Errores TLS (24h):"
TLS_ERRORS=$(sudo journalctl -u openvpn@server --since "24 hours ago" | grep -i "TLS Error" | wc -l)
echo "   Total: $TLS_ERRORS"
if [[ $TLS_ERRORS -gt 0 ]]; then
    echo "   Últimos errores:"
    sudo journalctl -u openvpn@server --since "24 hours ago" | grep -i "TLS Error" | tail -5
fi
echo ""

echo "4. Clientes desconectados por inactividad (24h):"
sudo journalctl -u openvpn@server --since "24 hours ago" | grep "Inactivity timeout" | wc -l
echo ""

echo "5. IPs baneadas por Fail2Ban:"
echo "   SSH:"
sudo fail2ban-client status sshd 2>/dev/null | grep "Banned IP" || echo "      Ninguna"
echo ""

echo "6. IPs bloqueadas en nftables:"
if nft list set inet security blocklist &>/dev/null; then
    BLOCKED=$(nft list set inet security blocklist | grep "elements" | wc -l)
    if [[ $BLOCKED -gt 0 ]]; then
        nft list set inet security blocklist
    else
        echo "   Ninguna"
    fi
else
    echo "   Blocklist no configurada"
fi
echo ""

echo "7. Top 10 IPs que intentaron conectar (7 días):"
sudo journalctl -u openvpn@server --since "7 days ago" | \
    grep "Initial packet" | \
    grep -oP '\[AF_INET\]\K[^:]+' | \
    sort | uniq -c | sort -rn | head -10
echo ""

echo "8. Logs de firewall (últimos drops):"
sudo journalctl --since "1 hour ago" | grep "NFT.*DROP" | tail -10 || echo "   Sin drops recientes"
echo ""

echo "9. Actividad del servicio nftables:"
sudo journalctl -u nftables --since "24 hours ago" --no-pager | tail -10
echo ""

echo "10. Estadísticas de tráfico (interfaz tun0):"
if ip -s link show tun0 &>/dev/null; then
    ip -s link show tun0 | grep -A 2 "RX:\|TX:"
else
    echo "    Interfaz tun0 no activa"
fi
echo ""

echo "=== FIN ANÁLISIS ==="