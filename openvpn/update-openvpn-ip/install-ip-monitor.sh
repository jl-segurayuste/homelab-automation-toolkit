#!/bin/bash

# Script de instalación del monitor de IP

set -e

echo "Instalando monitor de IP pública para OpenVPN..."

# Verificar si es root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root" 
   exit 1
fi

# Verificar dependencias
for cmd in curl grep sed awk systemctl; do
    if ! command -v $cmd &> /dev/null; then
        echo "ERROR: $cmd no está instalado"
        exit 1
    fi
done

# Copiar script principal
cp update-openvpn-ip.sh /usr/local/bin/
chmod +x /usr/local/bin/update-openvpn-ip.sh

# Crear servicio systemd
cat > /etc/systemd/system/openvpn-ip-monitor.service << EOF
[Unit]
Description=OpenVPN Public IP Monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/update-openvpn-ip.sh
Restart=always
RestartSec=10
User=root
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=openvpn-ip-monitor

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd
systemctl daemon-reload

# Habilitar y iniciar servicio
systemctl enable openvpn-ip-monitor.service
systemctl start openvpn-ip-monitor.service

echo "Instalación completada"
echo ""
echo "Comandos útiles:"
echo "  Ver estado: systemctl status openvpn-ip-monitor"
echo "  Ver logs: journalctl -u openvpn-ip-monitor -f"
echo "  Ver log detallado: tail -f /var/log/openvpn-ip-update.log"