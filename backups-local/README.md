# backups-local — copias de seguridad locales por niveles

Suite de scripts para **backup local** de un host Linux sobre una partición/disco dedicado
(`/mnt/backup_local` por defecto), orquestada por un script maestro y pensada para `cron`.
Complementa la sección [`../backups`](../backups) (restic/BorgBackup cifrado): aquí el enfoque
es `rsync`/`tar` local, snapshots LVM e imágenes de VMs.

> Ajusta las rutas del inicio de cada script a tu entorno. No hay datos reales: el correo de
> alertas es un placeholder (`tu-email@ejemplo.com`) y las rutas/volúmenes son de ejemplo.

## Scripts

| Script | Función |
|--------|---------|
| `backup_master.sh` | Orquesta el resto, cuenta errores y envía un reporte por email (msmtp). Planifica: diario `/etc` + `/home` + configs; domingos paquetes + snapshot LVM; día 1 de mes VMs completas, resto incrementales |
| `backup_etc.sh` | Copia comprimida de `/etc` |
| `backup_home.sh` | Backup incremental de `/home` con `rsync --link-dest` y rotación |
| `backup_configs.sh` | Configuraciones de usuario (dotfiles, configs varias) |
| `backup_packages.sh` | Inventario de paquetes instalados y orígenes APT |
| `backup_lvm_snapshot.sh` | Snapshot LVM de la raíz (solo lectura) para copias consistentes |
| `backup_vms_full.sh` | Backup completo de VMs |
| `backup_vms_incremental.sh` | Backup incremental de VMs con rotación |
| `backup_cleanup.sh` | Retención: elimina copias antiguas según política |
| `backup_monitor.sh` | Estado del sistema de backup (tamaños, última copia, snapshots) |
| `backup_alerts.sh` | Alertas: partición llena, errores recientes, copia obsoleta |

## Uso

```bash
# 1) Revisa y ajusta variables al inicio de cada script (rutas, EMAIL, VG/LV, etc.)
# 2) Prueba un script suelto
bash backup_etc.sh

# 3) Orquesta todo
bash backup_master.sh

# 4) Programa en cron (ejemplo: a las 02:00)
# 0 2 * * *  /mnt/backup_local/scripts/backup_master.sh
```

## Requisitos

- `rsync`, `tar`, `gzip`; `msmtp` para los emails (opcional); `lvm2` para snapshots;
  herramientas de virtualización para los backups de VMs.
- Permisos `sudo` para snapshots LVM y lectura de `/etc`.

## Notas

- Los snapshots LVM asumen nombres de ejemplo (`vg_nvme/lv_root`): ponlos los de tu sistema.
- La línea de imagen `dd` en `backup_lvm_snapshot.sh` está comentada por defecto (consume tiempo).
- Pensado para tu **propio** equipo; revisa la retención antes de automatizar borrados.
