#!/usr/bin/env bash
# Vigila el log de autenticacion en busca de fuerza bruta SSH y eventos sensibles,
# y notifica (opcional) por ntfy o webhook. Pensado para cron (cada 5-15 min) o
# para ejecucion continua con --follow.
#
# Variables:
#   AUTH_LOG       ruta del log (def: autodetecta /var/log/auth.log o /var/log/secure)
#   THRESHOLD      nº de fallos por IP para alertar (def: 10)
#   NTFY_URL       opcional: URL ntfy para notificar
#   WEBHOOK_URL    opcional: webhook generico (POST con cuerpo de texto)
set -uo pipefail

AUTH_LOG="${AUTH_LOG:-}"
THRESHOLD="${THRESHOLD:-10}"
NTFY_URL="${NTFY_URL:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"
WINDOW="${WINDOW:-}"   # vacio = todo el log; o ruta a un estado previo (no usado en cron simple)

if [[ -z "$AUTH_LOG" ]]; then
  for f in /var/log/auth.log /var/log/secure; do [[ -f "$f" ]] && AUTH_LOG="$f" && break; done
fi
[[ -n "$AUTH_LOG" && -f "$AUTH_LOG" ]] || { echo "[ERROR] No encuentro el log de auth. Define AUTH_LOG." >&2; exit 1; }

notify() {
  local title="$1" body="$2"
  echo "[$title] $body"
  [[ -n "$NTFY_URL" ]] && curl -fsS -m 10 -H "Title: $title" -d "$body" "$NTFY_URL" >/dev/null 2>&1 || true
  [[ -n "$WEBHOOK_URL" ]] && curl -fsS -m 10 -d "$title: $body" "$WEBHOOK_URL" >/dev/null 2>&1 || true
}

echo "=== auth-monitor sobre $AUTH_LOG (umbral: $THRESHOLD fallos/IP) ==="

# IPs con muchos fallos de contrasena
grep -aE "Failed password" "$AUTH_LOG" 2>/dev/null \
  | grep -aoE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}' \
  | sort | uniq -c | sort -rn \
  | while read -r count ip; do
      if [[ "$count" -ge "$THRESHOLD" ]]; then
        notify "Posible fuerza bruta SSH" "IP $ip con $count intentos fallidos en $AUTH_LOG"
      fi
    done

# Usuarios invalidos (escaneo de cuentas)
invalid=$(grep -acE "Invalid user" "$AUTH_LOG" 2>/dev/null || echo 0)
[[ "$invalid" -gt 0 ]] && echo "[INFO] Intentos con usuario invalido: $invalid"

# Escaladas con sudo
sudo_fail=$(grep -acE "sudo:.*authentication failure|sudo:.*incorrect password" "$AUTH_LOG" 2>/dev/null || echo 0)
[[ "$sudo_fail" -gt 0 ]] && notify "Fallos de sudo" "$sudo_fail fallos de autenticacion sudo en $AUTH_LOG"

echo "Hecho."
