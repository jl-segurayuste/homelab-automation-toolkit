#!/bin/bash
# check-vpn-certs.sh - Caducidad de los certificados emitidos por la PKI de OpenVPN.
#
# Configuración por variables de entorno:
#   CERT_DIR   carpeta con los .crt emitidos (por defecto, la del instalador del toolkit)
#   WARN_DAYS  días de antelación para el aviso (por defecto 30)
#
# Código de salida: 0 todo en orden, 1 hay certificados caducados o a punto de caducar,
# 2 no se pudo revisar (carpeta inexistente o sin certificados). Antes salía 0 siempre y, si la
# carpeta no existía, no imprimía nada: parecía que todo estaba bien.

set -uo pipefail

CERT_DIR="${CERT_DIR:-/etc/openvpn/easy-rsa/pki/issued}"
WARN_DAYS="${WARN_DAYS:-30}"

if [[ -t 1 ]]; then
    RED=$'\e[31m' YELLOW=$'\e[33m' GREEN=$'\e[32m' BOLD=$'\e[1m' RESET=$'\e[0m'
else
    RED="" YELLOW="" GREEN="" BOLD="" RESET=""
fi

if [[ ! -d "$CERT_DIR" ]]; then
    echo "ERROR: no existe $CERT_DIR (ajusta CERT_DIR)" >&2
    exit 2
fi

echo "Verificando certificados OpenVPN en $CERT_DIR (aviso a $WARN_DAYS días)..."
echo ""

total=0 ok=0 warn=0 expired=0
now=$(date +%s)
shopt -s nullglob
for cert in "$CERT_DIR"/*.crt; do
    cert_name=$(basename "$cert" .crt)
    total=$((total + 1))
    expiry_date=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [[ -z "$expiry_date" ]]; then
        echo "${RED}[ILEGIBLE]${RESET} $cert_name - no es un certificado X.509 válido"
        expired=$((expired + 1))
        continue
    fi
    days_left=$(( ($(date -d "$expiry_date" +%s) - now) / 86400 ))

    if (( days_left < 0 )); then
        echo "${RED}[EXPIRADO]${RESET} $cert_name - Expiró hace $((-days_left)) días"
        expired=$((expired + 1))
    elif (( days_left < WARN_DAYS )); then
        echo "${YELLOW}[AVISO]${RESET} $cert_name - Expira en $days_left días ($expiry_date)"
        warn=$((warn + 1))
    else
        echo "${GREEN}[OK]${RESET} $cert_name - Expira en $days_left días"
        ok=$((ok + 1))
    fi
done

if (( total == 0 )); then
    echo "ERROR: no hay ningún .crt en $CERT_DIR" >&2
    exit 2
fi

echo ""
echo "${BOLD}Total: $total certificado(s) — $ok OK, $warn por caducar, $expired caducado(s) o ilegible(s)${RESET}"
(( warn + expired > 0 )) && exit 1
exit 0
