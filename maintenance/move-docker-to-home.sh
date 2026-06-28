#!/bin/bash
# move-docker-to-home.sh - mover el data-root de Docker a otra particion (p.ej. /home).
# Util cuando la raiz (/) se queda sin espacio y otra particion tiene de sobra.
# Estrategia: parar Docker -> rsync de los datos -> symlink -> arrancar. Conserva un
# backup del directorio original hasta que verifiques que todo funciona.
set -euo pipefail

SRC="/var/lib/docker"
DST="${1:-/home/docker}"

echo "Esto movera ${SRC} a ${DST} y dejara un symlink (libera espacio en /)."
read -r -p "Continuar? (s/N): " -n 1 REPLY; echo
[[ "${REPLY}" =~ ^[Ss]$ ]] || exit 0

echo "1/7 - Parando Docker..."
sudo systemctl stop docker docker.socket

echo "2/7 - Creando ${DST}..."
sudo mkdir -p "${DST}"

echo "3/7 - Copiando datos (puede tardar varios minutos)..."
sudo rsync -aP "${SRC}/" "${DST}/"

echo "4/7 - Backup del directorio original..."
sudo mv "${SRC}" "${SRC}.backup"

echo "5/7 - Creando symlink ${SRC} -> ${DST}..."
sudo ln -s "${DST}" "${SRC}"

echo "6/7 - Reiniciando Docker..."
sudo systemctl start docker

echo "7/7 - Verificando..."
docker ps

echo
echo "[OK] Docker movido a ${DST}"
df -h / | grep -E "Filesystem|/dev"
echo "Si todo funciona, elimina el backup: sudo rm -rf ${SRC}.backup"
