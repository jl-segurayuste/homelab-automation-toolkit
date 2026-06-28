#!/bin/bash
# openvpn-diagnostics.sh

echo "============================================="
echo "  Diagnóstico de OpenVPN Server"
echo "============================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Estado del servicio
echo "1. ESTADO DEL SERVICIO"
echo "----------------------"
if systemctl is-active --quiet openvpn@server; then
    echo -e "[${GREEN}OK${NC}] Servicio OpenVPN está activo"
else
    echo -e "[${RED}ERROR${NC}] Servicio OpenVPN NO está activo"
    echo ""
    echo "Iniciando servicio..."
    sudo systemctl start openvpn@server
    sleep 2
fi

echo ""
systemctl status openvpn@server --no-pager -l
echo ""

# 2. Puerto de escucha
echo "2. PUERTO DE ESCUCHA"
echo "--------------------"
if ss -tulpn | grep -q openvpn; then
    echo -e "[${GREEN}OK${NC}] OpenVPN está escuchando:"
    ss -tulpn | grep openvpn
else
    echo -e "[${RED}ERROR${NC}] OpenVPN NO está escuchando en ningún puerto"
fi
echo ""

# 3. Interfaz TUN
echo "3. INTERFAZ TUN"
echo "---------------"
if ip addr show tun0 &>/dev/null; then
    echo -e "[${GREEN}OK${NC}] Interfaz tun0 existe:"
    ip addr show tun0
else
    echo -e "[${RED}ERROR${NC}] Interfaz tun0 NO existe"
fi
echo ""

# 4. Reglas de firewall
echo "4. REGLAS DE FIREWALL"
echo "---------------------"
echo "NAT (MASQUERADE):"
iptables -t nat -L POSTROUTING -n -v | grep "10.8.0.0/24"
echo ""
echo "INPUT (tun0):"
iptables -L INPUT -n -v | grep tun0
echo ""
echo "FORWARD:"
iptables -L FORWARD -n -v | grep tun0
echo ""

# 5. IP Forwarding
echo "5. IP FORWARDING"
echo "----------------"
ipv4_forward=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ $ipv4_forward == "1" ]]; then
    echo -e "[${GREEN}OK${NC}] IPv4 forwarding habilitado"
else
    echo -e "[${RED}ERROR${NC}] IPv4 forwarding deshabilitado"
fi
echo ""

# 6. Certificados
echo "6. CERTIFICADOS"
echo "---------------"
cd /etc/openvpn/easy-rsa/ || exit 1

SERVER_NAME=$(cat SERVER_NAME_GENERATED 2>/dev/null || echo "server")

echo "Certificado del servidor:"
if [[ -f "pki/issued/${SERVER_NAME}.crt" ]]; then
    echo -e "[${GREEN}OK${NC}] Certificado del servidor existe"
    openssl x509 -in "pki/issued/${SERVER_NAME}.crt" -noout -subject -dates
else
    echo -e "[${RED}ERROR${NC}] Certificado del servidor NO encontrado"
fi
echo ""

echo "CA (Autoridad Certificadora):"
if [[ -f "/etc/openvpn/ca.crt" ]]; then
    echo -e "[${GREEN}OK${NC}] CA existe"
    openssl x509 -in /etc/openvpn/ca.crt -noout -subject -dates
else
    echo -e "[${RED}ERROR${NC}] CA NO encontrada"
fi
echo ""

echo "Clientes válidos:"
num_valid=$(tail -n +2 pki/index.txt 2>/dev/null | grep -c "^V" || echo "0")
echo "Total: $num_valid"
tail -n +2 pki/index.txt 2>/dev/null | grep "^V" | cut -d '=' -f 2 | nl
echo ""

echo "Clientes revocados:"
num_revoked=$(tail -n +2 pki/index.txt 2>/dev/null | grep -c "^R" || echo "0")
echo "Total: $num_revoked"
if [[ $num_revoked -gt 0 ]]; then
    tail -n +2 pki/index.txt | grep "^R" | cut -d '=' -f 2 | nl
fi
echo ""

# 7. CRL
echo "7. CERTIFICATE REVOCATION LIST (CRL)"
echo "-------------------------------------"
if [[ -f "/etc/openvpn/crl.pem" ]]; then
    echo -e "[${GREEN}OK${NC}] CRL existe"
    crl_info=$(openssl crl -in /etc/openvpn/crl.pem -noout -nextupdate 2>/dev/null)
    echo "$crl_info"
else
    echo -e "[${RED}ERROR${NC}] CRL NO encontrada"
fi
echo ""

# 8. Configuración del servidor
echo "8. CONFIGURACIÓN DEL SERVIDOR"
echo "------------------------------"
if [[ -f "/etc/openvpn/server.conf" ]]; then
    echo "Puerto y protocolo:"
    grep "^port\|^proto" /etc/openvpn/server.conf
    echo ""
    echo "Red VPN:"
    grep "^server\|^topology" /etc/openvpn/server.conf
    echo ""
    echo "DNS:"
    grep "push.*DNS" /etc/openvpn/server.conf
else
    echo -e "[${RED}ERROR${NC}] server.conf NO encontrado"
fi
echo ""

# 9. Últimas líneas del log
echo "9. ÚLTIMAS LÍNEAS DEL LOG"
echo "-------------------------"
journalctl -u openvpn@server -n 20 --no-pager
echo ""

# 10. Clientes conectados actualmente
echo "10. CLIENTES CONECTADOS"
echo "-----------------------"
if [[ -f "/var/log/openvpn/status.log" ]]; then
    echo "Estado actual:"
    cat /var/log/openvpn/status.log
else
    echo "No hay archivo de estado"
fi
echo ""

echo "============================================="
echo "Diagnóstico completado"
echo "============================================="