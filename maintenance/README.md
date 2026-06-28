# maintenance — mantenimiento de servidores

Scripts de mantenimiento para servidores con contenedores/Kubernetes.

| Script | Qué hace |
|--------|----------|
| `cleanup-containerd.sh` | Libera espacio en nodos K3s: poda imágenes/contenedores/cache de containerd (para K3s durante la limpieza) |
| `db-dumps.sh` | Dumps lógicos de bases de datos PostgreSQL/MySQL que corren en Docker, con retención y notificación opcional |

## Uso

```bash
# Limpieza de containerd (ventana de mantenimiento; reinicia K3s)
sudo bash cleanup-containerd.sh

# Dumps de BD: configura PG_TARGETS / MYSQL_TARGETS dentro del script o por entorno
DEST_BASE=/ruta/backups NTFY_URL=https://ntfy.example.com/mis-backups bash db-dumps.sh
```

## Avisos

- `cleanup-containerd.sh` **detiene K3s** temporalmente: úsalo en mantenimiento.
- `db-dumps.sh` lee la contraseña de MySQL **dentro del contenedor**
  (`$MYSQL_ROOT_PASSWORD`); nunca la pongas en la línea de comandos.
- Programa los dumps con `cron` o un `systemd.timer` (p. ej. diario de madrugada).
