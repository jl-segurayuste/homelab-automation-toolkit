#!/bin/bash
# check-vpn-certs.sh

CERT_DIR="/etc/openvpn/easy-rsa/pki/issued"
WARN_DAYS=30

echo "Verificando certificados OpenVPN..."
echo ""

for cert in "$CERT_DIR"/*.crt; do
    if [[ -f "$cert" ]]; then
        cert_name=$(basename "$cert" .crt)
        expiry_date=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
        
        if [[ $days_left -lt 0 ]]; then
            echo "[EXPIRADO] $cert_name - Expiró hace $((-days_left)) días"
        elif [[ $days_left -lt $WARN_DAYS ]]; then
            echo "[AVISO] $cert_name - Expira en $days_left días ($expiry_date)"
        else
            echo "[OK] $cert_name - Expira en $days_left días"
        fi
    fi
done