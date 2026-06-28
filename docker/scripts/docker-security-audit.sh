#!/usr/bin/env bash
# Auditoria rapida de seguridad de Docker (estilo CIS, resumido). Solo LECTURA.
# Revisa configuraciones de riesgo habituales en el daemon y en los contenedores.
#   bash docker-security-audit.sh
set -uo pipefail

RC=0
okay() { echo "[OK]   $*"; }
warn() { echo "[WARN] $*"; RC=1; }
note() { echo "[INFO] $*"; }

command -v docker >/dev/null 2>&1 || { echo "docker no instalado"; exit 2; }

echo "=== Auditoria de seguridad Docker ==="

# 1. daemon.json: opciones de hardening
DJ=/etc/docker/daemon.json
if [[ -f "$DJ" ]]; then
  grep -q '"no-new-privileges": *true' "$DJ" && okay "no-new-privileges activado" || warn "no-new-privileges no activado en daemon.json"
  grep -q '"icc": *false' "$DJ" && okay "icc=false (sin comunicacion entre contenedores por defecto)" || warn "icc no esta en false"
  grep -q '"live-restore": *true' "$DJ" && okay "live-restore activado" || note "live-restore no activado"
  grep -q '"userns-remap"' "$DJ" && okay "userns-remap configurado" || note "userns-remap no configurado (aislamiento UID opcional)"
else
  warn "No existe $DJ (sin hardening del daemon)."
fi

# 2. Contenedores privilegiados
PRIV=$(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{.Name}} {{.HostConfig.Privileged}}' 2>/dev/null | awk '$2=="true"{print $1}')
[[ -n "$PRIV" ]] && warn "Contenedores PRIVILEGIADOS: $PRIV" || okay "Sin contenedores privilegiados"

# 3. Montajes del socket de Docker (escalada a root del host)
SOCK=$(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{.Name}} {{range .Mounts}}{{.Source}} {{end}}' 2>/dev/null | awk '/docker\.sock/{print $1}')
[[ -n "$SOCK" ]] && warn "Contenedores con /var/run/docker.sock montado: $SOCK" || okay "Ningun contenedor monta el socket de Docker"

# 4. Contenedores corriendo como root (UID 0)
for c in $(docker ps -q 2>/dev/null); do
  uid=$(docker inspect --format '{{.Config.User}}' "$c" 2>/dev/null)
  name=$(docker inspect --format '{{.Name}}' "$c" 2>/dev/null)
  [[ -z "$uid" || "$uid" == "0" || "$uid" == "root" ]] && warn "Contenedor como root: $name (define USER no-root)"
done

# 5. Puertos publicados en todas las interfaces (0.0.0.0)
EXPOSED=$(docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -E '0\.0\.0\.0:' | awk '{print $1}' | sort -u)
[[ -n "$EXPOSED" ]] && warn "Puertos publicados en 0.0.0.0 (considera bind a 127.0.0.1): $EXPOSED" || okay "Sin publicaciones en 0.0.0.0"

echo
[[ "$RC" -eq 0 ]] && echo "RESULTADO: sin hallazgos criticos." || echo "RESULTADO: revisa los [WARN]."
exit $RC
