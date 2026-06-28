#!/usr/bin/env bash
# Caza de persistencia en Linux (threat hunting, SOLO LECTURA).
# Revisa los mecanismos por los que el malware suele sobrevivir a reinicios.
# No es un antivirus: marca cosas a REVISAR, no confirma compromiso.
#
# Uso:  sudo bash detect-persistence.sh
set -uo pipefail

RC=0
flag() { echo "[REVISAR] $*"; RC=1; }
okay() { echo "[OK]      $*"; }

echo "=== Caza de persistencia (Linux) ==="

# 1. Cron sospechoso (descargas/ejecuciones inline)
susp_cron=$(grep -rsiE 'curl|wget|base64|/tmp/|/dev/shm|nc |ncat|bash -i|python -c' \
  /etc/cron* /var/spool/cron 2>/dev/null | head -20)
[[ -n "$susp_cron" ]] && { flag "Cron con patrones sospechosos:"; echo "$susp_cron" | sed 's/^/    /'; } || okay "Cron sin patrones sospechosos evidentes"

# 2. Servicios/timers systemd que ejecutan desde rutas temporales
susp_unit=$(grep -rsiE 'ExecStart=.*(/tmp/|/dev/shm/|/var/tmp/)' /etc/systemd /lib/systemd /run/systemd 2>/dev/null)
[[ -n "$susp_unit" ]] && { flag "Unidades systemd que ejecutan desde rutas temporales:"; echo "$susp_unit" | sed 's/^/    /'; } || okay "Sin unidades systemd ejecutando desde /tmp"

# 3. Persistencia en perfiles de shell y rc.local
for f in /etc/rc.local /etc/profile /root/.bashrc /root/.profile /root/.bash_profile; do
  [[ -f "$f" ]] || continue
  hits=$(grep -nEi 'curl|wget|base64 -d|/dev/tcp/|nc |bash -i|python -c|eval ' "$f" 2>/dev/null)
  [[ -n "$hits" ]] && { flag "Patrones sospechosos en $f:"; echo "$hits" | sed 's/^/    /'; }
done

# 4. LD_PRELOAD / librerias precargadas (hijacking)
if [[ -s /etc/ld.so.preload ]]; then flag "/etc/ld.so.preload NO esta vacio:"; sed 's/^/    /' /etc/ld.so.preload; else okay "/etc/ld.so.preload vacio o ausente"; fi
env | grep -q '^LD_PRELOAD=' && flag "LD_PRELOAD definido en el entorno actual" || true

# 5. Claves SSH autorizadas (posible puerta trasera)
for h in /root /home/*; do
  ak="$h/.ssh/authorized_keys"
  [[ -f "$ak" ]] && echo "[INFO]    Claves autorizadas en $ak: $(grep -c . "$ak" 2>/dev/null)"
done

# 6. Cuentas con UID 0 ademas de root
extra=$(awk -F: '($3==0 && $1!="root"){print $1}' /etc/passwd)
[[ -n "$extra" ]] && flag "Cuentas con UID 0 ademas de root: $extra" || okay "Solo root con UID 0"

# 7. Binarios SUID fuera de rutas estandar
susp_suid=$(find / -xdev -type f -perm -4000 2>/dev/null | grep -vE '^/(usr/bin|usr/sbin|bin|sbin|usr/lib|usr/libexec)/' | head -20)
[[ -n "$susp_suid" ]] && { flag "SUID en rutas no estandar:"; echo "$susp_suid" | sed 's/^/    /'; } || okay "SUID solo en rutas estandar"

# 8. Procesos ejecutando desde rutas temporales
susp_proc=$(ls -l /proc/*/exe 2>/dev/null | grep -E '/tmp/|/dev/shm/|/var/tmp/' | head)
[[ -n "$susp_proc" ]] && { flag "Procesos ejecutando desde rutas temporales:"; echo "$susp_proc" | sed 's/^/    /'; } || okay "Sin procesos desde /tmp"

echo "----------------------------------------"
[[ "$RC" -eq 0 ]] && echo "RESULTADO: sin indicadores evidentes (no descarta compromiso)." || echo "RESULTADO: hay elementos [REVISAR] arriba."
exit $RC
