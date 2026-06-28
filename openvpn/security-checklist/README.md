# OpenVPN Security Checklist Script

Script de verificación de seguridad para servidores OpenVPN que realiza un análisis completo del estado de seguridad, configuración, actualizaciones y recursos del sistema.

## Descripción

Este script ejecuta una lista de verificación (checklist) de seguridad que evalúa 10 aspectos críticos del servidor OpenVPN, incluyendo estado de servicios, firewall, fail2ban, actualizaciones, certificados y recursos del sistema. Es ideal para auditorías de seguridad regulares y cumplimiento de políticas.

## Características

- ✅ **Verificación de servicios** - OpenVPN, UFW, fail2ban
- 🔒 **Estado del firewall** - Confirmación de protección activa
- 📦 **Actualizaciones pendientes** - Seguridad del sistema operativo
- 💾 **Monitoreo de recursos** - Disco, CPU, memoria
- 🔐 **Validación de certificados** - Días hasta expiración
- 🚫 **IPs bloqueadas** - Estado de fail2ban
- 👥 **Clientes activos** - Conexiones actuales
- 📊 **Indicadores visuales** - Códigos de color para resultados
- ⚡ **Ejecución rápida** - Checklist completo en segundos
- 📋 **Salida estructurada** - Formato consistente y parseable

## Requisitos

### Sistema Operativo
- Linux con systemd
- Debian/Ubuntu (recomendado)

### Dependencias

```bash
systemctl     # Gestión de servicios (systemd)
ufw           # Firewall (opcional pero recomendado)
fail2ban      # Sistema anti-intrusión (opcional pero recomendado)
apt           # Gestor de paquetes Debian/Ubuntu
openssl       # Verificación de certificados
df            # Espacio en disco (coreutils)
uptime        # Load average (procps)
stat          # Info de archivos (coreutils)
grep, awk     # Procesamiento de texto (coreutils)
```

### Servicios Esperados

- OpenVPN (`openvpn@server`)
- UFW o iptables (firewall)
- fail2ban (recomendado)

## Instalación

```bash
# Descargar el script
wget https://raw.githubusercontent.com/tu-repo/security-checklist.sh

# Dar permisos de ejecución
chmod +x security-checklist.sh

# Mover a directorio en PATH (opcional)
sudo mv security-checklist.sh /usr/local/bin/

# Crear alias (opcional)
echo "alias vpn-security='/usr/local/bin/security-checklist.sh'" >> ~/.bashrc
source ~/.bashrc
```

## Uso

### Ejecución Básica

```bash
# Ejecutar checklist
sudo /usr/local/bin/security-checklist.sh

# O con alias
sudo vpn-security
```

**Salida esperada:**
```
=== CHECKLIST DE SEGURIDAD VPN ===

[OK] OpenVPN está corriendo
[OK] UFW está activo
[OK] Fail2Ban está corriendo
[OK] Sistema actualizado
[OK] Espacio en disco: 45%
[OK] CA expira en 3560 días
[INFO] IPs baneadas: 3
[INFO] Clientes conectados: 5
[INFO] Última actualización: 2024-12-08
[INFO] Load average: 0.15, 0.20, 0.18

=== FIN CHECKLIST ===
```

### Guardar Resultados

```bash
# Guardar en archivo con timestamp
sudo /usr/local/bin/security-checklist.sh > security-check-$(date +%Y%m%d).txt

# Añadir a log histórico
sudo /usr/local/bin/security-checklist.sh >> /var/log/vpn-security-checks.log
```

### Ejecutar en Modo Silencioso (solo errores)

```bash
# Mostrar solo problemas
sudo /usr/local/bin/security-checklist.sh | grep -E '\[FALLO\]|\[AVISO\]'

# Exit code para scripts
sudo /usr/local/bin/security-checklist.sh > /dev/null 2>&1 && echo "Todo OK" || echo "Hay problemas"
```

## Verificaciones Realizadas

### 1. Estado del Servicio OpenVPN

```bash
if systemctl is-active --quiet openvpn@server; then
    echo "[OK] OpenVPN está corriendo"
else
    echo "[FALLO] OpenVPN NO está corriendo"
fi
```

**Verifica:**
- Que el servicio esté activo
- Que esté en ejecución (no crashed)

**Acción si falla:**
```bash
sudo systemctl start openvpn@server
sudo systemctl status openvpn@server
sudo journalctl -u openvpn@server -n 50
```

### 2. Firewall Activo (UFW)

```bash
if sudo ufw status | grep -q "Status: active"; then
    echo "[OK] UFW está activo"
else
    echo "[FALLO] UFW NO está activo"
fi
```

**Verifica:**
- UFW habilitado y corriendo
- Protección de firewall activa

**Acción si falla:**
```bash
# Habilitar UFW
sudo ufw enable

# Permitir OpenVPN
sudo ufw allow 1194/udp

# Verificar reglas
sudo ufw status verbose
```

**Nota:** Si usas iptables directamente en lugar de UFW, el script mostrará fallo. Esto es normal.

### 3. Fail2Ban Activo

```bash
if systemctl is-active --quiet fail2ban; then
    echo "[OK] Fail2Ban está corriendo"
else
    echo "[FALLO] Fail2Ban NO está corriendo"
fi
```

**Verifica:**
- Servicio fail2ban activo
- Protección anti-fuerza bruta funcionando

**Acción si falla:**
```bash
# Instalar fail2ban si no está
sudo apt install -y fail2ban

# Iniciar servicio
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

# Verificar jails
sudo fail2ban-client status
```

### 4. Actualizaciones Pendientes

```bash
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
if [[ $UPDATES -eq 0 ]]; then
    echo "[OK] Sistema actualizado"
else
    echo "[AVISO] $UPDATES actualizaciones pendientes"
fi
```

**Verifica:**
- Actualizaciones de seguridad disponibles
- Estado del sistema operativo

**Acción si hay avisos:**
```bash
# Ver actualizaciones disponibles
sudo apt update
sudo apt list --upgradable

# Aplicar actualizaciones
sudo apt upgrade -y

# Solo actualizaciones de seguridad
sudo apt-get upgrade -y --only-upgrade \
  $(apt list --upgradable 2>/dev/null | grep security | cut -d/ -f1)
```

### 5. Espacio en Disco

```bash
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [[ $DISK_USAGE -lt 80 ]]; then
    echo "[OK] Espacio en disco: ${DISK_USAGE}%"
else
    echo "[AVISO] Espacio en disco alto: ${DISK_USAGE}%"
fi
```

**Umbrales:**
- < 80% = OK
- ≥ 80% = AVISO

**Acción si hay aviso:**
```bash
# Ver uso de disco por directorio
sudo du -sh /* | sort -h

# Limpiar logs antiguos
sudo journalctl --vacuum-time=30d

# Limpiar cache de APT
sudo apt clean
sudo apt autoclean

# Eliminar paquetes huérfanos
sudo apt autoremove -y
```

### 6. Certificados (CA)

```bash
DAYS_LEFT=$(( ($(date -d "$(openssl x509 -in /etc/openvpn/ca.crt -noout -enddate | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))
if [[ $DAYS_LEFT -gt 30 ]]; then
    echo "[OK] CA expira en $DAYS_LEFT días"
else
    echo "[AVISO] CA expira en $DAYS_LEFT días"
fi
```

**Umbrales:**
- > 30 días = OK
- ≤ 30 días = AVISO

**Acción si hay aviso:**
```bash
# Ver detalles del certificado
openssl x509 -in /etc/openvpn/ca.crt -noout -dates -subject

# Renovar CA (proceso complejo - planificar con anticipación)
# Ver documentación de renovación de CA
```

### 7. IPs Baneadas (fail2ban)

```bash
BANNED=$(sudo fail2ban-client status openvpn 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
echo "[INFO] IPs baneadas: ${BANNED:-0}"
```

**Información:**
- Número de IPs actualmente bloqueadas
- Indicador de intentos de intrusión

**Ver detalles:**
```bash
# Estado completo de fail2ban
sudo fail2ban-client status openvpn

# Ver IPs baneadas
sudo fail2ban-client status openvpn | grep "Banned IP list"

# Desbanear IP específica
sudo fail2ban-client set openvpn unbanip 203.0.113.45
```

### 8. Clientes Conectados

```bash
CLIENTS=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo "0")
echo "[INFO] Clientes conectados: $CLIENTS"
```

**Información:**
- Número actual de clientes conectados
- Indicador de uso del servidor

**Ver detalles:**
```bash
# Lista completa de clientes
cat /var/log/openvpn/status.log

# Solo nombres de clientes
grep "^CLIENT_LIST" /var/log/openvpn/status.log | cut -d',' -f2
```

### 9. Última Actualización del Sistema

```bash
LAST_UPDATE=$(stat -c %y /var/lib/apt/periodic/update-success-stamp 2>/dev/null | cut -d' ' -f1)
echo "[INFO] Última actualización: ${LAST_UPDATE:-Desconocida}"
```

**Información:**
- Fecha de último `apt update`
- Indica qué tan actualizada está la lista de paquetes

**Actualizar:**
```bash
sudo apt update
```

### 10. Load Average

```bash
LOAD=$(uptime | awk -F'load average:' '{print $2}')
echo "[INFO] Load average:$LOAD"
```

**Información:**
- Promedio de carga del sistema (1, 5, 15 minutos)
- Indicador de rendimiento del servidor

**Interpretación:**
- < número de CPUs = OK
- > número de CPUs = Sistema bajo presión

## Script Mejorado con Exit Codes

```bash
#!/bin/bash
# security-checklist-enhanced.sh

# ============= CONFIGURACIÓN =============
DISK_THRESHOLD=80
CERT_WARNING_DAYS=30
LOAD_THRESHOLD=2.0
# =========================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
FAILURES=0
WARNINGS=0
CHECKS=0

# Función de verificación
check() {
    ((CHECKS++))
    local status=$1
    local message=$2
    
    case $status in
        "OK")
            echo -e "${GREEN}[OK]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[AVISO]${NC} $message"
            ((WARNINGS++))
            ;;
        "FAIL")
            echo -e "${RED}[FALLO]${NC} $message"
            ((FAILURES++))
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
    esac
}

echo -e "${BLUE}=== CHECKLIST DE SEGURIDAD VPN ===${NC}"
echo ""

# 1. Servicio OpenVPN
if systemctl is-active --quiet openvpn@server; then
    check "OK" "OpenVPN está corriendo"
else
    check "FAIL" "OpenVPN NO está corriendo"
fi

# 2. Firewall (UFW o iptables)
if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status | grep -q "Status: active"; then
        check "OK" "UFW está activo"
    else
        check "FAIL" "UFW NO está activo"
    fi
elif sudo iptables -L -n | grep -q "ACCEPT.*1194"; then
    check "OK" "iptables configurado para OpenVPN"
else
    check "FAIL" "No se detectó firewall activo (UFW/iptables)"
fi

# 3. Fail2Ban
if systemctl is-active --quiet fail2ban; then
    jails=$(sudo fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d: -f2 | wc -w)
    check "OK" "Fail2Ban está corriendo ($jails jails activas)"
else
    check "WARN" "Fail2Ban NO está corriendo (recomendado)"
fi

# 4. Actualizaciones pendientes
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c security)

if [[ $UPDATES -eq 0 ]]; then
    check "OK" "Sistema actualizado"
elif [[ $SECURITY_UPDATES -gt 0 ]]; then
    check "WARN" "$UPDATES actualizaciones pendientes ($SECURITY_UPDATES de seguridad)"
else
    check "INFO" "$UPDATES actualizaciones pendientes"
fi

# 5. Espacio en disco
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [[ $DISK_USAGE -lt $DISK_THRESHOLD ]]; then
    check "OK" "Espacio en disco: ${DISK_USAGE}%"
elif [[ $DISK_USAGE -lt 90 ]]; then
    check "WARN" "Espacio en disco alto: ${DISK_USAGE}%"
else
    check "FAIL" "Espacio en disco crítico: ${DISK_USAGE}%"
fi

# 6. Certificado CA
if [[ -f /etc/openvpn/ca.crt ]]; then
    DAYS_LEFT=$(( ($(date -d "$(openssl x509 -in /etc/openvpn/ca.crt -noout -enddate | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))
    
    if [[ $DAYS_LEFT -gt 365 ]]; then
        check "OK" "CA expira en $DAYS_LEFT días"
    elif [[ $DAYS_LEFT -gt $CERT_WARNING_DAYS ]]; then
        check "INFO" "CA expira en $DAYS_LEFT días"
    elif [[ $DAYS_LEFT -gt 0 ]]; then
        check "WARN" "CA expira en $DAYS_LEFT días"
    else
        check "FAIL" "CA ha expirado hace $((-DAYS_LEFT)) días"
    fi
else
    check "FAIL" "Certificado CA no encontrado"
fi

# 7. Certificados de clientes próximos a expirar
if [[ -d /etc/openvpn/easy-rsa/pki/issued/ ]]; then
    EXPIRING_CERTS=0
    for cert in /etc/openvpn/easy-rsa/pki/issued/*.crt; do
        if [[ -f "$cert" ]]; then
            days_left=$(( ($(date -d "$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))
            if [[ $days_left -lt $CERT_WARNING_DAYS && $days_left -gt 0 ]]; then
                ((EXPIRING_CERTS++))
            fi
        fi
    done
    
    if [[ $EXPIRING_CERTS -eq 0 ]]; then
        check "OK" "No hay certificados de clientes próximos a expirar"
    else
        check "WARN" "$EXPIRING_CERTS certificado(s) de cliente expiran en menos de $CERT_WARNING_DAYS días"
    fi
fi

# 8. IPs baneadas
if systemctl is-active --quiet fail2ban; then
    BANNED=$(sudo fail2ban-client status openvpn 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
    if [[ -n "$BANNED" && "$BANNED" != "0" ]]; then
        check "INFO" "IPs baneadas: ${BANNED}"
    else
        check "INFO" "No hay IPs baneadas actualmente"
    fi
fi

# 9. Clientes conectados
CLIENTS=$(grep -c "^CLIENT_LIST" /var/log/openvpn/status.log 2>/dev/null || echo "0")
check "INFO" "Clientes conectados: $CLIENTS"

# 10. Última actualización del sistema
if [[ -f /var/lib/apt/periodic/update-success-stamp ]]; then
    LAST_UPDATE=$(stat -c %y /var/lib/apt/periodic/update-success-stamp 2>/dev/null | cut -d' ' -f1)
    DAYS_SINCE=$(( ($(date +%s) - $(stat -c %Y /var/lib/apt/periodic/update-success-stamp)) / 86400 ))
    
    if [[ $DAYS_SINCE -lt 7 ]]; then
        check "OK" "Última actualización: $LAST_UPDATE ($DAYS_SINCE días)"
    elif [[ $DAYS_SINCE -lt 30 ]]; then
        check "INFO" "Última actualización: $LAST_UPDATE ($DAYS_SINCE días)"
    else
        check "WARN" "Última actualización: $LAST_UPDATE ($DAYS_SINCE días atrás)"
    fi
else
    check "INFO" "Última actualización: Desconocida"
fi

# 11. Load average
LOAD_1=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
NUM_CPUS=$(nproc)
check "INFO" "Load average (1min): $LOAD_1 (CPUs: $NUM_CPUS)"

if (( $(echo "$LOAD_1 > $NUM_CPUS * 2" | bc -l) )); then
    check "WARN" "Load promedio alto para número de CPUs"
fi

# 12. Uso de memoria
MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
if (( $(echo "$MEM_USAGE < 80" | bc -l) )); then
    check "OK" "Uso de memoria: ${MEM_USAGE}%"
elif (( $(echo "$MEM_USAGE < 90" | bc -l) )); then
    check "WARN" "Uso de memoria alto: ${MEM_USAGE}%"
else
    check "FAIL" "Uso de memoria crítico: ${MEM_USAGE}%"
fi

# 13. Permisos de archivos críticos
critical_files=(
    "/etc/openvpn/server.conf:600"
    "/etc/openvpn/ca.key:600"
    "/etc/openvpn/easy-rsa/pki/private:700"
)

PERM_ERRORS=0
for file_perm in "${critical_files[@]}"; do
    file="${file_perm%:*}"
    expected_perm="${file_perm#*:}"
    
    if [[ -e "$file" ]]; then
        actual_perm=$(stat -c %a "$file")
        if [[ "$actual_perm" != "$expected_perm" ]]; then
            ((PERM_ERRORS++))
        fi
    fi
done

if [[ $PERM_ERRORS -eq 0 ]]; then
    check "OK" "Permisos de archivos críticos correctos"
else
    check "WARN" "$PERM_ERRORS archivo(s) con permisos incorrectos"
fi

# 14. Puerto OpenVPN escuchando
if ss -ulpn 2>/dev/null | grep -q ":1194"; then
    check "OK" "Puerto 1194 está escuchando"
else
    check "FAIL" "Puerto 1194 NO está escuchando"
fi

# 15. Interfaz TUN
if ip link show tun0 &>/dev/null; then
    check "OK" "Interfaz tun0 existe"
else
    check "FAIL" "Interfaz tun0 NO existe"
fi

# Resumen final
echo ""
echo -e "${BLUE}=== RESUMEN ===${NC}"
echo "Total de verificaciones: $CHECKS"
echo -e "${GREEN}OK: $((CHECKS - FAILURES - WARNINGS))${NC}"
echo -e "${YELLOW}Avisos: $WARNINGS${NC}"
echo -e "${RED}Fallos: $FAILURES${NC}"
echo ""

# Exit code
if [[ $FAILURES -gt 0 ]]; then
    echo -e "${RED}Estado: CRÍTICO${NC}"
    exit 2
elif [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}Estado: ADVERTENCIA${NC}"
    exit 1
else
    echo -e "${GREEN}Estado: OK${NC}"
    exit 0
fi
```

## Automatización

### Checklist Diario

```bash
# Añadir a crontab
sudo crontab -e

# Ejecutar diariamente a las 9:00 AM
0 9 * * * /usr/local/bin/security-checklist.sh > /var/log/vpn-daily-check.log 2>&1
```

### Alerta por Email si Hay Problemas

```bash
#!/bin/bash
# security-check-alert.sh

OUTPUT=$(/usr/local/bin/security-checklist.sh)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    # Hay problemas, enviar email
    echo "$OUTPUT" | mail -s "⚠️ VPN Security Alert - $(hostname)" admin@ejemplo.com
fi
```

**Cron:**
```bash
0 */6 * * * /usr/local/bin/security-check-alert.sh
```

### Integración con Nagios

```bash
#!/bin/bash
# /usr/lib/nagios/plugins/check_vpn_security

/usr/local/bin/security-checklist-enhanced.sh > /dev/null
EXIT_CODE=$?

case $EXIT_CODE in
    0)
        echo "OK - VPN security checks passed"
        exit 0
        ;;
    1)
        echo "WARNING - VPN security issues detected"
        exit 1
        ;;
    2)
        echo "CRITICAL - VPN security failures detected"
        exit 2
        ;;
    *)
        echo "UNKNOWN - Unable to check VPN security"
        exit 3
        ;;
esac
```

### Dashboard Web

```bash
#!/bin/bash
# generate-security-dashboard.sh

OUTPUT_FILE="/var/www/html/vpn-security.html"

cat > "$OUTPUT_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>VPN Security Status</title>
    <meta http-equiv="refresh" content="300">
    <style>
        body { font-family: monospace; margin: 20px; background: #1e1e1e; color: #d4d4d4; }
        .ok { color: #4ec9b0; }
        .warn { color: #ce9178; }
        .fail { color: #f48771; }
        .info { color: #569cd6; }
        pre { background: #252526; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>VPN Security Checklist</h1>
    <p>Last updated: <span id="time"></span></p>
    <pre>
HTMLEOF

# Ejecutar checklist y colorear salida
/usr/local/bin/security-checklist.sh | sed \
    -e 's/\[OK\]/<span class="ok">[OK]<\/span>/g' \
    -e 's/\[AVISO\]/<span class="warn">[AVISO]<\/span>/g' \
    -e 's/\[FALLO\]/<span class="fail">[FALLO]<\/span>/g' \
    -e 's/\[INFO\]/<span class="info">[INFO]<\/span>/g' \
    >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'HTMLEOF'
    </pre>
    <script>
        document.getElementById('time').innerHTML = new Date().toLocaleString();
    </script>
</body>
</html>
HTMLEOF

echo "Dashboard actualizado: $OUTPUT_FILE"
```

**Cron:**
```bash
*/5 * * * * /usr/local/bin/generate-security-dashboard.sh
```

## Personalización

### Añadir Verificaciones Propias

```bash
# Verificar backup reciente
if [[ -f /backup/vpn/vpn_backup_$(date +%Y%m%d)* ]]; then
    check "OK" "Backup de hoy existe"
else
    check "WARN" "No hay backup de hoy"
fi

# Verificar configuración específica
if grep -q "^verb 3" /etc/openvpn/server.conf; then
    check "OK" "Nivel de log adecuado"
else
    check "INFO" "Nivel de log diferente al recomendado"
fi

# Verificar que tls-crypt está habilitado
if grep -q "^tls-crypt" /etc/openvpn/server.conf; then
    check "OK" "tls-crypt habilitado"
else
    check "WARN" "tls-crypt no habilitado (recomendado)"
fi
```

### Umbrales Personalizados

Editar variables al inicio del script:

```bash
# Umbrales personalizados
DISK_THRESHOLD=85        # % de disco
CERT_WARNING_DAYS=60     # Días antes de expiración
MEM_THRESHOLD=85         # % de memoria
LOAD_MULTIPLIER=1.5      # Load vs CPUs
UPDATE_AGE_DAYS=14       # Días sin actualizar
```

## Reporting

### Reporte Semanal Consolidado

```bash
#!/bin/bash
# weekly-security-report.sh

REPORT_FILE="/tmp/vpn-weekly-security-report.txt"

{
    echo "========================================="
    echo "  REPORTE SEMANAL DE SEGURIDAD VPN"
    echo "  Servidor: $(hostname)"
    echo "  Periodo: $(date -d '7 days ago' +%Y-%m-%d) - $(date +%Y-%m-%d)"
    echo "========================================="
    echo ""
    
    echo "CHECKLIST ACTUAL:"
    /usr/local/bin/security-checklist.sh
    
    echo ""
    echo "ACTIVIDAD DE LA SEMANA:"
    echo ""
    
    echo "Total de intentos de conexión:"
    sudo journalctl -u openvpn@server --since "7 days ago" | grep -c "Initial packet"
    
    echo ""
    echo "Conexiones exitosas:"
    sudo journalctl -u openvpn@server --since "7 days ago" | grep -c "Peer Connection Initiated"
    
    echo ""
    echo "Errores TLS:"
    sudo journalctl -u openvpn@server --since "7 days ago" | grep -c "TLS Error"
    
    echo ""
    echo "IPs baneadas esta semana:"
    sudo journalctl -u fail2ban --since "7 days ago" | grep "Ban" | wc -l
    
    echo ""
    echo "Actualizaciones aplicadas:"
    grep "$(date -d '7 days ago' +%Y-%m-%d)" /var/log/apt/history.log 2>/dev/null | grep -c "Install:"
    
} > "$REPORT_FILE"

# Enviar por email
mail -s "Reporte Semanal VPN - $(hostname)" admin@ejemplo.com < "$REPORT_FILE"

# Limpiar
rm -f "$REPORT_FILE"
```

**Cron - Lunes a las 8 AM:**
```bash
0 8 * * 1 /usr/local/bin/weekly-security-report.sh
```

## Compliance y Auditoría

### Generar Reporte de Cumplimiento

```bash
#!/bin/bash
# compliance-report.sh

echo "========================================="
echo "  REPORTE DE CUMPLIMIENTO DE SEGURIDAD"
echo "  Generado: $(date)"
echo "  Servidor: $(hostname)"
echo "========================================="
echo ""

echo "[REQUISITO] Firewall activo"
if sudo ufw status | grep -q "Status: active"; then
    echo "  ✓ CUMPLE"
else
    echo "  ✗ NO CUMPLE"
fi

echo ""
echo "[REQUISITO] Sistema anti-intrusión"
if systemctl is-active --quiet fail2ban; then
    echo "  ✓ CUMPLE"
else
    echo "  ✗ NO CUMPLE"
fi

echo ""
echo "[REQUISITO] Actualizaciones aplicadas regularmente"
DAYS_SINCE=$(( ($(date +%s) - $(stat -c %Y /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo 0)) / 86400 ))
if [[ $DAYS_SINCE -lt 30 ]]; then
    echo "  ✓ CUMPLE (última actualización hace $DAYS_SINCE días)"
else
    echo "  ✗ NO CUMPLE (última actualización hace $DAYS_SINCE días)"
fi

echo ""
echo "[REQUISITO] Certificados válidos por al menos 30 días"
DAYS_LEFT=$(( ($(date -d "$(openssl x509 -in /etc/openvpn/ca.crt -noout -enddate | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))
if [[ $DAYS_LEFT -gt 30 ]]; then
    echo "  ✓ CUMPLE (CA válida por $DAYS_LEFT días)"
else
    echo "  ✗ NO CUMPLE (CA válida por solo $DAYS_LEFT días)"
fi

echo ""
echo "[REQUISITO] Cifrado fuerte habilitado"
if grep -q "AES-.*-GCM" /etc/openvpn/server.conf; then
    echo "  ✓ CUMPLE (usando AES-GCM)"
else
    echo "  ⚠ REVISAR (no se detectó AES-GCM)"
fi

echo ""
echo "[REQUISITO] tls-crypt o tls-auth habilitado"
if grep -qE "^tls-crypt|^tls-auth" /etc/openvpn/server.conf; then
    echo "  ✓ CUMPLE"
else
    echo "  ✗ NO CUMPLE"
fi

echo ""
echo "[REQUISITO] Backups configurados"
if [[ -d /backup/vpn ]] && [[ $(find /backup/vpn -name "vpn_backup_*.tar.gz" -mtime -7 | wc -l) -gt 0 ]]; then
    echo "  ✓ CUMPLE (backup reciente encontrado)"
else
    echo "  ✗ NO CUMPLE (no hay backup reciente)"
fi
```

## Troubleshooting

### Script No Encuentra UFW

Si usas iptables directamente:

```bash
# Modificar el script para verificar iptables
if sudo iptables -L -n | grep -q "ACCEPT.*1194"; then
    echo "[OK] Firewall (iptables) configurado"
else
    echo "[FALLO] Firewall no detectado"
fi
```

### Fail2ban No Instalado

```bash
# Instalar fail2ban
sudo apt update
sudo apt install -y fail2ban

# Configurar jail para OpenVPN
sudo nano /etc/fail2ban/jail.local
# ... ver documentación de fail2ban
```

### Permisos Denegados

```bash
# Ejecutar siempre con sudo
sudo /usr/local/bin/security-checklist.sh

# O añadir excepciones a sudoers para comandos específicos
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
- [analyze-vpn-logs.sh](README-log-analysis.md) - Análisis de logs

---

**Recomendación**: Ejecutar este checklist semanalmente como mínimo, o diariamente en entornos de producción críticos.