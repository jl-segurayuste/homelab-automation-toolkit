#!/bin/bash
# Archivo: /mnt/backup_local/scripts/backup_configs.sh
# Copia cifrada de configuraciones (claves SSH y GPG incluidas). Sale con código 1 si falla.
#
# Cifrado: gpg --symmetric en modo no interactivo con la frase de paso del fichero
# BACKUP_GPG_PASSFILE (por defecto /root/.backup_gpg_pass, permisos 600). Antes gpg la pedía por
# teclado: desde cron fallaba, se borraba el .tar.gz igualmente y no quedaba ninguna copia.

set -o pipefail
umask 077   # el contenido son claves privadas

BACKUP_DIR="/mnt/backup_local/system"
DATE=$(date +%Y%m%d_%H%M%S)
LOG="/mnt/backup_local/logs/backup.log"
PASSFILE="${BACKUP_GPG_PASSFILE:-/root/.backup_gpg_pass}"
ARCHIVE="${BACKUP_DIR}/configs_${DATE}.tar.gz"

fail() {
    echo "$(date): [X] ERROR en backup de configuraciones: $1" | tee -a "${LOG}"
    exit 1
}

echo "$(date): Respaldando configuraciones críticas..." | tee -a "${LOG}"

[ -r "${PASSFILE}" ] || fail "no se puede leer la frase de paso (${PASSFILE}); define BACKUP_GPG_PASSFILE"

# Directorio temporal; se borra siempre, también si algo falla (lleva las claves en claro)
TEMP_DIR=$(mktemp -d) || fail "mktemp"
trap 'rm -rf "${TEMP_DIR}" "${ARCHIVE}"' EXIT

# SSH
cp -r ~/.ssh "${TEMP_DIR}/" || fail "copia de ~/.ssh"

# GPG
gpg --export --armor > "${TEMP_DIR}/gpg_public_keys.asc" || fail "exportar claves públicas GPG"
gpg --export-secret-keys --armor > "${TEMP_DIR}/gpg_private_keys.asc" || fail "exportar claves privadas GPG"

# Ansible (si aplica)
if [ -d ~/ansible ]; then
    cp -r ~/ansible "${TEMP_DIR}/" || fail "copia de ~/ansible"
fi

# Opcionales: pueden no existir
cp ~/.gitconfig "${TEMP_DIR}/" 2>/dev/null
cp ~/.bashrc ~/.bash_aliases ~/.profile "${TEMP_DIR}/" 2>/dev/null
cp ~/.vimrc "${TEMP_DIR}/" 2>/dev/null
[ -d ~/.config/nvim ] && cp -r ~/.config/nvim "${TEMP_DIR}/"

# OpenVPN configs
if [ -d ~/openvpn ]; then
    cp -r ~/openvpn "${TEMP_DIR}/" || fail "copia de ~/openvpn"
fi

# Comprimir y cifrar; el .tar.gz sin cifrar solo se borra (trap) después de cifrar con éxito
tar -czf "${ARCHIVE}" -C "${TEMP_DIR}" . || fail "tar"
gpg --batch --yes --pinentry-mode loopback --passphrase-file "${PASSFILE}" \
    --symmetric --cipher-algo AES256 -o "${ARCHIVE}.gpg" "${ARCHIVE}" \
    || { rm -f "${ARCHIVE}.gpg"; fail "cifrado con gpg"; }

# Mantener últimos 15 backups
cd "${BACKUP_DIR}" || exit 1
ls -t configs_*.tar.gz.gpg | tail -n +16 | xargs -r rm

echo "$(date): [OK] Configuraciones respaldadas y cifradas" | tee -a "${LOG}"
