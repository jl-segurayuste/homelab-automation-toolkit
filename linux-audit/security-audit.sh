#!/usr/bin/env bash
# Auditoria de seguridad de un host Linux (solo LECTURA, no cambia nada).
# Revisiones tipo CIS resumidas: cuentas, SSH, firewall, ficheros peligrosos,
# servicios a la escucha, kernel y actualizaciones pendientes.
#
# Uso:  sudo bash security-audit.sh
set -uo pipefail

RC=0
okay() { echo "[OK]   $*"; }
warn() { echo "[WARN] $*"; RC=1; }
note() { echo "[INFO] $*"; }
section() { echo; echo "=== $* ==="; }

echo "###############################################"
echo "#  Auditoria de seguridad Linux  $(date '+%F %T')"
echo "#  Host: $(hostname)"
echo "###############################################"

section "Cuentas y contrasenas"
# UID 0 distintos de root
extra_root=$(awk -F: '($3==0 && $1!="root"){print $1}' /etc/passwd)
[[ -n "$extra_root" ]] && warn "Cuentas con UID 0 ademas de root: $extra_root" || okay "Solo root tiene UID 0"
# Contrasenas vacias
empty_pw=$(awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null)
[[ -n "$empty_pw" ]] && warn "Cuentas con contrasena VACIA: $empty_pw" || okay "Sin contrasenas vacias"
# Cuentas con shell de login sin caducidad de contrasena no se evalua aqui (informativo)
note "Usuarios con shell interactiva: $(grep -E '/(bash|sh|zsh|ksh)$' /etc/passwd | wc -l)"

section "Hardening SSH"
SSHD=/etc/ssh/sshd_config
if [[ -f "$SSHD" ]]; then
  grep -qiE '^\s*PermitRootLogin\s+(no|prohibit-password)' "$SSHD" && okay "PermitRootLogin restringido" || warn "PermitRootLogin permite root con contrasena"
  grep -qiE '^\s*PasswordAuthentication\s+no' "$SSHD" && okay "PasswordAuthentication no (solo claves)" || warn "PasswordAuthentication habilitado"
  grep -qiE '^\s*PermitEmptyPasswords\s+no' "$SSHD" && okay "PermitEmptyPasswords no" || warn "PermitEmptyPasswords no esta en 'no'"
  grep -qiE '^\s*X11Forwarding\s+no' "$SSHD" && okay "X11Forwarding no" || note "X11Forwarding habilitado"
else
  note "No hay sshd_config (sin servidor SSH?)"
fi

section "Firewall"
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi 'Status: active'; then
  okay "UFW activo"
elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state 2>/dev/null | grep -qi running; then
  okay "firewalld activo"
elif command -v nft >/dev/null 2>&1 && nft list ruleset 2>/dev/null | grep -q 'chain'; then
  okay "nftables con reglas cargadas"
else
  warn "No se detecta firewall activo (UFW/firewalld/nftables)"
fi

section "Ficheros peligrosos"
note "Buscando SUID/SGID inusuales (puede tardar)..."
suid=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
note "Binarios SUID/SGID encontrados: $suid (revisa con: find / -xdev -perm -4000 -type f)"
ww=$(find / -xdev -type f -perm -0002 2>/dev/null | grep -vE '^/proc|^/sys' | wc -l)
[[ "$ww" -gt 0 ]] && warn "Ficheros escribibles por cualquiera (world-writable): $ww" || okay "Sin ficheros world-writable"

section "Servicios a la escucha"
note "Puertos en escucha:"
ss -tulnH 2>/dev/null | awk '{print "   "$1" "$5}' | sort -u | head -30
pub=$(ss -tulnH 2>/dev/null | awk '{print $5}' | grep -E '^0\.0\.0\.0:|^\[::\]:' | wc -l)
[[ "$pub" -gt 0 ]] && note "Sockets escuchando en todas las interfaces: $pub (limita a 127.0.0.1 lo que no deba ser publico)"

section "Kernel / sysctl"
check_sysctl() { v=$(sysctl -n "$1" 2>/dev/null); [[ "$v" == "$2" ]] && okay "$1 = $2" || warn "$1 = ${v:-?} (recomendado $2)"; }
check_sysctl net.ipv4.conf.all.rp_filter 1
check_sysctl net.ipv4.tcp_syncookies 1
check_sysctl net.ipv4.conf.all.accept_redirects 0
check_sysctl kernel.randomize_va_space 2

section "Actualizaciones pendientes"
if command -v apt-get >/dev/null 2>&1; then
  upd=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
  sec=$(apt-get -s upgrade 2>/dev/null | grep -i security | grep -c '^Inst' || true)
  [[ "$sec" -gt 0 ]] && warn "Actualizaciones de SEGURIDAD pendientes: $sec (total: $upd)" || okay "Sin actualizaciones de seguridad pendientes ($upd totales)"
elif command -v dnf >/dev/null 2>&1; then
  sec=$(dnf -q updateinfo list security 2>/dev/null | grep -c '/' || true)
  [[ "$sec" -gt 0 ]] && warn "Actualizaciones de seguridad pendientes: $sec" || okay "Sin actualizaciones de seguridad pendientes"
fi

echo
echo "###############################################"
[[ "$RC" -eq 0 ]] && echo "RESULTADO: sin hallazgos criticos." || echo "RESULTADO: revisa los [WARN] de arriba."
echo "###############################################"
exit $RC
