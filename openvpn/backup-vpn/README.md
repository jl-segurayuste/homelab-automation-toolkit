# OpenVPN Backup Script

Script automatizado para realizar copias de seguridad de la configuración completa de OpenVPN, incluyendo certificados PKI, reglas de firewall y configuraciones de seguridad.

## Descripción

Este script crea backups comprimidos de todos los componentes críticos del servidor OpenVPN, incluyendo la infraestructura PKI (certificados y claves), configuraciones del servidor, reglas de firewall (iptables/ufw) y configuración de fail2ban. Incluye retención automática de 30 días.

## Características

- 📦 **Backup completo**: PKI, configuración, firewall y seguridad
- 🗜️ **Compresión eficiente**: Archivos .tar.gz para ahorrar espacio
- 🔄 **Retención automática**: Elimina backups de más de 30 días
- 📅 **Timestamp único**: Cada backup tiene fecha/hora en el nombre
- 🛡️ **Incluye seguridad**: fail2ban y reglas de firewall
- ⚡ **Ejecución rápida**: Mínimo impacto en el servidor
- 📊 **Listado automático**: Muestra todos los backups existentes

## Requisitos

### Sistema Operativo
- Linux (cualquier distribución)
- Bash 4.0+

### Dependencias

```bash
tar              # Empaquetado y compresión (GNU tar)
gzip             # Compresión (generalmente incluido con tar)
date             # Generación de timestamps (coreutils)
find             # Limpieza de backups antiguos (findutils)
mkdir            # Creación de directorios (coreutils)
```

Todas estas herramientas están preinstaladas en Debian/Ubuntu.

### Espacio en Disco

```bash
# Verificar tamaño de archivos a respaldar
du -sh /etc/openvpn/ /etc/iptables/ /etc/ufw/ /etc/fail2ban/ 2>/dev/null | awk '{sum+=$1} END {print sum}'

# Típicamente: 5-50 MB sin comprimir, 1-10 MB comprimido
# Para 30 días de retención: ~300 MB - 1 GB
```

## Instalación

```bash
# Descargar el script
wget https://raw.githubusercontent.com/tu-repo/backup-vpn.sh

# Dar permisos de ejecución
chmod +x backup-vpn.sh

# Mover a directorio en PATH (opcional)
sudo mv backup-vpn.sh /usr/local/bin/

# Crear directorio de backups
sudo mkdir -p /backup/vpn
```

## Configuración

### Variables Configurables

Edita el script para personalizar según tus necesidades:

```bash
# Directorio de destino de backups
BACKUP_DIR="/backup/vpn"

# Retención en días (por defecto 30)
RETENTION_DAYS=30

# Nombre del archivo (incluye timestamp automático)
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="vpn_backup_$DATE.tar.gz"
```

### Ubicaciones Alternativas

```bash
# Backup a disco externo montado
BACKUP_DIR="/mnt/backup/vpn"

# Backup a NFS/CIFS
BACKUP_DIR="/mnt/nas/backups/vpn"

# Backup a directorio de usuario
BACKUP_DIR="/home/backup/vpn"

# Múltiples destinos
BACKUP_DIRS=("/backup/vpn" "/mnt/nas/vpn" "/mnt/usb/vpn")
```

## Uso

### Ejecución Manual

```bash
# Ejecutar backup
sudo /usr/local/bin/backup-vpn.sh
```

**Salida esperada:**
```
Iniciando backup de configuración VPN...
Backup completado: /backup/vpn/vpn_backup_20241208_143015.tar.gz
total 2.3M
-rw-r--r-- 1 root root 1.2M Dec  1 10:30 vpn_backup_20241201_103045.tar.gz
-rw-r--r-- 1 root root 1.1M Dec  5 02:15 vpn_backup_20241205_021530.tar.gz
-rw-r--r-- 1 root root 1.2M Dec  8 14:30 vpn_backup_20241208_143015.tar.gz
```

### Verificar Contenido del Backup

```bash
# Listar archivos en el backup
tar -tzf /backup/vpn/vpn_backup_20241208_143015.tar.gz

# Ver solo directorios principales
tar -tzf /backup/vpn/vpn_backup_20241208_143015.tar.gz | cut -d/ -f1-3 | sort -u

# Buscar archivo específico
tar -tzf /backup/vpn/vpn_backup_20241208_143015.tar.gz | grep "server.conf"
```

### Extraer Backup Completo

```bash
# Crear directorio temporal
mkdir -p /tmp/vpn-restore

# Extraer backup
cd /tmp/vpn-restore
sudo tar -xzf /backup/vpn/vpn_backup_20241208_143015.tar.gz

# Ver estructura
ls -R /tmp/vpn-restore/
```

### Extraer Archivos Específicos

```bash
# Solo configuración de OpenVPN
tar -xzf /backup/vpn/vpn_backup_20241208_143015.tar.gz etc/openvpn/

# Solo certificados PKI
tar -xzf /backup/vpn/vpn_backup_20241208_143015.tar.gz etc/openvpn/easy-rsa/pki/

# Archivo específico
tar -xzf /backup/vpn/vpn_backup_20241208_143015.tar.gz etc/openvpn/server.conf
```

## Automatización

### Backup Diario con Cron

```bash
# Editar crontab de root
sudo crontab -e

# Backup diario a las 2:00 AM
0 2 * * * /usr/local/bin/backup-vpn.sh

# Backup diario a las 3:00 AM con log
0 3 * * * /usr/local/bin/backup-vpn.sh >> /var/log/vpn-backup.log 2>&1
```

### Diferentes Frecuencias

```bash
# Cada 12 horas
0 */12 * * * /usr/local/bin/backup-vpn.sh

# Cada 6 horas
0 */6 * * * /usr/local/bin/backup-vpn.sh

# Solo días laborables a las 2 AM
0 2 * * 1-5 /usr/local/bin/backup-vpn.sh

# Dos veces por semana (Lunes y Jueves)
0 2 * * 1,4 /usr/local/bin/backup-vpn.sh

# Primer día de cada mes
0 2 1 * * /usr/local/bin/backup-vpn.sh
```

### Servicio systemd

```bash
# Crear servicio
sudo nano /etc/systemd/system/vpn-backup.service
```

```ini
[Unit]
Description=OpenVPN Configuration Backup
After=openvpn@server.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-vpn.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=vpn-backup
```

```bash
# Crear timer
sudo nano /etc/systemd/system/vpn-backup.timer
```

```ini
[Unit]
Description=Daily OpenVPN Backup
Requires=vpn-backup.service

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true
AccuracySec=1h

[Install]
WantedBy=timers.target
```

```bash
# Activar
sudo systemctl daemon-reload
sudo systemctl enable vpn-backup.timer
sudo systemctl start vpn-backup.timer

# Verificar
sudo systemctl list-timers | grep vpn-backup
sudo systemctl status vpn-backup.timer
```

## Contenido del Backup

### Estructura de Directorios

El script respalda los siguientes directorios:

```
/etc/openvpn/
├── server.conf              # Configuración del servidor
├── client-template.txt      # Template para clientes
├── ca.crt                   # Certificado CA
├── server.crt/key          # Certificados del servidor
├── crl.pem                  # Lista de revocación
├── tls-crypt.key           # Clave TLS
├── dh.pem                   # Parámetros Diffie-Hellman (si existe)
├── ipp.txt                  # IPs persistentes de clientes
├── ccd/                     # Client config directory
└── easy-rsa/                # ⭐ PKI completa
    ├── vars                 # Variables de configuración
    ├── SERVER_CN_GENERATED
    ├── SERVER_NAME_GENERATED
    └── pki/
        ├── ca.crt           # CA
        ├── issued/          # ⭐ Certificados de clientes
        ├── private/         # ⭐ Claves privadas (CRÍTICO)
        ├── reqs/            # Solicitudes de certificados
        ├── index.txt        # Base de datos de certificados
        └── serial           # Número de serie

/etc/iptables/
├── add-openvpn-rules.sh    # Script de reglas
└── rm-openvpn-rules.sh     # Script de limpieza

/etc/ufw/                    # Si se usa UFW
├── ufw.conf
├── user.rules
└── ...

/etc/fail2ban/               # Si se usa fail2ban
├── fail2ban.conf
├── jail.conf
└── ...
```

### Archivos Críticos Incluidos

| Componente | Criticidad | Descripción |
|------------|-----------|-------------|
| `pki/private/` | 🔴 **CRÍTICO** | Claves privadas - necesarias para restaurar |
| `pki/issued/` | 🔴 **CRÍTICO** | Certificados de todos los clientes |
| `ca.crt` | 🔴 **CRÍTICO** | Certificado de la CA |
| `server.conf` | 🟠 **IMPORTANTE** | Configuración del servidor |
| `tls-crypt.key` | 🟠 **IMPORTANTE** | Clave TLS compartida |
| `ipp.txt` | 🟡 **ÚTIL** | IPs asignadas a clientes |
| `ccd/` | 🟡 **ÚTIL** | Configuraciones específicas por cliente |
| Reglas firewall | 🟡 **ÚTIL** | Scripts de iptables |

## Restauración

### Restauración Completa

```bash
# 1. Detener servicio OpenVPN
sudo systemctl stop openvpn@server

# 2. Hacer backup del estado actual (por si acaso)
sudo mv /etc/openvpn /etc/openvpn.old
sudo mv /etc/iptables /etc/iptables.old

# 3. Extraer backup
cd /
sudo tar -xzf /backup/vpn/vpn_backup_20241208_143015.tar.gz

# 4. Verificar permisos
sudo chmod 600 /etc/openvpn/easy-rsa/pki/private/*
sudo chmod 644 /etc/openvpn/*.crt
sudo chmod 600 /etc/openvpn/*.key

# 5. Reiniciar servicio
sudo systemctl start openvpn@server
sudo systemctl status openvpn@server

# 6. Verificar logs
sudo journalctl -u openvpn@server -n 50
```

### Restauración Selectiva

#### Restaurar Solo un Certificado de Cliente

```bash
# Extraer certificado específico
tar -xzf /backup/vpn/vpn_backup_20241208_143015.tar.gz \
    etc/openvpn/easy-rsa/pki/issued/cliente1.crt \
    etc/openvpn/easy-rsa/pki/private/cliente1.key

# Copiar a ubicación correcta
sudo cp etc/openvpn/easy-rsa/pki/issued/cliente1.crt \
    /etc/openvpn/easy-rsa/pki/issued/
sudo cp etc/openvpn/easy-rsa/pki/private/cliente1.key \
    /etc/openvpn/easy-rsa/pki/private/

# Limpiar archivos temporales
rm -rf etc/
```

#### Restaurar Solo Configuración del Servidor

```bash
# Extraer server.conf
tar -xzf /backup/vpn/vpn_backup_20241208_143015.tar.gz \
    etc/openvpn/server.conf

# Comparar con actual
diff etc/openvpn/server.conf /etc/openvpn/server.conf

# Restaurar si es necesario
sudo cp etc/openvpn/server.conf /etc/openvpn/
sudo systemctl restart openvpn@server
```

#### Restaurar Reglas de Firewall

```bash
# Extraer scripts de iptables
tar -xzf /backup/vpn/vpn_backup_20241208_143015.tar.gz \
    etc/iptables/

# Copiar
sudo cp -r etc/iptables/* /etc/iptables/

# Aplicar reglas
sudo /etc/iptables/add-openvpn-rules.sh
```

### Migración a Nuevo Servidor

```bash
# En servidor antiguo:
sudo /usr/local/bin/backup-vpn.sh
scp /backup/vpn/vpn_backup_20241208_143015.tar.gz user@nuevo-servidor:/tmp/

# En servidor nuevo:
# 1. Instalar OpenVPN (sin configurar)
wget https://raw.githubusercontent.com/tu-repo/openvpn-install.sh
chmod +x openvpn-install.sh
# NO ejecutar el instalador, solo instalar paquetes necesarios:
sudo apt update
sudo apt install -y openvpn iptables

# 2. Restaurar backup
cd /
sudo tar -xzf /tmp/vpn_backup_20241208_143015.tar.gz

# 3. Ajustar permisos
sudo chmod -R 755 /etc/openvpn/easy-rsa/
sudo chmod 600 /etc/openvpn/easy-rsa/pki/private/*
sudo chmod +x /etc/iptables/*.sh

# 4. Verificar y ajustar IP/interfaz en server.conf si es diferente
sudo nano /etc/openvpn/server.conf

# 5. Iniciar servicio
sudo systemctl enable openvpn@server
sudo systemctl start openvpn@server

# 6. Aplicar reglas de firewall
sudo /etc/iptables/add-openvpn-rules.sh

# 7. Verificar
sudo systemctl status openvpn@server
sudo /usr/local/bin/openvpn-diagnostics.sh
```

## Mejoras y Personalizaciones

### Script Mejorado con Múltiples Destinos

```bash
#!/bin/bash
# backup-vpn-enhanced.sh

# ============= CONFIGURACIÓN =============
BACKUP_DIRS=(
    "/backup/vpn"           # Local
    "/mnt/nas/vpn-backup"   # NAS
    "/mnt/usb/vpn-backup"   # USB externo
)
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="vpn_backup_$DATE.tar.gz"
LOG_FILE="/var/log/vpn-backup.log"
ALERT_EMAIL="admin@ejemplo.com"
# =========================================

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Crear backup temporal
TEMP_BACKUP="/tmp/$BACKUP_FILE"

log "Iniciando backup de configuración VPN..."

# Crear backup
if tar -czf "$TEMP_BACKUP" \
    /etc/openvpn/ \
    /etc/iptables/ \
    /etc/ufw/ \
    /etc/fail2ban/ \
    2>/dev/null; then
    
    BACKUP_SIZE=$(du -h "$TEMP_BACKUP" | cut -f1)
    log "Backup creado exitosamente: $BACKUP_SIZE"
    
    # Copiar a todos los destinos
    for BACKUP_DIR in "${BACKUP_DIRS[@]}"; do
        if [[ -d "$BACKUP_DIR" ]] || mkdir -p "$BACKUP_DIR" 2>/dev/null; then
            if cp "$TEMP_BACKUP" "$BACKUP_DIR/$BACKUP_FILE"; then
                log "✓ Copiado a: $BACKUP_DIR/$BACKUP_FILE"
                
                # Limpiar backups antiguos en este destino
                find "$BACKUP_DIR" -name "vpn_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete
                deleted=$(find "$BACKUP_DIR" -name "vpn_backup_*.tar.gz" -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
                [[ $deleted -gt 0 ]] && log "  Eliminados $deleted backup(s) antiguos"
            else
                log "✗ Error copiando a: $BACKUP_DIR"
            fi
        else
            log "✗ Destino no disponible: $BACKUP_DIR"
        fi
    done
    
    # Limpiar temporal
    rm -f "$TEMP_BACKUP"
    
    # Listar backups en destino principal
    if [[ -d "${BACKUP_DIRS[0]}" ]]; then
        log "Backups en ${BACKUP_DIRS[0]}:"
        ls -lh "${BACKUP_DIRS[0]}/" | grep "vpn_backup_" | tee -a "$LOG_FILE"
    fi
    
else
    log "ERROR: Falló la creación del backup"
    echo "Backup failed on $(hostname) at $(date)" | \
        mail -s "❌ VPN Backup Failed" "$ALERT_EMAIL"
    exit 1
fi

log "Backup completado"
```

### Backup con Cifrado

```bash
#!/bin/bash
# backup-vpn-encrypted.sh

BACKUP_DIR="/backup/vpn"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="vpn_backup_$DATE.tar.gz"
ENCRYPTED_FILE="vpn_backup_$DATE.tar.gz.gpg"
GPG_RECIPIENT="admin@ejemplo.com"  # Tu clave GPG

mkdir -p "$BACKUP_DIR"

echo "Creando backup cifrado..."

# Crear backup y cifrar en un solo paso
tar -czf - \
    /etc/openvpn/ \
    /etc/iptables/ \
    /etc/ufw/ \
    /etc/fail2ban/ \
    2>/dev/null | \
    gpg --encrypt --recipient "$GPG_RECIPIENT" \
    --output "$BACKUP_DIR/$ENCRYPTED_FILE"

# Verificar
if [[ -f "$BACKUP_DIR/$ENCRYPTED_FILE" ]]; then
    echo "Backup cifrado creado: $BACKUP_DIR/$ENCRYPTED_FILE"
    ls -lh "$BACKUP_DIR/$ENCRYPTED_FILE"
    
    # Limpiar antiguos
    find "$BACKUP_DIR" -name "vpn_backup_*.tar.gz.gpg" -mtime +30 -delete
else
    echo "ERROR: Falló la creación del backup cifrado"
    exit 1
fi

# Para restaurar:
# gpg --decrypt /backup/vpn/vpn_backup_20241208_143015.tar.gz.gpg | tar -xzf -
```

### Backup Remoto con rsync

```bash
#!/bin/bash
# backup-vpn-remote.sh

BACKUP_DIR="/backup/vpn"
REMOTE_SERVER="backup-server.ejemplo.com"
REMOTE_USER="backup"
REMOTE_DIR="/backups/vpn-servers/$(hostname)"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="vpn_backup_$DATE.tar.gz"

# Crear backup local
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    /etc/openvpn/ \
    /etc/iptables/ \
    2>/dev/null

# Sincronizar con servidor remoto
if rsync -avz --progress \
    "$BACKUP_DIR/" \
    "$REMOTE_USER@$REMOTE_SERVER:$REMOTE_DIR/"; then
    echo "Backup sincronizado con servidor remoto"
else
    echo "ERROR: Falló la sincronización remota"
fi

# Limpiar backups locales antiguos (mantener solo 7 días local)
find "$BACKUP_DIR" -name "vpn_backup_*.tar.gz" -mtime +7 -delete

# En servidor remoto, mantener 90 días
ssh "$REMOTE_USER@$REMOTE_SERVER" \
    "find $REMOTE_DIR -name 'vpn_backup_*.tar.gz' -mtime +90 -delete"
```

### Backup a Cloud (AWS S3)

```bash
#!/bin/bash
# backup-vpn-s3.sh

# Requiere: apt install awscli
# Configurar: aws configure

BACKUP_DIR="/tmp/vpn-backup"
S3_BUCKET="s3://mi-bucket-backups/vpn/$(hostname)"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="vpn_backup_$DATE.tar.gz"
RETENTION_DAYS=90

mkdir -p "$BACKUP_DIR"

# Crear backup
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    /etc/openvpn/ \
    /etc/iptables/ \
    2>/dev/null

# Subir a S3 con cifrado
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE" \
    "$S3_BUCKET/" \
    --storage-class STANDARD_IA \
    --server-side-encryption AES256

# Limpiar temporal local
rm -f "$BACKUP_DIR/$BACKUP_FILE"

# Listar backups en S3
echo "Backups en S3:"
aws s3 ls "$S3_BUCKET/"

# Configurar lifecycle policy en S3 para eliminar automáticamente
# después de X días (hacer una vez):
# aws s3api put-bucket-lifecycle-configuration --bucket mi-bucket-backups --lifecycle-configuration file://lifecycle.json
```

**lifecycle.json:**
```json
{
  "Rules": [
    {
      "Id": "DeleteOldVPNBackups",
      "Status": "Enabled",
      "Prefix": "vpn/",
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
```

## Verificación de Integridad

### Script de Verificación

```bash
#!/bin/bash
# verify-backup.sh

BACKUP_FILE="$1"

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Uso: $0 <archivo_backup.tar.gz>"
    exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "ERROR: Archivo no encontrado: $BACKUP_FILE"
    exit 1
fi

echo "Verificando integridad de: $BACKUP_FILE"
echo ""

# Verificar que tar puede leer el archivo
if tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
    echo "✓ Archivo tar válido y legible"
else
    echo "✗ ERROR: Archivo corrupto o no es un tar válido"
    exit 1
fi

# Contar archivos
FILE_COUNT=$(tar -tzf "$BACKUP_FILE" | wc -l)
echo "✓ Contiene $FILE_COUNT archivos"

# Verificar archivos críticos
echo ""
echo "Verificando archivos críticos:"

CRITICAL_FILES=(
    "etc/openvpn/server.conf"
    "etc/openvpn/ca.crt"
    "etc/openvpn/easy-rsa/pki/ca.crt"
    "etc/openvpn/easy-rsa/pki/private/ca.key"
    "etc/openvpn/easy-rsa/pki/index.txt"
)

for file in "${CRITICAL_FILES[@]}"; do
    if tar -tzf "$BACKUP_FILE" | grep -q "^$file$"; then
        echo "  ✓ $file"
    else
        echo "  ✗ FALTA: $file"
    fi
done

echo ""
echo "Tamaño: $(du -h "$BACKUP_FILE" | cut -f1)"
echo "Fecha creación: $(stat -c %y "$BACKUP_FILE")"
```

### Automatizar Verificación

```bash
# En crontab, después del backup
0 3 * * * /usr/local/bin/backup-vpn.sh && \
          /usr/local/bin/verify-backup.sh /backup/vpn/vpn_backup_$(date +\%Y\%m\%d)_*.tar.gz
```

## Monitoreo de Backups

### Script de Monitoreo

```bash
#!/bin/bash
# check-backup-status.sh

BACKUP_DIR="/backup/vpn"
MAX_AGE_HOURS=36  # Alertar si último backup tiene más de 36 horas
ALERT_EMAIL="admin@ejemplo.com"

# Encontrar backup más reciente
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/vpn_backup_*.tar.gz 2>/dev/null | head -1)

if [[ -z "$LATEST_BACKUP" ]]; then
    echo "❌ CRÍTICO: No se encontraron backups"
    echo "No backups found in $BACKUP_DIR on $(hostname)" | \
        mail -s "🚨 CRITICAL: No VPN Backups" "$ALERT_EMAIL"
    exit 2
fi

# Calcular antigüedad
BACKUP_TIME=$(stat -c %Y "$LATEST_BACKUP")
CURRENT_TIME=$(date +%s)
AGE_HOURS=$(( (CURRENT_TIME - BACKUP_TIME) / 3600 ))

echo "Último backup: $LATEST_BACKUP"
echo "Antigüedad: $AGE_HOURS horas"

if [[ $AGE_HOURS -gt $MAX_AGE_HOURS ]]; then
    echo "⚠️ AVISO: Backup antiguo (>$MAX_AGE_HOURS horas)"
    echo "Last VPN backup is $AGE_HOURS hours old on $(hostname)" | \
        mail -s "⚠️ WARNING: Old VPN Backup" "$ALERT_EMAIL"
    exit 1
else
    echo "✓ OK: Backup reciente"
    exit 0
fi
```

### Integración con Monitoring

**Nagios/Icinga:**
```bash
# /usr/lib/nagios/plugins/check_vpn_backup
#!/bin/bash
BACKUP_DIR="/backup/vpn"
WARN_HOURS=36
CRIT_HOURS=72

LATEST=$(ls -t "$BACKUP_DIR"/vpn_backup_*.tar.gz 2>/dev/null | head -1)
[[ -z "$LATEST" ]] && echo "CRITICAL: No backups" && exit 2

AGE_HOURS=$(( ($(date +%s) - $(stat -c %Y "$LATEST")) / 3600 ))

if [[ $AGE_HOURS -gt $CRIT_HOURS ]]; then
    echo "CRITICAL: Backup is $AGE_HOURS hours old"
    exit 2
elif [[ $AGE_HOURS -gt $WARN_HOURS ]]; then
    echo "WARNING: Backup is $AGE_HOURS hours old"
    exit 1
else
    echo "OK: Backup is $AGE_HOURS hours old"
    exit 0
fi
```

## Seguridad

### Permisos Recomendados

```bash
# Directorio de backups
sudo chmod 700 /backup/vpn
sudo chown root:root /backup/vpn

# Archivos de backup
sudo chmod 600 /backup/vpn/*.tar.gz
sudo chown root:root /backup/vpn/*.tar.gz

# Script de backup
sudo chmod 700 /usr/local/bin/backup-vpn.sh
sudo chown root:root /usr/local/bin/backup-vpn.sh
```

### Cifrado en Reposo

Si los backups contienen material sensible (claves privadas), considera:

1. **Cifrar el filesystem**: LUKS en /backup
2. **Usar GPG**: Cifrar cada backup individualmente
3. **Cifrar en destino**: Si usas almacenamiento cloud

### Auditoría

```bash
# Log de accesos al directorio de backups
sudo auditctl -w /backup/vpn -p rwa -k vpn_backup_access

# Ver eventos
sudo ausearch -k vpn_backup_access
```

## Troubleshooting

### Error: No such file or directory

```bash
# Verificar que los directorios existen
ls -la /etc/openvpn /etc/iptables /etc/ufw /etc/fail2ban

# El error es normal si algún componente no está instalado
# El script usa 2>/dev/null para ignorar estos errores
```

### Backup muy grande

```bash
# Excluir logs si crecen mucho
tar -czf "$BACKUP_FILE" \
    --exclude='*.log' \
    --exclude='*.log.*' \
    /etc/openvpn/ \
    /etc/iptables/

# Ver qué archivos ocupan más espacio
tar -tzf /backup/vpn/vpn_backup_20241208_143015.tar.gz | \
    xargs -I {} sh -c 'echo $(tar -xzOf /backup/vpn/vpn_backup_20241208_143015.tar.gz {} | wc -c) {}' | \
    sort -rn | head -20
```

### Espacio insuficiente

```bash
# Reducir retención
find "$BACKUP_DIR" -name "vpn_backup_*.tar.gz" -mtime +7 -delete

# O comprimir más agresivamente (más lento pero menor tamaño)
tar -c /etc/openvpn/ | gzip -9 > "$BACKUP_FILE"
# O usar xz (compresión máxima)
tar -cJf "$BACKUP_FILE" /etc/openvpn/
```

## Licencia

GPL-3.0

## Autor

**Proyecto**: homelab-automation-toolkit  
**Última actualización**: Diciembre 2025

## Scripts Relacionados

- [openvpn-install.sh](README.md) - Instalación de OpenVPN
- [openvpn-diagnostics.sh](README-diagnostics.md) - Diagnóstico completo
- [monitor-vpn.sh](README-monitor.md) - Monitoreo continuo
- [check-vpn-certs.sh](README-cert-checker.md) - Verificación de certificados

---

**Importante**: Los backups contienen claves privadas. Protégelos adecuadamente con permisos restrictivos y considera cifrarlos.