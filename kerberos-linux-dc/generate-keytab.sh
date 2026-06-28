#!/usr/bin/env bash
# Genera un keytab Kerberos para un principal, forzando cifrados FUERTES (solo AES).
# Soporta dos modos:
#   - DC (Samba AD): exporta el keytab con samba-tool (ejecutar en el DC).
#   - Cliente (MIT krb5): lo crea con ktutil pidiendo la contrasena de forma interactiva.
#
# El keytab es material sensible: se crea con permisos 600 y NUNCA debe versionarse.
#
# Uso:
#   sudo bash generate-keytab.sh <principal> <ruta_keytab> [--samba]
#   sudo bash generate-keytab.sh host/web1.example.lan /etc/krb5.keytab --samba
#   bash generate-keytab.sh usuario@EXAMPLE.LAN ./usuario.keytab
set -euo pipefail

PRINCIPAL="${1:?Uso: generate-keytab.sh <principal> <ruta_keytab> [--samba]}"
KEYTAB="${2:?Falta la ruta del keytab}"
MODE="${3:-}"
ENCTYPES="${ENCTYPES:-aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96}"

umask 077

if [[ "$MODE" == "--samba" ]]; then
  command -v samba-tool >/dev/null 2>&1 || { echo "[ERROR] samba-tool no disponible (ejecuta en el DC)." >&2; exit 1; }
  echo "[*] Exportando keytab para '$PRINCIPAL' con samba-tool..."
  samba-tool domain exportkeytab "$KEYTAB" --principal="$PRINCIPAL"
else
  command -v ktutil >/dev/null 2>&1 || { echo "[ERROR] ktutil no disponible (instala krb5-user)." >&2; exit 1; }
  echo "[*] Generando keytab con ktutil para '$PRINCIPAL' (solo AES)."
  read -rs -p "Contrasena del principal (no se mostrara): " KPW; echo
  # KVNO: numero de version de clave; usa el actual del KDC si lo conoces (def: 1)
  KVNO="${KVNO:-1}"
  {
    for e in $ENCTYPES; do
      echo "addent -password -p ${PRINCIPAL} -k ${KVNO} -e ${e}"
      echo "${KPW}"
    done
    echo "wkt ${KEYTAB}"
    echo "quit"
  } | ktutil >/dev/null
  unset KPW
fi

chmod 600 "$KEYTAB"
echo "[OK] Keytab creado: $KEYTAB (permisos 600)"
echo "[*] Contenido (enctypes):"
klist -kte "$KEYTAB" 2>/dev/null || true

# Aviso si hay cifrados debiles
if klist -kte "$KEYTAB" 2>/dev/null | grep -qiE 'arcfour|rc4|des-cbc|des-cbc-crc|des3'; then
  echo "[WARN] El keytab contiene cifrados DEBILES (no-AES). Regeneralo solo con AES."
fi
echo "Recuerda: NO subas el keytab a git. Distribuyelo por canal seguro."
