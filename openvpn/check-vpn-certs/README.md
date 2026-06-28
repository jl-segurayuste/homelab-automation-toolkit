# OpenVPN Certificate Expiration Checker

Script para verificar la fecha de expiración de certificados OpenVPN y alertar sobre certificados próximos a vencer o ya expirados.

## Descripción

Este script revisa todos los certificados emitidos en la PKI de OpenVPN y reporta su estado de expiración. Es útil para mantenimiento preventivo y evitar interrupciones del servicio por certificados vencidos.

## Características

- ✅ Escaneo automático de todos los certificados en la PKI
- 📅 Cálculo preciso de días restantes hasta expiración
- 🚨 Alertas configurables para certificados próximos a vencer
- 🔴 Detección de certificados ya expirados
- 📊 Reporte claro con códigos de color
- 🔧 Sin modificaciones al sistema (solo lectura)

## Requisitos

### Sistema Operativo
- Linux con bash
- Debian/Ubuntu (compatible con otros sistemas con bash)

### Dependencias
```bash
openssl      # Lectura de certificados X.509
date         # Cálculo de fechas (GNU coreutils)
basename     # Manipulación de rutas (GNU coreutils)
```

### Estructura OpenVPN
El script asume la estructura estándar de Easy-RSA:
```
/etc/openvpn/easy-rsa/pki/issued/
├── server_xxx.crt
├── cliente1.crt
├── cliente2.crt
└── ...
```

## Instalación

```bash
# Descargar el script
wget https://raw.githubusercontent.com/tu-repo/check-vpn-certs.sh

# Dar permisos de ejecución
chmod +x check-vpn-certs.sh

# Mover a un directorio en PATH (opcional)
sudo mv check-vpn-certs.sh /usr/local/bin/
```

## Uso

### Ejecución Básica

```bash
# Ejecutar el script
sudo ./check-vpn-certs.sh
```

**Salida de ejemplo:**
```
Verificando certificados OpenVPN...

[OK] server_abc123 - Expira en 3560 días
[OK] cliente1 - Expira en 3548 días
[AVISO] laptop-trabajo - Expira en 25 días (Jan 2 14:30:00 2025 GMT)
[OK] movil-android - Expira en 180 días
[EXPIRADO] viejo-cliente - Expiró hace 15 días
```

### Guardar Reporte

```bash
# Guardar en archivo con timestamp
sudo ./check-vpn-certs.sh > cert-report-$(date +%Y%m%d).txt

# Ver y guardar simultáneamente
sudo ./check-vpn-certs.sh | tee cert-report.txt
```

### Filtrar Resultados

```bash
# Solo certificados con problemas (avisos o expirados)
sudo ./check-vpn-certs.sh | grep -E '\[AVISO\]|\[EXPIRADO\]'

# Solo certificados expirados
sudo ./check-vpn-certs.sh | grep '\[EXPIRADO\]'

# Contar certificados por estado
sudo ./check-vpn-certs.sh | grep -c '\[OK\]'
sudo ./check-vpn-certs.sh | grep -c '\[AVISO\]'
sudo ./check-vpn-certs.sh | grep -c '\[EXPIRADO\]'
```

## Configuración

### Personalizar Umbral de Advertencia

Por defecto, el script alerta cuando quedan menos de 30 días. Para cambiar esto:

```bash
# Editar el script
nano check-vpn-certs.sh

# Modificar la línea (ejemplo: 60 días)
WARN_DAYS=60
```

### Personalizar Directorio de Certificados

Si tu instalación de OpenVPN usa una ruta diferente:

```bash
# Editar el script
nano check-vpn-certs.sh

# Modificar la línea
CERT_DIR="/ruta/personalizada/pki/issued"
```

## Interpretación de Resultados

### Indicadores de Estado

| Indicador | Color | Significado | Acción Requerida |
|-----------|-------|-------------|------------------|
| `[OK]` | Verde | Certificado válido con más de 30 días | Ninguna |
| `[AVISO]` | Amarillo | Certificado válido pero expira pronto (< 30 días) | Renovar certificado |
| `[EXPIRADO]` | Rojo | Certificado ya expirado | Renovar urgentemente |

### Ejemplos de Salida

#### Certificado OK
```
[OK] cliente1 - Expira en 3548 días
```
- ✅ El cliente puede conectarse sin problemas
- ⏰ Válido por ~9.7 años más

#### Certificado en Aviso
```
[AVISO] laptop-trabajo - Expira en 25 días (Jan 2 14:30:00 2025 GMT)
```
- ⚠️ Funciona ahora pero debe renovarse pronto
- 📅 Fecha exacta de expiración mostrada

#### Certificado Expirado
```
[EXPIRADO] viejo-cliente - Expiró hace 15 días
```
- ❌ El cliente NO puede conectarse
- 🔧 Requiere renovación inmediata

## Acciones Correctivas

### Renovar Certificado Próximo a Expirar

```bash
# Ir al directorio de Easy-RSA
cd /etc/openvpn/easy-rsa/

# Opción 1: Renovar certificado existente (mantiene mismo nombre)
sudo ./easyrsa renew cliente1 nopass

# Opción 2: Revocar y crear uno nuevo
sudo ./easyrsa revoke cliente1
sudo ./easyrsa gen-crl
sudo ./easyrsa build-client-full cliente1 nopass

# Actualizar CRL
sudo cp pki/crl.pem /etc/openvpn/
sudo systemctl restart openvpn@server

# Generar nuevo archivo .ovpn para el cliente
# (Usar el script de instalación original)
```

### Limpiar Certificados Expirados

```bash
# Revocar certificado expirado
cd /etc/openvpn/easy-rsa/
sudo ./easyrsa revoke nombre-cliente

# Regenerar CRL
sudo ./easyrsa gen-crl
sudo cp pki/crl.pem /etc/openvpn/
sudo chmod 644 /etc/openvpn/crl.pem

# Reiniciar OpenVPN
sudo systemctl restart openvpn@server
```

### Eliminar Referencias del Cliente

```bash
# Eliminar archivos .ovpn
sudo find /home/ /root/ -name "nombre-cliente.ovpn" -delete

# Limpiar asignación de IP persistente
sudo sed -i "/^nombre-cliente,/d" /etc/openvpn/ipp.txt
```

## Automatización

### Chequeo Diario con Cron

```bash
# Editar crontab
sudo crontab -e

# Añadir línea para ejecutar diariamente a las 8:00 AM
0 8 * * * /usr/local/bin/check-vpn-certs.sh > /var/log/openvpn/cert-check-$(date +\%Y\%m\%d).log
```

### Alerta por Email

```bash
#!/bin/bash
# check-and-alert.sh

OUTPUT=$(sudo /usr/local/bin/check-vpn-certs.sh)

# Verificar si hay certificados con problemas
if echo "$OUTPUT" | grep -qE '\[AVISO\]|\[EXPIRADO\]'; then
    # Enviar email con el reporte completo
    echo "$OUTPUT" | mail -s "⚠️ Alerta: Certificados OpenVPN próximos a vencer" admin@ejemplo.com
fi
```

**Configurar en cron:**
```bash
# Ejecutar cada lunes a las 9:00 AM
0 9 * * 1 /root/check-and-alert.sh
```

### Integración con Monitoring

#### Nagios/Icinga Check

```bash
#!/bin/bash
# check_openvpn_certs.sh

CERT_DIR="/etc/openvpn/easy-rsa/pki/issued"
WARN_DAYS=30
CRIT_DAYS=7

expired_count=0
warning_count=0

for cert in "$CERT_DIR"/*.crt; do
    if [[ -f "$cert" ]]; then
        expiry_date=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
        
        if [[ $days_left -lt 0 ]]; then
            ((expired_count++))
        elif [[ $days_left -lt $CRIT_DAYS ]]; then
            ((expired_count++))
        elif [[ $days_left -lt $WARN_DAYS ]]; then
            ((warning_count++))
        fi
    fi
done

if [[ $expired_count -gt 0 ]]; then
    echo "CRITICAL - $expired_count certificado(s) expirado(s) o crítico(s)"
    exit 2
elif [[ $warning_count -gt 0 ]]; then
    echo "WARNING - $warning_count certificado(s) expiran pronto"
    exit 1
else
    echo "OK - Todos los certificados válidos"
    exit 0
fi
```

#### Prometheus Exporter

```bash
#!/bin/bash
# openvpn-cert-exporter.sh

CERT_DIR="/etc/openvpn/easy-rsa/pki/issued"
METRICS_FILE="/var/lib/node_exporter/textfile_collector/openvpn_certs.prom"

echo "# HELP openvpn_cert_expiry_days Days until certificate expiration" > "$METRICS_FILE"
echo "# TYPE openvpn_cert_expiry_days gauge" >> "$METRICS_FILE"

for cert in "$CERT_DIR"/*.crt; do
    if [[ -f "$cert" ]]; then
        cert_name=$(basename "$cert" .crt)
        expiry_date=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
        
        echo "openvpn_cert_expiry_days{cert=\"$cert_name\"} $days_left" >> "$METRICS_FILE"
    fi
done
```

**Ejecutar cada hora:**
```bash
# En crontab
0 * * * * /usr/local/bin/openvpn-cert-exporter.sh
```

**Query Prometheus:**
```promql
# Alertar cuando certificados expiran en menos de 30 días
openvpn_cert_expiry_days < 30

# Contar certificados expirados
count(openvpn_cert_expiry_days < 0)
```

### Script de Renovación Automática

```bash
#!/bin/bash
# auto-renew-certs.sh

CERT_DIR="/etc/openvpn/easy-rsa/pki/issued"
RENEW_THRESHOLD=30  # Días antes de expiración para renovar

cd /etc/openvpn/easy-rsa/ || exit 1

for cert in "$CERT_DIR"/*.crt; do
    if [[ -f "$cert" ]]; then
        cert_name=$(basename "$cert" .crt)
        
        # Saltar certificado del servidor
        if [[ "$cert_name" =~ ^server_ ]]; then
            continue
        fi
        
        expiry_date=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
        
        if [[ $days_left -lt $RENEW_THRESHOLD && $days_left -gt 0 ]]; then
            echo "Renovando certificado: $cert_name (expira en $days_left días)"
            
            # Renovar certificado
            ./easyrsa renew "$cert_name" nopass
            
            # Enviar notificación
            echo "El certificado $cert_name ha sido renovado automáticamente" | \
                mail -s "Certificado OpenVPN Renovado: $cert_name" admin@ejemplo.com
        fi
    fi
done

# Regenerar CRL
./easyrsa gen-crl
cp pki/crl.pem /etc/openvpn/
systemctl reload openvpn@server
```

## Dashboard de Certificados

### Script HTML Simple

```bash
#!/bin/bash
# generate-cert-dashboard.sh

CERT_DIR="/etc/openvpn/easy-rsa/pki/issued"
WARN_DAYS=30
OUTPUT_FILE="/var/www/html/openvpn-certs.html"

cat > "$OUTPUT_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Estado de Certificados OpenVPN</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        .ok { background-color: #d4edda; }
        .warning { background-color: #fff3cd; }
        .expired { background-color: #f8d7da; }
    </style>
</head>
<body>
    <h1>Estado de Certificados OpenVPN</h1>
    <p>Última actualización: $(date)</p>
    <table>
        <tr>
            <th>Certificado</th>
            <th>Estado</th>
            <th>Días Restantes</th>
            <th>Fecha Expiración</th>
        </tr>
EOF

for cert in "$CERT_DIR"/*.crt; do
    if [[ -f "$cert" ]]; then
        cert_name=$(basename "$cert" .crt)
        expiry_date=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
        
        if [[ $days_left -lt 0 ]]; then
            status="EXPIRADO"
            css_class="expired"
        elif [[ $days_left -lt $WARN_DAYS ]]; then
            status="AVISO"
            css_class="warning"
        else
            status="OK"
            css_class="ok"
        fi
        
        cat >> "$OUTPUT_FILE" << EOF
        <tr class="$css_class">
            <td>$cert_name</td>
            <td>$status</td>
            <td>$days_left</td>
            <td>$expiry_date</td>
        </tr>
EOF
    fi
done

cat >> "$OUTPUT_FILE" << 'EOF'
    </table>
</body>
</html>
EOF

echo "Dashboard generado: $OUTPUT_FILE"
```

**Actualizar cada hora:**
```bash
# En crontab
0 * * * * /usr/local/bin/generate-cert-dashboard.sh
```

## Mejores Prácticas

### Políticas de Renovación

1. **Revisar mensualmente** el estado de todos los certificados
2. **Renovar con 30 días de anticipación** mínimo
3. **Notificar a usuarios** cuando se renueve su certificado
4. **Mantener registro** de renovaciones y revocaciones
5. **Documentar razones** de revocación

### Gestión de Certificados de Larga Duración

```bash
# Al crear certificados, usar validez apropiada

# Para servidores (10 años)
EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-server-full server nopass

# Para clientes regulares (1 año)
EASYRSA_CERT_EXPIRE=365 ./easyrsa build-client-full cliente nopass

# Para clientes temporales (30 días)
EASYRSA_CERT_EXPIRE=30 ./easyrsa build-client-full temporal nopass
```

### Rotación de Certificados Raíz (CA)

La CA tiene validez de 10 años por defecto. Cuando se acerque la expiración:

```bash
# Verificar expiración de CA
openssl x509 -in /etc/openvpn/ca.crt -noout -enddate

# Si es necesario renovar CA (proceso complejo):
# 1. Crear nueva CA
# 2. Firmar certificados existentes con nueva CA
# 3. Distribuir nueva CA a todos los clientes
# 4. Período de transición con ambas CAs
```

## Limitaciones

- No verifica certificados revocados (solo fechas de expiración)
- No detecta certificados no válidos por otras razones
- Requiere acceso de lectura al directorio PKI
- Basado en formato de fecha de GNU `date` (puede no funcionar en BSD)

## Solución de Problemas

### Error: No such file or directory

```bash
# Verificar que el directorio existe
ls -la /etc/openvpn/easy-rsa/pki/issued/

# Si no existe, verificar ruta de instalación
find /etc/openvpn -name "issued" -type d

# Ajustar CERT_DIR en el script
```

### Fechas Incorrectas

```bash
# Verificar zona horaria del sistema
timedatectl

# Sincronizar reloj
sudo ntpdate -s time.nist.gov
# O con systemd-timesyncd
sudo systemctl restart systemd-timesyncd
```

### Permisos Denegados

```bash
# Dar permisos de lectura (si es necesario)
sudo chmod +r /etc/openvpn/easy-rsa/pki/issued/*.crt

# Ejecutar siempre con sudo
sudo ./check-vpn-certs.sh
```

## Scripts Relacionados

- [openvpn-install.sh](README.md) - Instalación de OpenVPN
- [openvpn-diagnostics.sh](README-diagnostics.md) - Diagnóstico completo del servidor

## Licencia

GPL-3.0

## Autor

**Proyecto**: homelab-automation-toolkit  
**Última actualización**: Diciembre 2025

---

**Tip**: Combina este script con el de diagnóstico para un monitoreo completo del servidor OpenVPN.