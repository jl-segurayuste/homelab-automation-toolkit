#!/usr/bin/env bash
# Genera un keytab Kerberos para un principal, forzando cifrados FUERTES (solo AES).
# Soporta dos modos:
#   - DC (Samba AD): exporta el keytab con samba-tool (ejecutar en el DC).
#   - Cliente (MIT krb5): lo crea con ktutil pidiendo la contrasena de forma interactiva.
#
# Salt de las claves AES (modo cliente). ktutil, si no se le indica, usa el salt por defecto de MIT:
# REALM + las partes del principal (postgres/db1.ejemplo.lan@EJEMPLO.LAN -> EJEMPLO.LANpostgresdb1.ejemplo.lan).
# Active Directory y Samba AD calculan las claves de la CUENTA con otro salt, y un SPN usa las de su cuenta:
#   - cuenta de usuario (tambien las de servicio): REALM + sAMAccountName exacto -> EJEMPLO.LANsvc-postgres
#   - cuenta de equipo: REALM + "host" + nombre DNS completo en minusculas (coincide con el de host/<fqdn>)
# Con el salt equivocado las claves AES no valen y el servicio no puede descifrar los tickets en cuanto la cuenta
# deja de admitir RC4. Por eso, en modo cliente, un principal con "/" exige --account o --salt (o --default-salt
# si el KDC es MIT o es el host/ de una cuenta de equipo).
#
# El keytab es material sensible: se crea con permisos 600 y NUNCA debe versionarse.
#
# Uso:
#   sudo bash generate-keytab.sh <principal> <ruta_keytab> --samba
#   bash generate-keytab.sh <principal> <ruta_keytab> [--account <sAMAccountName> | --salt <salt> | --default-salt]
# Ejemplos:
#   sudo bash generate-keytab.sh host/web1.example.lan /etc/krb5.keytab --samba
#   KVNO=2 bash generate-keytab.sh postgres/db1.ejemplo.lan@EJEMPLO.LAN ./postgres.keytab --account svc-postgres
#   KVNO=3 bash generate-keytab.sh usuario@EJEMPLO.LAN ./usuario.keytab
# Variables: KVNO (debe ser el de la cuenta: msDS-KeyVersionNumber en AD; def: 1), ENCTYPES.
set -euo pipefail

USO="Uso: generate-keytab.sh <principal> <ruta_keytab> [--samba | --account <sAMAccountName> | --salt <salt> | --default-salt]"
PRINCIPAL="${1:?$USO}"
KEYTAB="${2:?$USO}"
shift 2
MODE="ktutil"
ACCOUNT=""
SALT="${SALT:-}"
DEFAULT_SALT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --samba)        MODE="samba"; shift ;;
    --account)      ACCOUNT="${2:?Falta el sAMAccountName tras --account}"; shift 2 ;;
    --salt)         SALT="${2:?Falta el salt tras --salt}"; shift 2 ;;
    --default-salt) DEFAULT_SALT=1; shift ;;
    *) echo "[ERROR] Opcion desconocida: $1" >&2; echo "$USO" >&2; exit 2 ;;
  esac
done
ENCTYPES="${ENCTYPES:-aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96}"

umask 077

if [[ "$MODE" == "samba" ]]; then
  command -v samba-tool >/dev/null 2>&1 || { echo "[ERROR] samba-tool no disponible (ejecuta en el DC)." >&2; exit 1; }
  # samba-tool exporta las claves que el DC ya tiene: no depende del salt.
  echo "[*] Exportando keytab para '$PRINCIPAL' con samba-tool..."
  samba-tool domain exportkeytab "$KEYTAB" --principal="$PRINCIPAL"
else
  command -v ktutil >/dev/null 2>&1 || { echo "[ERROR] ktutil no disponible (instala krb5-user)." >&2; exit 1; }

  # Realm: el del principal o, si no lo lleva, el default_realm de krb5.conf
  if [[ "$PRINCIPAL" == *@* ]]; then
    REALM="${PRINCIPAL##*@}"
  else
    REALM="$(awk -F= '/^[[:space:]]*default_realm[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' /etc/krb5.conf 2>/dev/null || true)"
    [[ -n "$REALM" ]] || { echo "[ERROR] El principal no lleva @REALM y no hay default_realm en /etc/krb5.conf." >&2; exit 1; }
    PRINCIPAL="${PRINCIPAL}@${REALM}"
  fi
  NAME="${PRINCIPAL%@*}"

  if [[ -n "$ACCOUNT" && -n "$SALT" ]]; then
    echo "[ERROR] Usa --account o --salt, no los dos." >&2; exit 2
  fi
  [[ -n "$ACCOUNT" ]] && SALT="${REALM}${ACCOUNT}"
  if [[ -z "$SALT" && "$NAME" == */* && $DEFAULT_SALT -eq 0 ]]; then
    cat >&2 <<EOF
[ERROR] '$PRINCIPAL' es un principal de servicio (SPN). Con Active Directory o Samba AD sus claves son las de la
        cuenta que tiene el SPN y se calculan con el salt de esa cuenta, no con el del SPN. Indica la cuenta:
          --account <sAMAccountName>      (salt ${REALM}<sAMAccountName>, con sus mayusculas exactas)
        o el salt directamente con --salt. Si el KDC es MIT, o es el host/ de una cuenta de equipo, usa --default-salt.
EOF
    exit 2
  fi
  if [[ -n "$SALT" ]] && ! printf 'addent\nquit\n' | ktutil 2>&1 | grep -q -- '-s salt'; then
    echo "[ERROR] Este ktutil no admite -s (salt); hace falta krb5 1.18 o superior (RHEL 8, Debian 11)." >&2; exit 1
  fi
  if [[ -z "$SALT" && "$NAME" != */* ]]; then
    echo "[*] Salt por defecto (${REALM}${NAME}): con AD solo vale si '${NAME}' esta escrito exactamente como su sAMAccountName."
  fi

  KVNO="${KVNO:-1}"
  [[ "$KVNO" =~ ^[0-9]+$ ]] || { echo "[ERROR] KVNO no valido: '$KVNO'." >&2; exit 2; }
  [[ -e "$KEYTAB" ]] && { echo "[ERROR] '$KEYTAB' ya existe: ktutil anadiria las entradas en lugar de sustituirlas. Muevelo antes." >&2; exit 1; }

  echo "[*] Generando keytab con ktutil para '$PRINCIPAL' (solo AES, KVNO $KVNO${SALT:+, salt $SALT})."
  echo "    El KVNO debe ser el de la cuenta (msDS-KeyVersionNumber en AD)."
  read -rs -p "Contrasena de la cuenta (no se mostrara): " KPW; echo
  {
    for e in $ENCTYPES; do
      echo "addent -password -p ${PRINCIPAL} -k ${KVNO} -e ${e}${SALT:+ -s ${SALT}}"
      echo "${KPW}"
    done
    echo "wkt ${KEYTAB}"
    echo "quit"
  } | ktutil >/dev/null
  unset KPW
  [[ -f "$KEYTAB" ]] || { echo "[ERROR] ktutil no ha creado el keytab." >&2; exit 1; }
fi

chmod 600 "$KEYTAB"
echo "[OK] Keytab creado: $KEYTAB (permisos 600)"
echo "[*] Contenido (enctypes):"
klist -kte "$KEYTAB" 2>/dev/null || true

# Aviso si hay cifrados debiles
if klist -kte "$KEYTAB" 2>/dev/null | grep -qiE 'arcfour|rc4|des-cbc|des-cbc-crc|des3'; then
  echo "[WARN] El keytab contiene cifrados DEBILES (no-AES). Regeneralo solo con AES."
fi

# klist -kte solo lista las entradas; la prueba de que las claves son las del KDC es descifrar un ticket real.
if [[ "${PRINCIPAL%@*}" == */* ]]; then
  if klist -s 2>/dev/null; then
    echo "[*] Comprobacion con un ticket real (kvno -k):"
    if kvno -k "$KEYTAB" "$PRINCIPAL"; then
      ETYPE="$(klist -e 2>/dev/null | grep -A2 " ${PRINCIPAL}" | grep -o 'Etype (skey, tkt): .*' | awk '{print $NF}')"
      echo "[OK] El keytab descifra el ticket (cifrado del ticket: ${ETYPE:-desconocido})."
      [[ "$ETYPE" == aes* ]] || echo "[WARN] El ticket no era AES: las claves AES no se han probado."
    else
      echo "[ERROR] El keytab NO descifra el ticket del KDC (salt, KVNO o contrasena equivocados)." >&2
      exit 1
    fi
  else
    echo "[*] Para comprobarlo: kinit <usuario>; kvno -k $KEYTAB $PRINCIPAL  (debe decir 'keytab entry valid' con un ticket AES)"
  fi
fi
echo "Recuerda: NO subas el keytab a git. Distribuyelo por canal seguro."
