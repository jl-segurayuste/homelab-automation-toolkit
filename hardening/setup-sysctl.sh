#!/bin/bash
# Ajusta limites del kernel utiles para servidores con muchos servicios/contenedores.
# Ejecutar con: sudo bash setup-sysctl.sh
set -e

cat > /etc/sysctl.d/99-custom.conf << 'EOF'
# inotify - necesario para agentes que vigilan muchos logs/ficheros (Promtail, etc.)
fs.inotify.max_user_instances = 512
fs.inotify.max_user_watches = 524288
# Red - mejor rendimiento con muchas conexiones concurrentes
net.core.somaxconn = 1024
# Memoria virtual - requerido por Elasticsearch/OpenSearch y similares
vm.max_map_count = 262144
EOF

sysctl --system
echo "[OK] Limites del kernel aplicados"
sysctl fs.inotify.max_user_instances vm.max_map_count
