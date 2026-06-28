#!/usr/bin/env bash
# Auditoria de seguridad de Kerberos / Samba AD DC.
# Comprueba configuraciones debiles habituales y cuentas de riesgo. Solo LECTURA.
#
# Uso (en el DC):  sudo bash kerberos-security-audit.sh
set -uo pipefail

RC=0
note() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; RC=1; }
okay() { echo "[OK]   $*"; }

echo "=== Auditoria de seguridad Kerberos / AD DC ==="

# 1. Cifrados debiles en krb5.conf
if [[ -f /etc/krb5.conf ]]; then
  if grep -qiE 'arcfour|rc4|des-cbc|allow_weak_crypto[[:space:]]*=[[:space:]]*true' /etc/krb5.conf; then
    warn "krb5.conf permite cifrados debiles (RC4/DES o allow_weak_crypto=true)."
  else
    okay "krb5.conf sin cifrados debiles evidentes."
  fi
fi

# 2. Herramientas de Samba presentes
if ! command -v samba-tool >/dev/null 2>&1; then
  note "samba-tool no disponible: se omiten comprobaciones de AD."
  exit $RC
fi

# 3. Politica de contrasenas
echo "--- Politica de contrasenas ---"
samba-tool domain passwordsettings show 2>/dev/null || warn "No se pudo leer la politica de contrasenas."

# 4. Cuentas con 'password never expires' (riesgo)
echo "--- Cuentas con contrasena que nunca expira ---"
if samba-tool user list >/dev/null 2>&1; then
  while read -r u; do
    [[ -z "$u" ]] && continue
    if samba-tool user show "$u" 2>/dev/null | grep -qiE 'userAccountControl.*DONT_EXPIRE_PASSWD|PASSWD_NOTREQD'; then
      warn "Cuenta de riesgo (no expira / sin password requerido): $u"
    fi
  done < <(samba-tool user list 2>/dev/null)
fi

# 5. Miembros de grupos privilegiados
echo "--- Miembros de grupos privilegiados ---"
for g in "Domain Admins" "Enterprise Admins" "Schema Admins" "Administrators"; do
  members=$(samba-tool group listmembers "$g" 2>/dev/null | tr '\n' ' ')
  [[ -n "$members" ]] && note "$g: $members"
done

# 6. Nivel funcional del dominio (los bajos limitan controles modernos)
echo "--- Nivel funcional ---"
samba-tool domain level show 2>/dev/null || true

echo
[[ "$RC" -eq 0 ]] && echo "RESULTADO: sin hallazgos criticos." || echo "RESULTADO: revisa los [WARN] de arriba."
exit $RC
