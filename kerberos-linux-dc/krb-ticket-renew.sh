#!/usr/bin/env bash
# Renovacion automatica de tickets Kerberos (TGT). Pensado para cron o systemd.timer.
# Estrategia:
#   - Si se da un KEYTAB + PRINCIPAL: re-kinit desde el keytab (ticket siempre fresco;
#     ideal para cuentas de servicio).
#   - Si no, intenta renovar el TGT existente con 'kinit -R' (debe ser renovable).
#
# Variables:
#   KEYTAB        ruta a un keytab (opcional)
#   PRINCIPAL     principal a usar con el keytab (obligatorio si hay KEYTAB)
#   KRB5CCNAME    cache de credenciales (opcional; por defecto la del entorno)
set -uo pipefail

KEYTAB="${KEYTAB:-}"
PRINCIPAL="${PRINCIPAL:-}"
export KRB5CCNAME="${KRB5CCNAME:-${KRB5CCNAME:-}}"

log() { echo "$(date '+%F %T') $*"; }

if [[ -n "$KEYTAB" ]]; then
  [[ -f "$KEYTAB" ]] || { log "[ERROR] No existe el keytab: $KEYTAB"; exit 1; }
  [[ -n "$PRINCIPAL" ]] || { log "[ERROR] Define PRINCIPAL al usar KEYTAB"; exit 1; }
  if kinit -k -t "$KEYTAB" "$PRINCIPAL"; then
    log "[OK] Ticket obtenido desde keytab para $PRINCIPAL"
  else
    log "[ERROR] Fallo kinit desde keytab para $PRINCIPAL"; exit 1
  fi
else
  # Sin keytab: renovar el TGT actual si es renovable; si no, error claro.
  if ! klist -s 2>/dev/null; then
    log "[ERROR] No hay TGT valido en cache y no se dio keytab. Ejecuta kinit primero."
    exit 1
  fi
  if kinit -R 2>/dev/null; then
    log "[OK] TGT renovado (kinit -R)"
  else
    log "[WARN] No se pudo renovar (ticket no renovable o caducado). Re-autentica con kinit/keytab."
    exit 1
  fi
fi

klist 2>/dev/null | sed 's/^/    /' || true
