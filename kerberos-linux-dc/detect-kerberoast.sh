#!/usr/bin/env bash
# Deteccion DEFENSIVA (solo lectura) de cuentas expuestas a ataques Kerberos en un
# Samba AD DC:
#   - Kerberoasting : cuentas de USUARIO con servicePrincipalName (SPN) -> tickets
#                     de servicio crackeables offline.
#   - AS-REP roasting: cuentas con "no requerir preautenticacion" (DONT_REQ_PREAUTH).
#   - Cifrado debil  : cuentas que aun permiten RC4 (sin AES).
#
# Uso (en el DC):  sudo bash detect-kerberoast.sh
set -uo pipefail

RC=0
warn() { echo "[WARN] $*"; RC=1; }
okay() { echo "[OK]   $*"; }

command -v samba-tool >/dev/null 2>&1 || { echo "samba-tool no disponible (ejecuta en el DC)."; exit 2; }

echo "=== Deteccion de exposicion Kerberos (Samba AD) ==="

mapfile -t USERS < <(samba-tool user list 2>/dev/null)
[[ ${#USERS[@]} -gt 0 ]] || { echo "No se pudo listar usuarios."; exit 2; }

kerberoast=0; asrep=0; rc4=0

for u in "${USERS[@]}"; do
  [[ -z "$u" ]] && continue
  show=$(samba-tool user show "$u" 2>/dev/null) || continue

  # Kerberoasting: SPN en cuenta de usuario (krbtgt se ignora)
  if [[ "$u" != "krbtgt" ]] && echo "$show" | grep -qiE '^servicePrincipalName'; then
    warn "Kerberoastable (SPN en cuenta de usuario): $u"
    kerberoast=$((kerberoast+1))
  fi

  # AS-REP roasting: DONT_REQ_PREAUTH (0x400000)
  uac=$(echo "$show" | awk -F: '/userAccountControl/{gsub(/ /,"",$2); print $2; exit}')
  if [[ -n "${uac:-}" && "$uac" =~ ^[0-9]+$ ]] && (( uac & 0x400000 )); then
    warn "AS-REP roastable (sin preautenticacion): $u"
    asrep=$((asrep+1))
  fi

  # RC4 permitido: msDS-SupportedEncryptionTypes sin el bit AES, o con bit RC4 (0x4)
  enc=$(echo "$show" | awk -F: '/msDS-SupportedEncryptionTypes/{gsub(/ /,"",$2); print $2; exit}')
  if [[ -n "${enc:-}" && "$enc" =~ ^[0-9]+$ ]]; then
    # bits AES = 0x8 (aes128) | 0x10 (aes256) ; RC4 = 0x4
    if (( (enc & 0x18) == 0 )) || (( enc & 0x4 )); then
      warn "Cifrado debil permitido (RC4/sin AES): $u (enctypes=$enc)"
      rc4=$((rc4+1))
    fi
  fi
done

echo "----------------------------------------"
echo "Kerberoastable: $kerberoast   AS-REP: $asrep   RC4/sin-AES: $rc4"
[[ "$RC" -eq 0 ]] && okay "Sin cuentas expuestas detectadas." || cat <<'EOF'
Recomendaciones:
  - Cuentas de servicio con SPN: usar gMSA o contrasenas largas/aleatorias (>=25),
    y forzar solo AES (msDS-SupportedEncryptionTypes = 24).
  - Quitar "no requerir preautenticacion" salvo necesidad justificada.
  - Eliminar RC4: aplicar AES en cuentas y rotar krbtgt dos veces (rotate-krbtgt.sh).
EOF
exit $RC
