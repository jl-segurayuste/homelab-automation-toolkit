#!/bin/bash
# Reglas UFW base para un servidor: deny entrante por defecto, SSH restringido a
# redes de confianza y ejemplos comentados para servicios habituales.
# Ajusta las subredes (LAN_CIDR / VPN_CIDR) y los puertos a tu entorno.
# Ejecutar con: sudo bash setup-firewall.sh
set -e

LAN_CIDR="192.168.1.0/24"      # tu red local
VPN_CIDR="192.168.255.0/24"    # tu red VPN (si la usas)

echo "=== Configurando UFW ==="

# Politica por defecto
ufw default deny incoming
ufw default allow outgoing

# SSH - solo desde redes de confianza
ufw allow from "$LAN_CIDR" to any port 22 comment "SSH LAN"
ufw allow from "$VPN_CIDR" to any port 22 comment "SSH VPN"

# --- Ejemplos (descomenta los que necesites) ---
# VPN OpenVPN (publico)
# ufw allow 1194/udp comment "OpenVPN"
# DNS interno (solo LAN/VPN)
# ufw allow from "$LAN_CIDR" to any port 53 comment "DNS LAN"
# ufw allow from "$VPN_CIDR" to any port 53 comment "DNS VPN"
# Reverse proxy (publico)
# ufw allow 80/tcp comment "HTTP"
# ufw allow 443/tcp comment "HTTPS"

# Habilitar
ufw --force enable
ufw status verbose

echo "=== Firewall configurado ==="
