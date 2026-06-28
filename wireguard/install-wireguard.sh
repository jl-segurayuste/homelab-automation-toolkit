#!/usr/bin/env bash
# Instala y configura un servidor WireGuard de forma segura en Debian/Ubuntu.
# Genera las claves EN EL HOST (nunca se incrustan ni se versionan).
#
# Uso:
#   sudo WG_ADDR=10.10.0.1/24 WG_PORT=51820 WAN_IF=eth0 bash install-wireguard.sh
set -euo pipefail

WG_IF="${WG_IF:-wg0}"
WG_ADDR="${WG_ADDR:-10.10.0.1/24}"     # red interna de la VPN
WG_PORT="${WG_PORT:-51820}"
WAN_IF="${WAN_IF:-$(ip route show default 2>/dev/null | awk '{print $5; exit}')}"
WG_DIR="/etc/wireguard"

[[ $EUID -eq 0 ]] || { echo "[ERROR] Ejecuta como root." >&2; exit 1; }

echo "[*] Instalando WireGuard..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y wireguard wireguard-tools

umask 077
mkdir -p "$WG_DIR"

if [[ ! -f "$WG_DIR/server_private.key" ]]; then
  echo "[*] Generando claves del servidor..."
  wg genkey | tee "$WG_DIR/server_private.key" | wg pubkey > "$WG_DIR/server_public.key"
  chmod 600 "$WG_DIR/server_private.key"
fi
SERVER_PRIV=$(cat "$WG_DIR/server_private.key")

echo "[*] Activando reenvio IP..."
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-wireguard.conf
sysctl -q --system

echo "[*] Escribiendo $WG_DIR/$WG_IF.conf..."
cat > "$WG_DIR/$WG_IF.conf" <<EOF
[Interface]
Address = $WG_ADDR
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIV
# NAT de salida hacia internet
PostUp   = iptables -t nat -A POSTROUTING -o $WAN_IF -j MASQUERADE; iptables -A FORWARD -i $WG_IF -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $WAN_IF -j MASQUERADE; iptables -D FORWARD -i $WG_IF -j ACCEPT

# Anade peers con add-peer.sh
EOF
chmod 600 "$WG_DIR/$WG_IF.conf"

systemctl enable --now "wg-quick@$WG_IF"
echo "[OK] WireGuard activo en $WG_IF ($WG_ADDR, puerto $WG_PORT/udp)."
echo "Clave publica del servidor: $(cat "$WG_DIR/server_public.key")"
echo "Recuerda: abre solo $WG_PORT/udp en el firewall. Anade clientes con add-peer.sh"
