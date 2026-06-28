#!/usr/bin/env bash
# Anade un peer (cliente) a un servidor WireGuard y genera su config de cliente.
# Las claves del cliente se generan al vuelo; la privada solo va en su config.
#
# Uso:
#   sudo bash add-peer.sh <nombre_peer> <ip_vpn_cliente>
#   sudo bash add-peer.sh portatil 10.10.0.2
set -euo pipefail

WG_IF="${WG_IF:-wg0}"
WG_DIR="/etc/wireguard"
DNS="${DNS:-1.1.1.1}"
ALLOWED="${ALLOWED:-0.0.0.0/0}"          # 0.0.0.0/0 = todo el trafico por la VPN
ENDPOINT="${ENDPOINT:-vpn.example.com}"  # host:puerto publico del servidor

PEER_NAME="${1:?Uso: add-peer.sh <nombre> <ip_vpn>}"
PEER_IP="${2:?Falta la IP VPN del cliente, p.ej. 10.10.0.2}"

[[ $EUID -eq 0 ]] || { echo "[ERROR] Ejecuta como root." >&2; exit 1; }
[[ -f "$WG_DIR/$WG_IF.conf" ]] || { echo "[ERROR] No existe $WG_DIR/$WG_IF.conf" >&2; exit 1; }

umask 077
SERVER_PUB=$(cat "$WG_DIR/server_public.key")
WG_PORT=$(awk -F'= *' '/ListenPort/{print $2}' "$WG_DIR/$WG_IF.conf")

PEER_PRIV=$(wg genkey)
PEER_PUB=$(echo "$PEER_PRIV" | wg pubkey)
PSK=$(wg genpsk)   # clave precompartida (defensa extra frente a ataques cuanticos)

# Anadir el peer al servidor (en caliente y persistente)
wg set "$WG_IF" peer "$PEER_PUB" preshared-key <(echo "$PSK") allowed-ips "${PEER_IP}/32"
cat >> "$WG_DIR/$WG_IF.conf" <<EOF

[Peer]
# $PEER_NAME
PublicKey = $PEER_PUB
PresharedKey = $PSK
AllowedIPs = ${PEER_IP}/32
EOF

OUT="$WG_DIR/clients/${PEER_NAME}.conf"
mkdir -p "$WG_DIR/clients"
cat > "$OUT" <<EOF
[Interface]
PrivateKey = $PEER_PRIV
Address = ${PEER_IP}/32
DNS = $DNS

[Peer]
PublicKey = $SERVER_PUB
PresharedKey = $PSK
Endpoint = ${ENDPOINT}:${WG_PORT}
AllowedIPs = $ALLOWED
PersistentKeepalive = 25
EOF
chmod 600 "$OUT"

echo "[OK] Peer '$PEER_NAME' anadido. Config del cliente: $OUT"
echo "Entregala por canal seguro (contiene la clave privada del cliente). Para QR:"
echo "  qrencode -t ansiutf8 < $OUT"
