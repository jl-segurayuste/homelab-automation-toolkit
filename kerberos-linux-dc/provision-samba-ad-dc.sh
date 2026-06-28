#!/usr/bin/env bash
# Provisiona un Controlador de Dominio (Active Directory) sobre Linux con Samba 4 + Kerberos.
# Orientado a seguridad: fuerza tipos de cifrado fuertes y deja apuntes de hardening.
#
# Probado en Debian/Ubuntu. Ejecutar como root en un host DEDICADO (un DC no debe
# compartir funciones). Revisa y ajusta las variables antes de ejecutar.
#
# Uso:
#   sudo REALM=EXAMPLE.LAN DOMAIN=EXAMPLE bash provision-samba-ad-dc.sh
set -euo pipefail

REALM="${REALM:-EXAMPLE.LAN}"          # realm Kerberos en MAYUSCULAS
DOMAIN="${DOMAIN:-EXAMPLE}"            # nombre NetBIOS
DNS_FORWARDER="${DNS_FORWARDER:-1.1.1.1}"
DC_HOSTNAME="${DC_HOSTNAME:-dc1}"

if [[ $EUID -ne 0 ]]; then echo "[ERROR] Ejecuta como root." >&2; exit 1; fi

echo "=== Provision Samba AD DC ==="
echo "Realm=$REALM  Domain=$DOMAIN  Host=$DC_HOSTNAME"

# La contrasena del Administrador NO se pone en el script: se pide de forma interactiva.
read -rs -p "Contrasena para el Administrador del dominio (no se mostrara): " ADMIN_PW; echo
[[ ${#ADMIN_PW} -ge 12 ]] || { echo "[ERROR] Usa una contrasena de >=12 caracteres." >&2; exit 1; }

echo "[*] Instalando paquetes..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y samba krb5-config krb5-user winbind libnss-winbind libpam-winbind dnsutils

echo "[*] Deteniendo servicios que interfieren con el DC..."
systemctl disable --now smbd nmbd winbind 2>/dev/null || true

# Backups de configs previas
[[ -f /etc/samba/smb.conf ]] && mv /etc/samba/smb.conf /etc/samba/smb.conf.bak.$(date +%s)

echo "[*] Provisionando dominio..."
samba-tool domain provision \
  --use-rfc2307 \
  --realm="$REALM" \
  --domain="$DOMAIN" \
  --server-role=dc \
  --dns-backend=SAMBA_INTERNAL \
  --adminpass="$ADMIN_PW" \
  --option="dns forwarder=$DNS_FORWARDER"
unset ADMIN_PW

echo "[*] Configurando Kerberos del host..."
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

echo "[*] Habilitando el servicio unificado samba-ad-dc..."
systemctl unmask samba-ad-dc
systemctl enable --now samba-ad-dc

echo
echo "=== Provision completada ==="
echo "Verifica con:"
echo "  samba-tool domain level show"
echo "  kinit administrator@$REALM"
echo "  klist"
echo
echo "SIGUIENTE PASO DE SEGURIDAD: ejecuta harden-kerberos.sh y kerberos-security-audit.sh"
