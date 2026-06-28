# OpenVPN Log Analysis Script

Script de análisis de logs para servidores OpenVPN que extrae métricas clave, detecta patrones de conexión, errores TLS y posibles intentos de ataque.

## Descripción

Este script analiza los logs del servicio OpenVPN para proporcionar un resumen de la actividad del servidor, incluyendo intentos de conexión, errores, desconexiones y estadísticas de IPs. Es útil para troubleshooting, auditoría de seguridad y monitoreo de uso.

## Características

- 📊 **Últimos intentos de conexión** - 10 más recientes en 24h
- 🔐 **Errores TLS** - Contador de fallos de autenticación
- 📉 **Timeouts de inactividad** - Clientes desconectados por inactividad
- 🚫 **IPs baneadas** - Integración con fail2ban
- 📈 **Top 10 IPs** - Estadísticas de intentos de conexión en 7 días
- ⚡ **Ejecución rápida** - Análisis en segundos
- 📝 **Salida estructurada** - Fácil de leer y parsear

## Requisitos

### Sistema Operativo
- Linux con systemd
- Debian/Ubuntu (compatible con otras distribuciones systemd)

### Dependencias

```bash
journalctl    # Lectura de logs systemd
grep          # Filtrado de texto
wc            # Conteo de líneas
sort          # Ordenamiento
uniq          # Eliminación de duplicados
fail2ban      # Opcional - para estadísticas de baneos
```

### Servicios Requeridos

- OpenVPN corriendo bajo systemd (`openvpn@server`)
- fail2ban (opcional, para sección de IPs baneadas)

## Instalación

```bash
# Descargar el script
wget https://raw.githubusercontent.com/tu-repo/analyze-vpn-logs.sh

# Dar permisos de ejecución
chmod +x analyze-vpn-logs.sh

# Mover a directorio en PATH (opcional)
sudo mv analyze-vpn-logs.sh /usr/local/bin/

# Crear alias (opcional)
echo "alias vpn-logs='/usr/local/bin/analyze-vpn-logs.sh'" >> ~/.bashrc
source ~/.bashrc
```

## Uso

### Ejecución Básica

```bash
# Ejecutar análisis
sudo /usr/local/bin/analyze-vpn-logs.sh

# O con alias
sudo vpn-logs
```

**Salida esperada:**
```
=== ANÁLISIS DE LOGS VPN ===

Últimos intentos de conexión:
Dec 08 14:23:45 server openvpn[1234]: TLS: Initial packet from [AF_INET]203.0.113.45:52341
Dec 08 14:25:12 server openvpn[1234]: TLS: Initial packet from [AF_INET]198.51.100.23:44892
Dec 08 15:10:33 server openvpn[1234]: TLS: Initial packet from [AF_INET]192.0.2.15:38271
...

Errores TLS:
3

Clientes desconectados:
5

IPs baneadas por Fail2Ban:
Currently banned:	2
|- 198.51.100.50
`- 203.0.113.100

Top 10 IPs que intentaron conectar:
     15 203.0.113.45
     12 198.51.100.23
      8 192.0.2.15
      5 198.51.100.50
      3 203.0.113.100
      2 192.0.2.88
      1 198.51.100.99
```

### Guardar Reporte

```bash
# Guardar análisis en archivo
sudo /usr/local/bin/analyze-vpn-logs.sh > vpn-analysis-$(date +%Y%m%d).txt

# Añadir a archivo de logs histórico
sudo /usr/local/bin/analyze-vpn-logs.sh >> /var/log/vpn-analysis.log
```

### Análisis Personalizado

```bash
# Ver solo sección específica
sudo journalctl -u openvpn@server --since "24 hours ago" | grep "Initial packet" | tail -20

# Últimos 7 días
sudo journalctl -u openvpn@server --since "7 days ago" | grep "TLS Error"

# Desde fecha específica
sudo journalctl -u openvpn@server --since "2024-12-01" --until "2024-12-08"
```

## Secciones del Análisis

### 1. Últimos Intentos de Conexión

```bash
sudo journalctl -u openvpn@server --since "24 hours ago" | grep "Initial packet" | tail -10
```

**Muestra:**
- Timestamp del intento
- IP origen y puerto
- Últimos 10 intentos en las últimas 24 horas

**Interpretación:**
- **Muchos intentos de la misma IP**: Cliente con problemas de conectividad o ataque
- **IPs desconocidas**: Posibles escaneos o intentos de intrusión
- **Puertos aleatorios**: Normal en clientes NAT

### 2. Errores TLS

```bash
sudo journalctl -u openvpn@server --since "24 hours ago" | grep -i "TLS Error" | wc -l
```

**Detecta:**
- Fallos de handshake TLS
- Certificados inválidos o expirados
- Problemas de autenticación

**Causas comunes:**
- Cliente con certificado revocado
- Certificado expirado
- Configuración incorrecta del cliente
- Ataque de fuerza bruta

### 3. Clientes Desconectados por Inactividad

```bash
sudo journalctl -u openvpn@server --since "24 hours ago" | grep "Inactivity timeout" | wc -l
```

**Indica:**
- Clientes que perdieron conectividad
- Problemas de red del cliente
- Dispositivos móviles que cambian de red

**Normal si:**
- Clientes móviles que apagan pantalla
- Conexiones intermitentes esperadas

**Anormal si:**
- Número excesivo (>20% de conexiones)
- Siempre el mismo cliente

### 4. IPs Baneadas por Fail2Ban

```bash
sudo fail2ban-client status openvpn 2>/dev/null | grep "Banned IP"
```

**Muestra:**
- IPs actualmente bloqueadas
- Requiere fail2ban configurado para OpenVPN

**Configurar fail2ban para OpenVPN:**
```bash
# /etc/fail2ban/filter.d/openvpn.conf
[Definition]
failregex = ^.*TLS Error: TLS key negotiation failed to occur within 60 seconds.*\[AF_INET\]<HOST>:
            ^.*TLS Error: TLS handshake failed.*\[AF_INET\]<HOST>:
            ^.*VERIFY ERROR.*\[AF_INET\]<HOST>:
ignoreregex =

# /etc/fail2ban/jail.local
[openvpn]
enabled = true
port = 1194
protocol = udp
filter = openvpn
logpath = /var/log/syslog
maxretry = 5
findtime = 600
bantime = 3600
```

### 5. Top 10 IPs Conectando

```bash
sudo journalctl -u openvpn@server --since "7 days ago" | \
    grep "Initial packet" | \
    grep -oP '\[AF_INET\]\K[^:]+' | \
    sort | uniq -c | sort -rn | head -10
```

**Análisis:**
- **Alto número de una IP legítima**: Usuario activo normal
- **Alto número de IP desconocida**: Posible ataque
- **Muchas IPs con 1-2 intentos**: Escaneo distribuido

## Script Mejorado con Funciones Avanzadas

```bash
#!/bin/bash
# analyze-vpn-logs-enhanced.sh

# ============= CONFIGURACIÓN =============
TIMEFRAME_RECENT="24 hours ago"
TIMEFRAME_STATS="7 days ago"
SUSPICIOUS_THRESHOLD=10  # Alertar si una IP intenta más de X veces
# =========================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== ANÁLISIS DE LOGS OPENVPN ===${NC}"
echo ""

# 1. Resumen general
echo -e "${GREEN}[1] RESUMEN GENERAL (últimas 24h)${NC}"
echo "────────────────────────────────────"

total_attempts=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | grep -c "Initial packet" || echo "0")
successful_connections=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | grep -c "Peer Connection Initiated" || echo "0")
tls_errors=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | grep -c "TLS Error" || echo "0")
inactivity_timeouts=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | grep -c "Inactivity timeout" || echo "0")

echo "Total de intentos de conexión: $total_attempts"
echo "Conexiones exitosas: $successful_connections"
echo "Errores TLS: $tls_errors"
echo "Timeouts por inactividad: $inactivity_timeouts"

if [[ $total_attempts -gt 0 ]]; then
    success_rate=$(awk "BEGIN {printf \"%.2f\", ($successful_connections/$total_attempts)*100}")
    echo "Tasa de éxito: ${success_rate}%"
fi
echo ""

# 2. Últimos intentos de conexión
echo -e "${GREEN}[2] ÚLTIMOS 10 INTENTOS DE CONEXIÓN${NC}"
echo "────────────────────────────────────"
sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | \
    grep "Initial packet" | \
    tail -10
echo ""

# 3. Errores detallados
echo -e "${GREEN}[3] ERRORES RECIENTES${NC}"
echo "────────────────────────────────────"

echo "Errores TLS (últimas 5 líneas):"
sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | \
    grep -i "TLS Error" | \
    tail -5 || echo "  Ninguno"
echo ""

echo "Errores de verificación de certificados:"
cert_errors=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | grep -c "VERIFY ERROR" || echo "0")
echo "  Total: $cert_errors"
if [[ $cert_errors -gt 0 ]]; then
    sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | \
        grep "VERIFY ERROR" | \
        tail -3
fi
echo ""

# 4. Desconexiones
echo -e "${GREEN}[4] DESCONEXIONES${NC}"
echo "────────────────────────────────────"
echo "Por inactividad: $inactivity_timeouts"

restart_count=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | grep -c "SIGTERM received, sending exit notification" || echo "0")
echo "Reinicios del servicio: $restart_count"
echo ""

# 5. Fail2Ban
echo -e "${GREEN}[5] ESTADO DE FAIL2BAN${NC}"
echo "────────────────────────────────────"
if command -v fail2ban-client >/dev/null 2>&1; then
    if sudo fail2ban-client status openvpn >/dev/null 2>&1; then
        sudo fail2ban-client status openvpn
    else
        echo "Jail 'openvpn' no configurado"
    fi
else
    echo "Fail2ban no instalado"
fi
echo ""

# 6. Top IPs
echo -e "${GREEN}[6] TOP 10 IPs (últimos 7 días)${NC}"
echo "────────────────────────────────────"
echo "Intentos | IP"

sudo journalctl -u openvpn@server --since "$TIMEFRAME_STATS" | \
    grep "Initial packet" | \
    grep -oP '\[AF_INET\]\K[^:]+' | \
    sort | uniq -c | sort -rn | head -10 | \
    while read count ip; do
        if [[ $count -ge $SUSPICIOUS_THRESHOLD ]]; then
            echo -e "${RED}$count${NC}      | $ip ${RED}[SOSPECHOSO]${NC}"
        else
            echo "$count      | $ip"
        fi
    done
echo ""

# 7. Clientes únicos
echo -e "${GREEN}[7] ESTADÍSTICAS DE CLIENTES${NC}"
echo "────────────────────────────────────"
unique_ips=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_STATS" | \
    grep "Initial packet" | \
    grep -oP '\[AF_INET\]\K[^:]+' | \
    sort -u | wc -l)
echo "IPs únicas (7 días): $unique_ips"

# Clientes conectados ahora
if [[ -f /var/log/openvpn/status.log ]]; then
    current_clients=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo "0")
    echo "Clientes conectados actualmente: $current_clients"
    
    if [[ $current_clients -gt 0 ]]; then
        echo ""
        echo "Clientes activos:"
        grep "^CLIENT_LIST" /var/log/openvpn/status.log | \
            awk -F',' '{print "  - "$2" ("$3")"}' 2>/dev/null
    fi
fi
echo ""

# 8. Análisis temporal
echo -e "${GREEN}[8] DISTRIBUCIÓN TEMPORAL (últimas 24h)${NC}"
echo "────────────────────────────────────"
sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | \
    grep "Initial packet" | \
    awk '{print $1, $2, $3}' | \
    cut -d: -f1 | \
    uniq -c | \
    tail -10
echo ""

# 9. Certificados problemáticos
echo -e "${GREEN}[9] CERTIFICADOS PROBLEMÁTICOS${NC}"
echo "────────────────────────────────────"
revoked=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | grep -c "certificate verify failed" || echo "0")
expired=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | grep -c "certificate has expired" || echo "0")

echo "Certificados revocados rechazados: $revoked"
echo "Certificados expirados rechazados: $expired"

if [[ $revoked -gt 0 ]] || [[ $expired -gt 0 ]]; then
    echo ""
    echo "Detalles:"
    sudo journalctl -u openvpn@server --since "$TIMEFRAME_RECENT" | \
        grep -E "certificate verify failed|certificate has expired" | \
        tail -5
fi
echo ""

# 10. Alertas de seguridad
echo -e "${GREEN}[10] ALERTAS DE SEGURIDAD${NC}"
echo "────────────────────────────────────"

# IPs con muchos intentos fallidos
suspicious_ips=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_STATS" | \
    grep "Initial packet" | \
    grep -oP '\[AF_INET\]\K[^:]+' | \
    sort | uniq -c | sort -rn | \
    awk -v threshold=$SUSPICIOUS_THRESHOLD '$1 >= threshold {print $2}')

if [[ -n "$suspicious_ips" ]]; then
    echo -e "${YELLOW}⚠ IPs con actividad sospechosa (>=$SUSPICIOUS_THRESHOLD intentos):${NC}"
    echo "$suspicious_ips" | while read ip; do
        attempts=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_STATS" | \
            grep "Initial packet" | \
            grep -c "$ip")
        successful=$(sudo journalctl -u openvpn@server --since "$TIMEFRAME_STATS" | \
            grep "Peer Connection Initiated" | \
            grep -c "$ip" || echo "0")
        echo "  - $ip: $attempts intentos, $successful exitosos"
    done
else
    echo "✓ No se detectó actividad sospechosa"
fi
echo ""

# Resumen final
echo -e "${BLUE}=== FIN DEL ANÁLISIS ===${NC}"
echo "Generado: $(date)"
```

## Análisis Avanzados

### Detección de Ataques de Fuerza Bruta

```bash
#!/bin/bash
# detect-bruteforce.sh

echo "Detectando posibles ataques de fuerza bruta..."
echo ""

# IPs con más de 20 intentos fallidos en las últimas 24h
sudo journalctl -u openvpn@server --since "24 hours ago" | \
    grep "TLS Error" | \
    grep -oP '\[AF_INET\]\K[^:]+' | \
    sort | uniq -c | sort -rn | \
    awk '$1 > 20 {print "ALERTA: "$2" - "$1" intentos fallidos"}' 

# Verificar si están baneadas
echo ""
echo "Estado en fail2ban:"
sudo fail2ban-client status openvpn 2>/dev/null || echo "Fail2ban no configurado"
```

### Análisis de Patrones Horarios

```bash
#!/bin/bash
# hourly-pattern.sh

echo "Distribución de conexiones por hora (últimos 7 días):"
echo ""

sudo journalctl -u openvpn@server --since "7 days ago" | \
    grep "Peer Connection Initiated" | \
    awk '{print $3}' | \
    cut -d: -f1 | \
    sort | uniq -c | \
    awk '{printf "%02d:00 ", $2; for(i=0;i<$1/5;i++) printf "▓"; printf " (%d)\n", $1}'
```

### Reporte de Clientes Problemáticos

```bash
#!/bin/bash
# problem-clients.sh

echo "=== CLIENTES CON PROBLEMAS ==="
echo ""

cd /etc/openvpn/easy-rsa/ || exit 1

# Obtener lista de clientes válidos
valid_clients=$(tail -n +2 pki/index.txt 2>/dev/null | grep "^V" | cut -d '=' -f 2)

echo "Clientes con errores TLS frecuentes:"
for client in $valid_clients; do
    errors=$(sudo journalctl -u openvpn@server --since "7 days ago" | \
        grep -c "$client.*TLS Error" || echo "0")
    
    if [[ $errors -gt 5 ]]; then
        echo "  - $client: $errors errores"
    fi
done

echo ""
echo "Clientes con desconexiones frecuentes:"
for client in $valid_clients; do
    disconnects=$(sudo journalctl -u openvpn@server --since "7 days ago" | \
        grep -c "$client.*Inactivity timeout" || echo "0")
    
    if [[ $disconnects -gt 10 ]]; then
        echo "  - $client: $disconnects desconexiones"
    fi
done
```

### Exportar a CSV

```bash
#!/bin/bash
# export-stats-csv.sh

OUTPUT="vpn-stats-$(date +%Y%m%d).csv"

echo "timestamp,ip,event_type" > "$OUTPUT"

sudo journalctl -u openvpn@server --since "7 days ago" --output=short-iso | \
    grep -E "Initial packet|Peer Connection|TLS Error" | \
    while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | grep -oP '\[AF_INET\]\K[^:]+' | head -1)
        
        if echo "$line" | grep -q "Initial packet"; then
            event="connection_attempt"
        elif echo "$line" | grep -q "Peer Connection"; then
            event="connection_success"
        elif echo "$line" | grep -q "TLS Error"; then
            event="tls_error"
        fi
        
        echo "$timestamp,$ip,$event" >> "$OUTPUT"
    done

echo "Exportado a: $OUTPUT"
```

## Integración con Grafana

### Script para Prometheus

```bash
#!/bin/bash
# vpn-log-metrics.sh

TEXTFILE="/var/lib/node_exporter/textfile_collector/vpn_logs.prom"

# Conexiones últimas 24h
attempts=$(sudo journalctl -u openvpn@server --since "24 hours ago" | grep -c "Initial packet")
successes=$(sudo journalctl -u openvpn@server --since "24 hours ago" | grep -c "Peer Connection Initiated")
tls_errors=$(sudo journalctl -u openvpn@server --since "24 hours ago" | grep -c "TLS Error")

cat > "$TEXTFILE" <<EOF
# HELP vpn_connection_attempts_24h Connection attempts in last 24 hours
# TYPE vpn_connection_attempts_24h gauge
vpn_connection_attempts_24h $attempts

# HELP vpn_successful_connections_24h Successful connections in last 24 hours
# TYPE vpn_successful_connections_24h gauge
vpn_successful_connections_24h $successes

# HELP vpn_tls_errors_24h TLS errors in last 24 hours
# TYPE vpn_tls_errors_24h gauge
vpn_tls_errors_24h $tls_errors
EOF
```

**PromQL queries para alertas:**
```promql
# Alertar si muchos errores TLS
vpn_tls_errors_24h > 50

# Alertar si baja tasa de éxito
(vpn_successful_connections_24h / vpn_connection_attempts_24h) < 0.8
```

## Automatización

### Reporte Diario por Email

```bash
#!/bin/bash
# daily-vpn-report.sh

REPORT_FILE="/tmp/vpn-daily-report.txt"
EMAIL="admin@ejemplo.com"

# Generar reporte
/usr/local/bin/analyze-vpn-logs.sh > "$REPORT_FILE"

# Enviar por email
mail -s "Reporte Diario VPN - $(hostname) - $(date +%Y-%m-%d)" \
     "$EMAIL" < "$REPORT_FILE"

# Limpiar
rm -f "$REPORT_FILE"
```

**Cron:**
```bash
# Ejecutar a las 8:00 AM todos los días
0 8 * * * /usr/local/bin/daily-vpn-report.sh
```

### Alertas en Tiempo Real

```bash
#!/bin/bash
# realtime-vpn-alerts.sh

echo "Monitoreando logs de OpenVPN en tiempo real..."
echo "Presiona Ctrl+C para salir"
echo ""

sudo journalctl -u openvpn@server -f | while read -r line; do
    # Alertar en errores TLS
    if echo "$line" | grep -q "TLS Error"; then
        ip=$(echo "$line" | grep -oP '\[AF_INET\]\K[^:]+')
        echo "[ALERTA TLS] IP: $ip"
        # Opcional: enviar notificación
        # notify-send "VPN Alert" "TLS Error from $ip"
    fi
    
    # Alertar en certificados expirados
    if echo "$line" | grep -q "certificate has expired"; then
        echo "[ALERTA] Intento con certificado expirado"
    fi
    
    # Mostrar conexiones exitosas
    if echo "$line" | grep -q "Peer Connection Initiated"; then
        ip=$(echo "$line" | grep -oP '\[AF_INET\]\K[^:]+')
        client=$(echo "$line" | grep -oP 'with \K[^,]+')
        echo "[CONEXIÓN] Cliente: $client, IP: $ip"
    fi
done
```

## Análisis Forense

### Investigar IP Específica

```bash
#!/bin/bash
# investigate-ip.sh

if [[ -z "$1" ]]; then
    echo "Uso: $0 <IP_ADDRESS>"
    exit 1
fi

IP="$1"

echo "=== INVESTIGACIÓN DE IP: $IP ==="
echo ""

echo "[1] Total de intentos:"
sudo journalctl -u openvpn@server | grep "$IP" | grep -c "Initial packet"

echo ""
echo "[2] Conexiones exitosas:"
sudo journalctl -u openvpn@server | grep "$IP" | grep -c "Peer Connection Initiated"

echo ""
echo "[3] Errores TLS:"
sudo journalctl -u openvpn@server | grep "$IP" | grep -c "TLS Error"

echo ""
echo "[4] Primera aparición:"
sudo journalctl -u openvpn@server | grep "$IP" | head -1 | awk '{print $1, $2, $3}'

echo ""
echo "[5] Última aparición:"
sudo journalctl -u openvpn@server | grep "$IP" | tail -1 | awk '{print $1, $2, $3}'

echo ""
echo "[6] Estado en fail2ban:"
sudo fail2ban-client status openvpn 2>/dev/null | grep "$IP" || echo "No baneada"

echo ""
echo "[7] Últimas 10 líneas de log:"
sudo journalctl -u openvpn@server | grep "$IP" | tail -10

echo ""
echo "[8] GeoIP lookup:"
if command -v geoiplookup >/dev/null 2>&1; then
    geoiplookup "$IP"
elif command -v curl >/dev/null 2>&1; then
    curl -s "https://ipapi.co/$IP/json/" | jq -r '"\(.city), \(.region), \(.country_name)"'
else
    echo "Herramientas de GeoIP no disponibles"
fi
```

### Timeline de Eventos

```bash
#!/bin/bash
# event-timeline.sh

DAYS="${1:-7}"

echo "Timeline de eventos VPN (últimos $DAYS días)"
echo ""

sudo journalctl -u openvpn@server --since "$DAYS days ago" | \
    grep -E "Initial packet|Peer Connection|TLS Error|Inactivity timeout|restart|SIGTERM" | \
    awk '{
        date=$1" "$2" "$3
        if ($0 ~ /Initial packet/) type="[INTENTO]"
        else if ($0 ~ /Peer Connection/) type="[CONEXIÓN]"
        else if ($0 ~ /TLS Error/) type="[ERROR TLS]"
        else if ($0 ~ /Inactivity/) type="[TIMEOUT]"
        else if ($0 ~ /restart|SIGTERM/) type="[REINICIO]"
        print date, type
    }' | \
    uniq -c | \
    awk '{printf "%s %s %s (%d eventos)\n", $2, $3, $4, $1}'
```

## Troubleshooting

### Logs Vacíos o No Encontrados

```bash
# Verificar que el servicio está loggeando
sudo systemctl status openvpn@server

# Ver configuración de logging
grep "^verb\|^log\|^status" /etc/openvpn/server.conf

# Ver logs directamente sin journalctl
sudo cat /var/log/syslog | grep openvpn

# Si usas rsyslog para openvpn:
sudo cat /var/log/openvpn.log
```

### Journalctl Sin Permisos

```bash
# Añadir usuario al grupo systemd-journal
sudo usermod -aG systemd-journal $USER

# O ejecutar siempre con sudo
sudo analyze-vpn-logs.sh
```

### Fechas Incorrectas

```bash
# Verificar zona horaria
timedatectl

# Ajustar si es necesario
sudo timedatectl set-timezone Europe/Madrid

# Verificar que NTP está sincronizado
timedatectl status | grep "System clock synchronized"
```

## Mejores Prácticas

### Retención de Logs

```bash
# Configurar journald para retener más tiempo
sudo nano /etc/systemd/journald.conf

# Añadir/modificar:
[Journal]
MaxRetentionSec=90day
SystemMaxUse=2G
```

```bash
# Aplicar cambios
sudo systemctl restart systemd-journald
```

### Logs Estructurados

Para análisis más fácil, considera aumentar verbosidad:

```bash
# En /etc/openvpn/server.conf
verb 4  # Nivel de detalle (0-11, default 1)
```

### Exportar Logs a SIEM

```bash
# Enviar logs a servidor remoto
# En /etc/rsyslog.d/openvpn.conf
if $programname == 'openvpn' then @@siem-server.ejemplo.com:514
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
- [backup-vpn.sh](README-backup.md) - Backup y restauración

---

**Nota**: Este script es de solo lectura y no modifica ninguna configuración del sistema.