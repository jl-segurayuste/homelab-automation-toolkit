#!/bin/bash
# backup-vpn.sh

BACKUP_DIR="/backup/vpn"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="vpn_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Iniciando backup de configuración VPN..."

# Backup de configuración
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    /etc/openvpn/ \
    /etc/iptables/ \
    /etc/ufw/ \
    /etc/fail2ban/ \
    2>/dev/null

# Mantener solo últimos 30 días
find "$BACKUP_DIR" -name "vpn_backup_*.tar.gz" -mtime +30 -delete

echo "Backup completado: $BACKUP_DIR/$BACKUP_FILE"

# Listar backups
ls -lh "$BACKUP_DIR"/