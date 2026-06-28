#!/bin/bash
# disk-cleanup.sh - liberar espacio en disco de forma segura en Debian/Ubuntu.
# Combina limpieza de Docker, journald, logs, APT, snap y kernels antiguos.
# Por defecto NO toca Docker; pasa --docker para incluir la limpieza de Docker.
#
#   ./disk-cleanup.sh            # limpieza estandar del sistema
#   ./disk-cleanup.sh --docker   # ademas: docker system prune (borra datos no usados)
set -uo pipefail

DO_DOCKER=0
[ "${1:-}" = "--docker" ] && DO_DOCKER=1

line() { printf '%s\n' "============================================"; }

echo "Espacio actual:"
df -h / | grep -v tmpfs

if [ "${DO_DOCKER}" -eq 1 ] && command -v docker >/dev/null 2>&1; then
    echo "-> Limpiando Docker (contenedores/imagenes/redes/volumenes no usados)..."
    docker system prune -a -f --volumes || true
fi

echo "-> Vaciando journald (conservar 3 dias / 100M)..."
sudo journalctl --vacuum-time=3d || true
sudo journalctl --vacuum-size=100M || true

echo "-> Borrando logs rotados antiguos..."
sudo find /var/log -type f \( -name "*.gz" -o -name "*.old" -o -name "*.[0-9]" \) -delete 2>/dev/null || true
sudo find /var/log -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true

echo "-> Truncando logs grandes (>100M)..."
sudo find /var/log -type f -size +100M -exec truncate -s 0 {} \; 2>/dev/null || true

echo "-> Limpiando cache de APT..."
sudo apt-get clean
sudo apt-get autoremove -y --purge

echo "-> Eliminando revisiones de snap deshabilitadas..."
if command -v snap >/dev/null 2>&1; then
    sudo snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r name rev; do
        sudo snap remove "$name" --revision="$rev" 2>/dev/null || true
    done
fi

echo "-> Limpiando temporales y miniaturas..."
sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
rm -rf "${HOME}/.cache/thumbnails/"* 2>/dev/null || true

echo "-> Purgando kernels antiguos (conserva el actual)..."
CURRENT_KERNEL="$(uname -r | sed 's/-generic//')"
dpkg -l 2>/dev/null | grep -E 'linux-image-[0-9]' | grep -v "${CURRENT_KERNEL}" \
    | awk '{print $2}' | head -n -1 | xargs -r sudo apt-get purge -y 2>/dev/null || true

line
echo "Espacio tras la limpieza:"
df -h / | grep -v tmpfs
line
echo "Top directorios por tamano en /var:"
sudo du -h --max-depth=1 /var 2>/dev/null | sort -hr | head -10
