#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_packages.sh

BACKUP_DIR="/mnt/backup_local/system/packages"
DATE=$(date +%Y%m%d)

echo "$(date): Guardando lista de paquetes..." | tee -a /mnt/backup_local/logs/backup.log

# Lista de paquetes instalados manualmente
apt-mark showmanual > "${BACKUP_DIR}/manual_packages_${DATE}.txt"

# Lista completa de paquetes
dpkg --get-selections > "${BACKUP_DIR}/all_packages_${DATE}.txt"

# Repositorios configurados
sudo cp -a /etc/apt/sources.list* "${BACKUP_DIR}/sources_${DATE}/"

# Claves APT
sudo apt-key exportall > "${BACKUP_DIR}/apt_keys_${DATE}.txt"

# Mantener solo últimas 10 versiones
cd "${BACKUP_DIR}" || exit 1
ls -t manual_packages_*.txt | tail -n +11 | xargs -r rm
ls -t all_packages_*.txt | tail -n +11 | xargs -r rm

echo "$(date): [OK] Lista de paquetes guardada" | tee -a /mnt/backup_local/logs/backup.log
