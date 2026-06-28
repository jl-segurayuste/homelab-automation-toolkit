#!/bin/bash
# verify-ai-stack.sh - verificacion rapida de un stack de IA local (Ollama + Open WebUI).
# Comprueba el servicio Ollama, su API, los modelos, el contenedor de Open WebUI,
# la conectividad entre ambos, el firewall y los recursos del host. Solo lectura.
set -uo pipefail

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
WEBUI_URL="${WEBUI_URL:-http://localhost:3000}"
WEBUI_CONTAINER="${WEBUI_CONTAINER:-open-webui}"

echo "=== Verificacion del stack de IA ==="

echo
echo "1. Ollama:"
systemctl is-active --quiet ollama && echo "  [OK] servicio activo" || echo "  [X] servicio inactivo"
curl -sf "${OLLAMA_URL}/api/tags" >/dev/null && echo "  [OK] API accesible" || echo "  [X] API no accesible"

echo
echo "2. Modelos instalados:"
command -v ollama >/dev/null 2>&1 && ollama list | tail -n +2 | awk '{print "  - "$1}' || echo "  (ollama CLI no disponible)"

echo
echo "3. Open WebUI:"
docker ps --format '{{.Names}}' 2>/dev/null | grep -q "${WEBUI_CONTAINER}" && echo "  [OK] contenedor activo" || echo "  [X] contenedor inactivo"
curl -sf "${WEBUI_URL}" >/dev/null && echo "  [OK] web accesible" || echo "  [X] web no accesible"

echo
echo "4. Conectividad WebUI -> Ollama (gateway docker0):"
docker exec "${WEBUI_CONTAINER}" curl -sf "http://172.17.0.1:11434/api/tags" >/dev/null 2>&1 \
    && echo "  [OK] conectado" || echo "  [X] sin conexion"

echo
echo "5. Firewall:"
sudo ufw status 2>/dev/null | grep -q "Status: active" && echo "  [OK] UFW activo" || echo "  [i] UFW inactivo"

echo
echo "6. Recursos:"
echo "  RAM libre:   $(free -h | awk '/^Mem:/ {print $7}')"
echo "  Disco libre: $(df -h / | awk 'NR==2 {print $4}')"
