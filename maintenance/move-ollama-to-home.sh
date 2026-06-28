#!/bin/bash
# move-ollama-to-home.sh - mover los modelos de Ollama a otra particion (p.ej. /home).
# Los modelos LLM ocupan mucho; si /usr esta en la raiz y se llena, conviene moverlos.
# Estrategia: parar el servicio -> rsync -> symlink -> arrancar. Conserva backup.
set -euo pipefail

SRC="/usr/share/ollama"
DST="${1:-/home/ollama}"

echo "Esto movera ${SRC} a ${DST} y dejara un symlink."
read -r -p "Continuar? (s/N): " -n 1 REPLY; echo
[[ "${REPLY}" =~ ^[Ss]$ ]] || exit 0

echo "1/5 - Parando Ollama..."
sudo systemctl stop ollama 2>/dev/null || true

echo "2/5 - Creando ${DST}..."
sudo mkdir -p "${DST}"

echo "3/5 - Moviendo modelos (puede tardar)..."
sudo rsync -aP "${SRC}/" "${DST}/"

echo "4/5 - Backup del original y symlink..."
sudo mv "${SRC}" "${SRC}.backup"
sudo ln -s "${DST}" "${SRC}"

echo "5/5 - Reiniciando Ollama..."
sudo systemctl start ollama

echo
echo "[OK] Ollama movido a ${DST}"
df -h / | grep -E "Filesystem|/dev"
echo "Si funciona (espera 1 min y prueba), elimina el backup: sudo rm -rf ${SRC}.backup"
