# OpenVPN Continuous Monitoring Script

Script de monitoreo continuo para servidores OpenVPN que verifica el estado del servicio, recursos del sistema, conectividad y envía alertas automáticas por email ante problemas detectados.

## Descripción

Este script realiza verificaciones periódicas del servidor OpenVPN, monitorizando el estado del servicio, interfaces de red, puertos, clientes conectados y recursos del sistema (CPU, memoria, disco). Incluye capacidad de auto-recuperación y notificaciones por email.

## Características

- 🔄 **Auto-recuperación**: Reinicia automáticamente el servicio si cae
- 📧 **Alertas por email**: Notificaciones inmediatas de problemas
- 📊 **Monitoreo de recursos**: CPU, memoria y disco
- 👥 **Conteo de clientes**: Seguimiento de conexiones activas
- 🔌 **Verificación de red**: Interfaces y puertos
- 📝 **Logging completo**: Registro detallado con timestamps
- ⚡ **Ejecución ligera**: Mínimo impacto en recursos

## Requisitos

### Sistema Operativo
- Linux con systemd
- Debian/Ubuntu (compatible con otras distribuciones)

### Dependencias

```bash
systemctl    # Gestión de servicios (systemd)
ip           # Información de interfaces (iproute2)
ss           # Sockets y puertos (iproute2)
mail/mailx   # Envío de emails
top          # Uso de CPU
free         # Uso de memoria
df           # Uso de disco
bc           # Calculadora para comparaciones decimales
grep, awk    # Utilidades de texto (coreutils)
```

### Instalación de Dependencias

```bash
# Debian/Ubuntu - mailutils para envío de emails
sudo apt update
sudo apt install -y mailutils bc

# Configurar servidor SMTP (opcional - usar relay externo)
sudo apt install -y postfix
# O configurar con servicio externo como SendGrid, AWS SES, etc.
```

## Instalación

### Descarga e Instalación

```bash
# Descargar el script
wget https://raw.githubusercontent.com/tu-repo/monitor-vpn.sh

# Dar permisos de ejecución
chmod +x monitor-vpn.sh

# Mover a directorio en PATH
sudo mv monitor-vpn.sh /usr/local/bin/

# Crear directorio de logs
sudo mkdir -p /var/log
sudo touch /var/log/vpn-monitor.log
```

### Configuración Inicial

```bash
# Editar el script para configurar tu email
sudo nano /usr/local/bin/monitor-vpn.sh

# Modificar esta línea con tu email real:
ALERT_EMAIL="tu_email@ejemplo.com"
```

## Configuración

### Variables Configurables

Edita el script para ajustar estas variables según tus necesidades:

```bash
# Archivo de log
LOG_FILE="/var/log/vpn-monitor.log"

# Email para alertas
ALERT_EMAIL="admin@tudominio.com"

# Puerto OpenVPN (si usas uno diferente a 1194)
# Modifica la línea:
if ! ss -ulpn | grep -q ":1194"; then

# Umbrales de recursos (%)
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=80
```

### Configuración Avanzada

```bash
#!/bin/bash
# monitor-vpn.sh - Versión mejorada con configuración

# ============= CONFIGURACIÓN =============
LOG_FILE="/var/log/vpn-monitor.log"
ALERT_EMAIL="admin@ejemplo.com"
VPN_PORT="1194"
VPN_PROTOCOL="udp"  # udp o tcp

# Umbrales de alerta (%)
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=80

# Configuración de servicio
SERVICE_NAME="openvpn@server"
TUN_INTERFACE="tun0"

# Configuración de email
EMAIL_SUBJECT_PREFIX="[ALERTA VPN]"
EMAIL_FROM="monitoring@servidor.com"
# =========================================

# ... resto del script
```

## Uso

### Ejecución Manual

```bash
# Ejecutar una vez
sudo /usr/local/bin/monitor-vpn.sh

# Ver log en tiempo real
sudo tail -f /var/log/vpn-monitor.log
```

**Salida de ejemplo:**
```
[2024-12-08 14:30:15] OK: OpenVPN está corriendo
[2024-12-08 14:30:15] Clientes conectados: 3
[2024-12-08 14:30:15] AVISO: Uso de CPU alto: 85.2%
```

### Automatización con Cron

#### Monitoreo cada 5 minutos

```bash
# Editar crontab
sudo crontab -e

# Añadir línea
*/5 * * * * /usr/local/bin/monitor-vpn.sh
```

#### Monitoreo cada minuto (producción crítica)

```bash
# En crontab
* * * * * /usr/local/bin/monitor-vpn.sh
```

#### Monitoreo con diferentes frecuencias

```bash
# Cada 2 minutos
*/2 * * * * /usr/local/bin/monitor-vpn.sh

# Cada 10 minutos
*/10 * * * * /usr/local/bin/monitor-vpn.sh

# Solo en horas laborales (9-18h, lunes a viernes)
*/5 9-18 * * 1-5 /usr/local/bin/monitor-vpn.sh

# Cada hora fuera de horario laboral
0 0-8,19-23 * * * /usr/local/bin/monitor-vpn.sh
```

### Servicio systemd (Alternativa Avanzada)

Para monitoreo continuo sin cron:

```bash
# Crear archivo de servicio
sudo nano /etc/systemd/system/vpn-monitor.service
```

```ini
[Unit]
Description=OpenVPN Monitoring Service
After=openvpn@server.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/monitor-vpn.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=vpn-monitor

[Install]
WantedBy=multi-user.target
```

```bash
# Crear timer
sudo nano /etc/systemd/system/vpn-monitor.timer
```

```ini
[Unit]
Description=OpenVPN Monitor Timer
Requires=vpn-monitor.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
AccuracySec=1s

[Install]
WantedBy=timers.target
```

```bash
# Habilitar y arrancar
sudo systemctl daemon-reload
sudo systemctl enable vpn-monitor.timer
sudo systemctl start vpn-monitor.timer

# Verificar estado
sudo systemctl status vpn-monitor.timer
sudo systemctl list-timers | grep vpn-monitor
```

## Verificaciones Realizadas

### 1. Estado del Servicio OpenVPN

```bash
if ! systemctl is-active --quiet openvpn@server; then
    # ALERTA + auto-recuperación
fi
```

**Acciones:**
- ✅ Detecta si el servicio está caído
- 🔄 Intenta reiniciar automáticamente
- 📧 Envía alerta por email
- 📝 Registra en log

### 2. Interfaz TUN

```bash
if ! ip link show tun0 &>/dev/null; then
    # ALERTA
fi
```

**Verifica:**
- Existencia de interfaz `tun0`
- Indica problemas de inicialización del túnel

### 3. Puerto de Escucha

```bash
if ! ss -ulpn | grep -q ":1194"; then
    # ALERTA
fi
```

**Verifica:**
- OpenVPN escuchando en puerto configurado
- Detecta problemas de binding o firewall

### 4. Clientes Conectados

```bash
CLIENTS=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log)
```

**Monitorea:**
- Número de clientes activos
- Útil para detectar anomalías (muchos o muy pocos)

### 5. Uso de CPU

```bash
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    # AVISO
fi
```

**Umbral:** 80% por defecto

### 6. Uso de Memoria

```bash
MEM_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
if (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
    # AVISO
fi
```

**Umbral:** 80% por defecto

### 7. Espacio en Disco

```bash
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [[ $DISK_USAGE -gt 80 ]]; then
    # AVISO
fi
```

**Umbral:** 80% por defecto

## Configuración de Email

### Opción 1: SMTP Local (Postfix)

```bash
# Instalar Postfix
sudo apt install -y postfix mailutils

# Configurar como "Internet Site"
sudo dpkg-reconfigure postfix

# Probar envío
echo "Test" | mail -s "Test Subject" tu_email@ejemplo.com
```

### Opción 2: Relay SMTP Externo (Gmail)

```bash
# Instalar dependencias
sudo apt install -y postfix mailutils libsasl2-modules

# Configurar Postfix
sudo nano /etc/postfix/main.cf
```

Añadir al final:
```
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_security_level = encrypt
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

Crear archivo de credenciales:
```bash
sudo nano /etc/postfix/sasl_passwd
```

```
[smtp.gmail.com]:587 tu_email@gmail.com:tu_app_password
```

```bash
# Generar hash y proteger
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo systemctl restart postfix

# Probar
echo "Test desde VPN server" | mail -s "Test VPN Monitor" destino@ejemplo.com
```

### Opción 3: SendGrid API

```bash
# Instalar curl
sudo apt install -y curl

# Modificar script para usar API en lugar de mail
send_alert() {
    local subject="$1"
    local message="$2"
    
    curl --request POST \
      --url https://api.sendgrid.com/v3/mail/send \
      --header "Authorization: Bearer $SENDGRID_API_KEY" \
      --header 'Content-Type: application/json' \
      --data "{
        \"personalizations\": [{\"to\": [{\"email\": \"$ALERT_EMAIL\"}]}],
        \"from\": {\"email\": \"vpn-monitor@tudominio.com\"},
        \"subject\": \"$subject\",
        \"content\": [{\"type\": \"text/plain\", \"value\": \"$message\"}]
      }"
}
```

### Opción 4: Webhook/Slack

```bash
# Enviar a Slack en lugar de email
send_slack_alert() {
    local message="$1"
    local webhook_url="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"🚨 VPN Alert: $message\"}" \
      "$webhook_url"
}
```

## Logs y Análisis

### Estructura del Log

```
[2024-12-08 09:00:01] OK: OpenVPN está corriendo
[2024-12-08 09:00:01] Clientes conectados: 2
[2024-12-08 09:05:01] OK: OpenVPN está corriendo
[2024-12-08 09:05:01] Clientes conectados: 3
[2024-12-08 09:10:01] ALERTA: OpenVPN NO está corriendo
[2024-12-08 09:10:06] OpenVPN reiniciado exitosamente
[2024-12-08 09:10:06] Clientes conectados: 0
[2024-12-08 09:15:01] OK: OpenVPN está corriendo
[2024-12-08 09:15:01] Clientes conectados: 2
[2024-12-08 09:15:01] AVISO: Uso de CPU alto: 85.3%
```

### Análisis de Logs

```bash
# Ver últimas 50 líneas
sudo tail -50 /var/log/vpn-monitor.log

# Buscar alertas
sudo grep "ALERTA" /var/log/vpn-monitor.log

# Buscar avisos
sudo grep "AVISO" /var/log/vpn-monitor.log

# Contar reinicios de servicio
sudo grep -c "OpenVPN reiniciado" /var/log/vpn-monitor.log

# Ver estadísticas de clientes
sudo grep "Clientes conectados" /var/log/vpn-monitor.log | tail -20

# Alertas de hoy
sudo grep "$(date +%Y-%m-%d)" /var/log/vpn-monitor.log | grep -E "ALERTA|AVISO"

# Resumen diario
sudo grep "$(date +%Y-%m-%d)" /var/log/vpn-monitor.log | \
  awk '{print $2}' | sort | uniq -c
```

### Rotación de Logs

```bash
# Crear configuración de logrotate
sudo nano /etc/logrotate.d/vpn-monitor
```

```
/var/log/vpn-monitor.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        # Opcional: enviar resumen semanal
        /usr/local/bin/send-weekly-report.sh
    endscript
}
```

```bash
# Probar configuración
sudo logrotate -f /etc/logrotate.d/vpn-monitor
```

## Mejoras y Personalizaciones

### Script Mejorado con Todas las Funciones

```bash
#!/bin/bash
# monitor-vpn.sh - Versión completa mejorada

# ============= CONFIGURACIÓN =============
LOG_FILE="/var/log/vpn-monitor.log"
ALERT_EMAIL="admin@ejemplo.com"
VPN_PORT="1194"
SERVICE_NAME="openvpn@server"
TUN_INTERFACE="tun0"

# Umbrales
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=80
MIN_CLIENTS=0      # Alertar si hay menos de N clientes
MAX_CLIENTS=100    # Alertar si hay más de N clientes

# Control de alertas (evitar spam)
ALERT_COOLDOWN=3600  # Segundos entre alertas del mismo tipo
ALERT_STATE_FILE="/var/run/vpn-monitor-alerts"
# =========================================

# Función de logging mejorada
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Función de alerta con cooldown
send_alert() {
    local alert_type="$1"
    local subject="$2"
    local message="$3"
    
    # Verificar cooldown
    if [[ -f "$ALERT_STATE_FILE" ]]; then
        local last_alert=$(grep "^$alert_type:" "$ALERT_STATE_FILE" | cut -d: -f2)
        if [[ -n "$last_alert" ]]; then
            local now=$(date +%s)
            local elapsed=$((now - last_alert))
            if [[ $elapsed -lt $ALERT_COOLDOWN ]]; then
                log "INFO" "Alerta '$alert_type' en cooldown (${elapsed}s/${ALERT_COOLDOWN}s)"
                return
            fi
        fi
    fi
    
    # Enviar alerta
    echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
    
    # Actualizar estado
    sed -i "/^$alert_type:/d" "$ALERT_STATE_FILE" 2>/dev/null
    echo "$alert_type:$(date +%s)" >> "$ALERT_STATE_FILE"
    
    log "ALERT" "Email enviado: $subject"
}

# Verificar servicio OpenVPN
check_service() {
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log "ERROR" "OpenVPN NO está corriendo"
        send_alert "service_down" \
            "🚨 ALERTA VPN - Servicio Caído" \
            "OpenVPN service is down on $(hostname) at $(date)"
        
        log "INFO" "Intentando reiniciar servicio..."
        systemctl start "$SERVICE_NAME"
        sleep 5
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log "INFO" "OpenVPN reiniciado exitosamente"
            send_alert "service_recovered" \
                "✅ VPN Recuperado - Servicio Reiniciado" \
                "OpenVPN was successfully restarted on $(hostname) at $(date)"
        else
            log "ERROR" "No se pudo reiniciar OpenVPN"
            send_alert "service_failed" \
                "❌ CRÍTICO - VPN No Pudo Reiniciarse" \
                "Failed to restart OpenVPN on $(hostname) at $(date). Manual intervention required."
        fi
    else
        log "OK" "OpenVPN está corriendo"
    fi
}

# Verificar interfaz TUN
check_tun_interface() {
    if ! ip link show "$TUN_INTERFACE" &>/dev/null; then
        log "ERROR" "Interfaz $TUN_INTERFACE no existe"
        send_alert "tun_missing" \
            "🚨 ALERTA VPN - Interfaz TUN Faltante" \
            "TUN interface $TUN_INTERFACE is missing on $(hostname)"
    else
        log "OK" "Interfaz $TUN_INTERFACE existe"
    fi
}

# Verificar puerto
check_port() {
    if ! ss -ulpn | grep -q ":$VPN_PORT"; then
        log "ERROR" "Puerto $VPN_PORT no está escuchando"
        send_alert "port_not_listening" \
            "🚨 ALERTA VPN - Puerto No Escuchando" \
            "OpenVPN is not listening on port $VPN_PORT on $(hostname)"
    else
        log "OK" "Puerto $VPN_PORT escuchando"
    fi
}

# Contar clientes
check_clients() {
    local clients
    clients=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo "0")
    log "INFO" "Clientes conectados: $clients"
    
    if [[ $clients -lt $MIN_CLIENTS ]]; then
        log "WARN" "Pocos clientes conectados: $clients < $MIN_CLIENTS"
    elif [[ $clients -gt $MAX_CLIENTS ]]; then
        log "WARN" "Muchos clientes conectados: $clients > $MAX_CLIENTS"
        send_alert "too_many_clients" \
            "⚠️ AVISO VPN - Muchos Clientes" \
            "Unusual number of VPN clients: $clients on $(hostname)"
    fi
}

# Verificar recursos
check_resources() {
    # CPU
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        log "WARN" "Uso de CPU alto: ${cpu_usage}%"
        send_alert "high_cpu" \
            "⚠️ AVISO VPN - CPU Alta" \
            "High CPU usage on $(hostname): ${cpu_usage}%"
    fi
    
    # Memoria
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
    if (( $(echo "$mem_usage > $MEM_THRESHOLD" | bc -l) )); then
        log "WARN" "Uso de memoria alto: ${mem_usage}%"
        send_alert "high_memory" \
            "⚠️ AVISO VPN - Memoria Alta" \
            "High memory usage on $(hostname): ${mem_usage}%"
    fi
    
    # Disco
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        log "WARN" "Uso de disco alto: ${disk_usage}%"
        send_alert "high_disk" \
            "⚠️ AVISO VPN - Disco Alto" \
            "High disk usage on $(hostname): ${disk_usage}%"
    fi
}

# Ejecución principal
main() {
    log "INFO" "=== Inicio de verificación ==="
    
    check_service
    check_tun_interface
    check_port
    check_clients
    check_resources
    
    log "INFO" "=== Fin de verificación ==="
}

# Ejecutar
main
```

### Dashboard de Métricas

```bash
#!/bin/bash
# vpn-metrics-dashboard.sh

cat << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VPN Monitoring Dashboard</title>
    <meta http-equiv="refresh" content="60">
    <style>
        body { font-family: Arial; margin: 20px; background: #f5f5f5; }
        .card { background: white; padding: 20px; margin: 10px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px; }
        .metric-value { font-size: 2em; font-weight: bold; }
        .metric-label { color: #666; }
        .status-ok { color: #28a745; }
        .status-warn { color: #ffc107; }
        .status-error { color: #dc3545; }
    </style>
</head>
<body>
    <h1>OpenVPN Server Status</h1>
    <div class="card">
        <h2>Service Status</h2>
EOF

# Estado del servicio
if systemctl is-active --quiet openvpn@server; then
    echo '<p class="status-ok">✓ Service Running</p>'
else
    echo '<p class="status-error">✗ Service Down</p>'
fi

# Clientes conectados
clients=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo "0")
echo "<div class='metric'>"
echo "<div class='metric-value'>$clients</div>"
echo "<div class='metric-label'>Connected Clients</div>"
echo "</div>"

# CPU
cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
echo "<div class='metric'>"
echo "<div class='metric-value'>${cpu}%</div>"
echo "<div class='metric-label'>CPU Usage</div>"
echo "</div>"

# Memoria
mem=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
echo "<div class='metric'>"
echo "<div class='metric-value'>${mem}%</div>"
echo "<div class='metric-label'>Memory Usage</div>"
echo "</div>"

cat << 'EOF'
    </div>
    <div class="card">
        <h2>Recent Logs</h2>
        <pre>
EOF

tail -20 /var/log/vpn-monitor.log

cat << 'EOF'
        </pre>
    </div>
    <p style="text-align: center; color: #999;">
        Last updated: <script>document.write(new Date().toLocaleString());</script>
    </p>
</body>
</html>
EOF
```

## Integración con Sistemas de Monitoreo

### Zabbix

```bash
# UserParameter en /etc/zabbix/zabbix_agentd.conf
UserParameter=vpn.service.status,systemctl is-active openvpn@server --quiet && echo 1 || echo 0
UserParameter=vpn.clients.count,grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo 0
UserParameter=vpn.tun.status,ip link show tun0 &>/dev/null && echo 1 || echo 0
UserParameter=vpn.port.listening,ss -ulpn | grep -q ":1194" && echo 1 || echo 0
```

### Prometheus Node Exporter

```bash
#!/bin/bash
# /usr/local/bin/vpn-metrics-exporter.sh

TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
OUTPUT_FILE="$TEXTFILE_DIR/vpn_metrics.prom"

{
    echo "# HELP vpn_service_up OpenVPN service status"
    echo "# TYPE vpn_service_up gauge"
    systemctl is-active --quiet openvpn@server && echo "vpn_service_up 1" || echo "vpn_service_up 0"
    
    echo "# HELP vpn_clients_connected Number of connected VPN clients"
    echo "# TYPE vpn_clients_connected gauge"
    clients=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo "0")
    echo "vpn_clients_connected $clients"
    
    echo "# HELP vpn_tun_interface_up TUN interface status"
    echo "# TYPE vpn_tun_interface_up gauge"
    ip link show tun0 &>/dev/null && echo "vpn_tun_interface_up 1" || echo "vpn_tun_interface_up 0"
} > "$OUTPUT_FILE"
```

**Cron:**
```
* * * * * /usr/local/bin/vpn-metrics-exporter.sh
```

## Troubleshooting

### Script No Envía Emails

```bash
# Verificar configuración de mail
echo "Test" | mail -s "Test" tu_email@ejemplo.com

# Ver logs de postfix
sudo tail -f /var/log/mail.log

# Verificar estado de postfix
sudo systemctl status postfix

# Test con mailutils
echo "Test body" | mail -s "Test subject" -a "From: vpn@servidor.com" tu_email@ejemplo.com
```

### Falsos Positivos en CPU/Memoria

```bash
# Ajustar umbrales en el script
CPU_THRESHOLD=90  # En lugar de 80
MEM_THRESHOLD=90
```

### Logs Crecen Demasiado

```bash
# Implementar logrotate (ver sección anterior)

# O limpiar manualmente logs antiguos
find /var/log -name "vpn-monitor.log*" -mtime +30 -delete
```

## Licencia

GPL-3.0

## Autor

**Proyecto**: homelab-automation-toolkit  
**Última actualización**: Diciembre 2025

## Scripts Relacionados

- [openvpn-install.sh](README.md) - Instalación de OpenVPN
- [openvpn-diagnostics.sh](README-diagnostics.md) - Diagnóstico completo
- [check-vpn-certs.sh](README-cert-checker.md) - Verificación de certificados

---

**Nota**: Este script está diseñado para ejecución periódica vía cron. Para monitoreo en tiempo real considera usar soluciones como Prometheus + Grafana.