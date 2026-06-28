# backups — copias de seguridad cifradas

Scripts de backup **cifrado y verificado** con [restic](https://restic.net) o
[BorgBackup](https://www.borgbackup.org). Ambos: deduplicación, retención y comprobación
de integridad. Pensados para `cron` o un `systemd.timer`.

| Script | Herramienta |
|--------|-------------|
| `restic-backup.sh` | restic (soporta local, SFTP, S3, B2...) |
| `borg-backup.sh` | BorgBackup (local o `ssh://`) |
| `vaultwarden-backup.sh` | Backup **consistente** de Vaultwarden (para el contenedor para un checkpoint limpio del WAL de SQLite, tar del volumen y arranca; con retención) |

## Uso (restic)

```bash
echo 'una-passphrase-larga-y-aleatoria' > /root/.restic-pass && chmod 600 /root/.restic-pass
sudo RESTIC_REPOSITORY=/mnt/backup/restic \
     RESTIC_PASSWORD_FILE=/root/.restic-pass \
     BACKUP_PATHS="/etc /home /var/www" \
     bash restic-backup.sh
```

## Uso (borg)

```bash
echo 'una-passphrase-larga-y-aleatoria' > /root/.borg-pass && chmod 600 /root/.borg-pass
sudo BORG_REPO=/mnt/backup/borg BORG_PASSPHRASE_FILE=/root/.borg-pass \
     BACKUP_PATHS="/etc /home" bash borg-backup.sh
```

## Uso (Vaultwarden)

```bash
# Ajusta el contenedor/volumen/destino por variables de entorno
sudo VW_CONTAINER=vaultwarden \
     VW_VOL_DATA=/var/lib/docker/volumes/vaultwarden-data/_data \
     VW_DEST=/var/backups/vaultwarden VW_RETENTION=14 \
     bash vaultwarden-backup.sh
# Luego sincroniza VW_DEST a un destino remoto con restic/borg/rsync.
```

## Seguridad

- **Cifrado en origen**: los datos se cifran antes de salir del host; el destino nunca ve texto claro.
- La **passphrase nunca se incrusta**: se lee de un fichero `600` o variable de entorno.
- **Regla 3-2-1**: 3 copias, 2 medios, 1 fuera de sitio. Manda una copia a destino remoto (SFTP/S3/B2).
- **Verifica restauraciones** periódicamente: un backup no probado no es un backup.
- Guarda la passphrase en un gestor seguro; **sin ella, los datos cifrados no se recuperan**.
