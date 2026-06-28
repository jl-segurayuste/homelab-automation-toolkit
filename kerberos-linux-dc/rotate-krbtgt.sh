#!/usr/bin/env bash
# Rota la contrasena de la cuenta krbtgt en un Samba AD DC.
# Por que: la clave de krbtgt firma TODOS los TGT. Si se ve comprometida, un atacante
# puede forjar "Golden Tickets". Rotarla (DOS veces, con margen) invalida esos tickets.
#
# IMPORTANTE:
#   - Hazlo en una VENTANA DE MANTENIMIENTO.
#   - Ejecuta la rotacion DOS veces separadas por > la vida maxima de ticket
#     (p.ej. 10-24h) para no invalidar tickets legitimos de golpe.
#   - Con varios DCs, deja replicar entre la 1a y la 2a rotacion.
#
# Uso:  sudo bash rotate-krbtgt.sh        (pide confirmacion)
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "[ERROR] Ejecuta como root en el DC." >&2; exit 1; }
command -v samba-tool >/dev/null 2>&1 || { echo "[ERROR] samba-tool no disponible." >&2; exit 1; }

cat <<'EOF'
Vas a ROTAR la contrasena de krbtgt. Esto invalida tickets Kerberos existentes.
Recuerda: ejecuta DOS veces con margen (> vida de ticket) y deja replicar entre DCs.
EOF
read -r -p "Escribe ROTAR para continuar: " ans
[[ "$ans" == "ROTAR" ]] || { echo "Cancelado."; exit 0; }

ts=$(date +%Y%m%d-%H%M%S)
echo "[*] Estado previo de krbtgt (msDS-KeyVersionNumber):"
samba-tool user show krbtgt 2>/dev/null | grep -iE 'KeyVersionNumber|pwdLastSet' || true

echo "[*] Rotando con contrasena aleatoria..."
samba-tool user setpassword krbtgt --random-password

echo "[OK] krbtgt rotada ($ts)."
echo "Repite esta rotacion tras > la vida maxima de ticket (y tras replicar entre DCs)."
echo "Verifica replicacion con: samba-tool drs showrepl"
