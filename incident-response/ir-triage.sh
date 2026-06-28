#!/usr/bin/env bash
# Triaje de respuesta a incidentes (IR) en Linux: recolecta estado volatil del
# sistema en un directorio con marca de tiempo. SOLO LECTURA (no modifica el host).
# Util para una foto rapida ante sospecha de compromiso, antes de actuar.
#
# Uso:  sudo bash ir-triage.sh [directorio_salida]
set -uo pipefail

OUT="${1:-./ir-triage-$(hostname)-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"
run() { echo "### $1" >> "$OUT/$2"; shift 2; "$@" >> "$OUT/$3" 2>&1 || true; }
save() { local title="$1" file="$2"; shift 2; { echo "### $title"; "$@"; } >> "$OUT/$file" 2>&1 || true; }

echo "[*] Recolectando en: $OUT"

# --- Sistema ---
save "uname" system.txt uname -a
save "uptime" system.txt uptime
save "fecha" system.txt date
save "quien esta conectado" system.txt who -a
save "ultimos logins" system.txt last -20

# --- Procesos ---
save "procesos (ps aux)" processes.txt ps auxww
save "arbol de procesos" processes.txt pstree -ap
save "procesos por uso" processes.txt sh -c 'ps -eo pid,ppid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -30'

# --- Red ---
save "conexiones y puertos" network.txt ss -taupn
save "tabla ARP" network.txt ip neigh
save "interfaces" network.txt ip -brief addr
save "rutas" network.txt ip route
command -v iptables >/dev/null 2>&1 && save "iptables" network.txt iptables -S
command -v nft >/dev/null 2>&1 && save "nftables" network.txt nft list ruleset

# --- Persistencia / arranque ---
save "servicios systemd activos" persistence.txt systemctl list-units --type=service --state=running
save "timers systemd" persistence.txt systemctl list-timers --all
save "crontab root" persistence.txt crontab -l
for d in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
  save "contenido $d" persistence.txt ls -la "$d"
done
save "cron de usuarios" persistence.txt sh -c 'ls -la /var/spool/cron/crontabs 2>/dev/null || ls -la /var/spool/cron 2>/dev/null'
save "modulos del kernel" persistence.txt lsmod

# --- Usuarios y accesos ---
save "passwd" users.txt cat /etc/passwd
save "cuentas con UID 0" users.txt awk -F: '($3==0){print $1}' /etc/passwd
save "sudoers" users.txt sh -c 'cat /etc/sudoers; cat /etc/sudoers.d/* 2>/dev/null'
save "claves SSH autorizadas" users.txt sh -c 'for h in /root /home/*; do echo "== $h =="; cat "$h/.ssh/authorized_keys" 2>/dev/null; done'

# --- Ficheros sospechosos ---
save "ficheros modificados ultimas 24h en rutas clave" files.txt sh -c 'find /etc /usr/local /tmp /var/tmp /dev/shm -xdev -type f -mtime -1 2>/dev/null | head -200'
save "SUID/SGID" files.txt sh -c 'find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null'
save "ejecutables en /tmp /dev/shm" files.txt sh -c 'find /tmp /var/tmp /dev/shm -xdev -type f -executable 2>/dev/null'

# --- Logs relevantes (copia, no truncar el original) ---
mkdir -p "$OUT/logs"
for l in /var/log/auth.log /var/log/secure /var/log/syslog /var/log/messages; do
  [[ -f "$l" ]] && tail -n 2000 "$l" > "$OUT/logs/$(basename "$l").tail" 2>/dev/null || true
done

echo "[OK] Triaje recolectado en: $OUT"
echo "Empaqueta para analisis offline:  tar czf ${OUT}.tar.gz -C \"$(dirname "$OUT")\" \"$(basename "$OUT")\""
echo "Recuerda: preserva la cadena de custodia (hashes, copia, no trabajar sobre el original)."
