#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_configs.sh

BACKUP_DIR="/mnt/backup_local/system"
DATE=$(date +%Y%m%d_%H%M%S)

echo "$(date): Respaldando configuraciones críticas..." | tee -a /mnt/backup_local/logs/backup.log

# Crear directorio temporal
TEMP_DIR=$(mktemp -d)

# SSH
cp -r ~/.ssh "${TEMP_DIR}/"

# GPG
gpg --export --armor > "${TEMP_DIR}/gpg_public_keys.asc"
gpg --export-secret-keys --armor > "${TEMP_DIR}/gpg_private_keys.asc"

# Ansible (si aplica para )
if [ -d ~/ansible ]; then
    cp -r ~/ansible "${TEMP_DIR}/"
fi

# Git config
cp ~/.gitconfig "${TEMP_DIR}/" 2>/dev/null

# Bash/Zsh configs
cp ~/.bashrc ~/.bash_aliases ~/.profile "${TEMP_DIR}/" 2>/dev/null

# Vim/Neovim
cp ~/.vimrc "${TEMP_DIR}/" 2>/dev/null
[ -d ~/.config/nvim ] && cp -r ~/.config/nvim "${TEMP_DIR}/"

# OpenVPN configs 
if [ -d ~/openvpn ]; then
    cp -r ~/openvpn "${TEMP_DIR}/"
fi

# Comprimir todo
tar -czf "${BACKUP_DIR}/configs_${DATE}.tar.gz" -C "${TEMP_DIR}" .

# Cifrar backup (RECOMENDADO para claves privadas)
gpg --symmetric --cipher-algo AES256 "${BACKUP_DIR}/configs_${DATE}.tar.gz"
rm "${BACKUP_DIR}/configs_${DATE}.tar.gz"

# Limpiar
rm -rf "${TEMP_DIR}"

# Mantener últimos 15 backups
cd "${BACKUP_DIR}" || exit 1
ls -t configs_*.tar.gz.gpg | tail -n +16 | xargs -r rm

echo "$(date): [OK] Configuraciones respaldadas y cifradas" | tee -a /mnt/backup_local/logs/backup.log
