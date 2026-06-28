# OpenVPN Diagnostics Script

Script de diagnóstico completo para servidores OpenVPN en Debian/Ubuntu. Verifica el estado del servicio, configuración, certificados, firewall y conexiones activas.

## Descripción

Este script realiza una verificación exhaustiva de todos los componentes críticos de un servidor OpenVPN, identificando problemas comunes y proporcionando información detallada para troubleshooting.

## Características

- ✅ **Verificación del servicio** - Estado, inicio automático
- 🔌 **Puertos de escucha** - Confirma que OpenVPN está escuchando
- 🌐 **Interfaz TUN** - Verifica la interfaz de túnel
- 🔥 **Reglas de firewall** - NAT, INPUT y FORWARD
- 📡 **IP Forwarding** - Estado de IPv4/IPv6 forwarding
- 🔐 **Certificados PKI** - CA, servidor y clientes
- 🚫 **Lista de revocación** - Estado del CRL
- ⚙️ **Configuración** - Resumen de parámetros principales
- 📊 **Clientes activos** - Conexiones en tiempo real
- 📝 **Logs recientes** - Últimas 20 líneas del journal

## Requisitos

### Sistema Operativo
- Debian 11+ o Ubuntu 18.04+
- OpenVPN instalado y configurado

### Permisos
- Acceso root o sudo (necesario para acceder a configuración y logs)

### Dependencias
Todas las herramientas necesarias suelen estar preinstaladas:
```bash
systemctl    # Gestión de servicios (systemd)
ss           # Información de sockets (iproute2)
iptables     # Reglas de firewall
ip           # Información de interfaces de red
openssl      # Verificación de certificados
journalctl   # Lectura de logs (systemd)
cat, grep    # Utilidades básicas
```

## Instalación

### Descarga Directa

```bash
# Descargar el script
wget https://raw.githubusercontent.com/tu-repo/openvpn-diagnostics.sh

# Dar permisos de ejecución
chmod +x openvpn-diagnostics.sh
```

### Desde Repositorio

```bash
git clone https://github.com/tu-repo/openvpn-tools.git
cd openvpn-tools
chmod +x openvpn-diagnostics.sh
```

## Uso

### Ejecución Básica

```bash
# Como root
sudo ./openvpn-diagnostics.sh

# O ejecutar directamente si ya tienes permisos
./openvpn-diagnostics.sh
```

### Guardar Resultados en Archivo

```bash
# Guardar diagnóstico completo
sudo ./openvpn-diagnostics.sh > diagnostico-$(date +%Y%m%d-%H%M%S).txt

# Incluir errores en el archivo
sudo ./openvpn-diagnostics.sh &> diagnostico-completo.txt
```

### Monitoreo Continuo

```bash
# Ejecutar cada 30 segundos
watch -n 30 'sudo ./openvpn-diagnostics.sh'

# Solo la sección de clientes conectados
watch -n 10 'sudo cat /var/log/openvpn/status.log'
```

## Salida del Script

El script genera un informe estructurado en 10 secciones:

### 1. Estado del Servicio
```
[OK] Servicio OpenVPN está activo
● openvpn@server.service - OpenVPN connection to server
   Loaded: loaded
   Active: active (running)
```

**Verifica:**
- Si el servicio está corriendo
- Estado detallado del systemd unit
- Intenta iniciar el servicio si está detenido

### 2. Puerto de Escucha
```
[OK] OpenVPN está escuchando:
udp   LISTEN 0   0   0.0.0.0:1194   0.0.0.0:*   users:(("openvpn",pid=1234))
```

**Verifica:**
- Que OpenVPN está escuchando en el puerto configurado
- Protocolo (UDP/TCP) y dirección de enlace

### 3. Interfaz TUN
```
[OK] Interfaz tun0 existe:
tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP>
    inet 10.8.0.1/24 scope global tun0
```

**Verifica:**
- Existencia de la interfaz tun0
- Dirección IP de la VPN
- Estado de la interfaz (UP/DOWN)

### 4. Reglas de Firewall
```
NAT (MASQUERADE):
MASQUERADE  all  --  10.8.0.0/24  0.0.0.0/0

INPUT (tun0):
ACCEPT     all  --  *      tun0     0.0.0.0/0    0.0.0.0/0

FORWARD:
ACCEPT     all  --  eth0   tun0     0.0.0.0/0    0.0.0.0/0
ACCEPT     all  --  tun0   eth0     0.0.0.0/0    0.0.0.0/0
```

**Verifica:**
- Regla NAT MASQUERADE para clientes VPN
- Tráfico permitido en tun0
- Forwarding entre interfaces

### 5. IP Forwarding
```
[OK] IPv4 forwarding habilitado
```

**Verifica:**
- Estado de `/proc/sys/net/ipv4/ip_forward`
- Debe ser `1` para permitir routing

### 6. Certificados
```
Certificado del servidor:
[OK] Certificado del servidor existe
subject=CN = cn_abc123def456
notBefore=Dec  1 10:30:00 2024 GMT
notAfter=Nov 29 10:30:00 2034 GMT

CA (Autoridad Certificadora):
[OK] CA existe
subject=CN = cn_xyz789ghi012
notBefore=Dec  1 10:30:00 2024 GMT
notAfter=Nov 29 10:30:00 2034 GMT

Clientes válidos:
Total: 3
     1	cliente1
     2	cliente2
     3	laptop-work

Clientes revocados:
Total: 1
     1	old-phone
```

**Verifica:**
- Certificado del servidor y CA existen
- Fechas de validez de certificados
- Lista de clientes válidos y revocados

### 7. Certificate Revocation List (CRL)
```
[OK] CRL existe
nextUpdate=Mar  1 10:30:00 2025 GMT
```

**Verifica:**
- Existencia del archivo CRL
- Fecha de próxima actualización

### 8. Configuración del Servidor
```
Puerto y protocolo:
port 1194
proto udp

Red VPN:
server 10.8.0.0 255.255.255.0
topology subnet

DNS:
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"
```

**Muestra:**
- Puerto y protocolo configurados
- Red VPN asignada
- Servidores DNS configurados para clientes

### 9. Últimas Líneas del Log
```
Dec 08 14:23:45 server openvpn[1234]: TLS: Initial packet from [AF_INET]203.0.113.45:52341
Dec 08 14:23:46 server openvpn[1234]: VERIFY OK: depth=1, CN=cn_xyz789ghi012
Dec 08 14:23:46 server openvpn[1234]: VERIFY OK: depth=0, CN=cliente1
Dec 08 14:23:46 server openvpn[1234]: peer info: IV_VER=2.5.7
Dec 08 14:23:47 server openvpn[1234]: cliente1/203.0.113.45:52341 MULTI_sva: pool returned IPv4=10.8.0.6
```

**Muestra:**
- Eventos recientes del servicio
- Conexiones de clientes
- Errores o advertencias

### 10. Clientes Conectados
```
OpenVPN CLIENT LIST
Updated,2024-12-08 14:25:30
Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since
cliente1,203.0.113.45:52341,12456,45789,2024-12-08 14:23:47
laptop-work,198.51.100.23:44892,89234,123456,2024-12-08 09:15:22
ROUTING TABLE
Virtual Address,Common Name,Real Address,Last Ref
10.8.0.6,cliente1,203.0.113.45:52341,2024-12-08 14:25:28
10.8.0.12,laptop-work,198.51.100.23:44892,2024-12-08 14:25:25
```

**Muestra:**
- Clientes actualmente conectados
- IPs reales y virtuales
- Tráfico transmitido
- Tiempo de conexión

## Interpretación de Resultados

### Indicadores de Estado

| Indicador | Significado |
|-----------|-------------|
| `[OK]` en verde | Componente funcionando correctamente |
| `[ERROR]` en rojo | Problema detectado que requiere atención |
| `[AVISO]` en amarillo | Advertencia, puede funcionar pero revisar |

### Problemas Comunes y Soluciones

#### ❌ Servicio NO está activo

**Problema:**
```
[ERROR] Servicio OpenVPN NO está activo
```

**Solución:**
```bash
# Ver por qué falló
sudo journalctl -xeu openvpn@server

# Verificar configuración
sudo openvpn --config /etc/openvpn/server.conf

# Reintentar inicio
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server
```

#### ❌ OpenVPN NO está escuchando en ningún puerto

**Problema:**
```
[ERROR] OpenVPN NO está escuchando en ningún puerto
```

**Causas posibles:**
1. Servicio no iniciado (ver arriba)
2. Puerto ya en uso por otro proceso
3. Error en configuración del puerto

**Solución:**
```bash
# Verificar si el puerto está ocupado
sudo ss -tulpn | grep :1194

# Verificar configuración
grep "^port\|^proto" /etc/openvpn/server.conf

# Cambiar puerto si es necesario
sudo nano /etc/openvpn/server.conf
sudo systemctl restart openvpn@server
```

#### ❌ Interfaz tun0 NO existe

**Problema:**
```
[ERROR] Interfaz tun0 NO existe
```

**Solución:**
```bash
# Verificar módulo TUN
lsmod | grep tun

# Cargar módulo si no está
sudo modprobe tun

# Verificar /dev/net/tun
ls -la /dev/net/tun

# Reiniciar servicio
sudo systemctl restart openvpn@server
```

#### ❌ IPv4 forwarding deshabilitado

**Problema:**
```
[ERROR] IPv4 forwarding deshabilitado
```

**Solución:**
```bash
# Habilitar temporalmente
sudo sysctl -w net.ipv4.ip_forward=1

# Habilitar permanentemente
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/99-openvpn.conf
sudo sysctl -p /etc/sysctl.d/99-openvpn.conf
```

#### ❌ Reglas de firewall faltantes

**Problema:**
```
NAT (MASQUERADE):
(vacío, sin reglas)
```

**Solución:**
```bash
# Aplicar reglas manualmente
sudo /etc/iptables/add-openvpn-rules.sh

# O reiniciar servicio iptables
sudo systemctl restart iptables-openvpn

# Verificar
sudo iptables -t nat -L POSTROUTING -n -v
```

#### ❌ Certificados NO encontrados

**Problema:**
```
[ERROR] Certificado del servidor NO encontrado
[ERROR] CA NO encontrada
```

**Solución:**
```bash
# Verificar archivos
ls -la /etc/openvpn/*.crt /etc/openvpn/*.key

# Si faltan, regenerar PKI (¡CUIDADO! esto invalida clientes existentes)
cd /etc/openvpn/easy-rsa/
sudo ./easyrsa init-pki
sudo ./easyrsa build-ca
sudo ./easyrsa build-server-full server nopass
```

#### ⚠️ CRL desactualizada

**Problema:**
```
nextUpdate=Jan 15 10:30:00 2024 GMT  # (fecha pasada)
```

**Solución:**
```bash
cd /etc/openvpn/easy-rsa/
sudo ./easyrsa gen-crl
sudo cp pki/crl.pem /etc/openvpn/
sudo chmod 644 /etc/openvpn/crl.pem
sudo systemctl restart openvpn@server
```

## Uso en Producción

### Integración con Monitoreo

#### Nagios/Icinga
```bash
#!/bin/bash
# check_openvpn.sh para Nagios

if systemctl is-active --quiet openvpn@server; then
    echo "OK - OpenVPN activo"
    exit 0
else
    echo "CRITICAL - OpenVPN inactivo"
    exit 2
fi
```

#### Prometheus/Node Exporter
```bash
# Exportar métricas
echo "openvpn_service_status $(systemctl is-active openvpn@server --quiet && echo 1 || echo 0)" > /var/lib/node_exporter/openvpn.prom
echo "openvpn_connected_clients $(grep -c '^CLIENT_LIST' /var/log/openvpn/status.log 2>/dev/null || echo 0)" >> /var/lib/node_exporter/openvpn.prom
```

#### Zabbix
```bash
# UserParameter en zabbix_agentd.conf
UserParameter=openvpn.status,systemctl is-active openvpn@server --quiet && echo 1 || echo 0
UserParameter=openvpn.clients,grep -c '^CLIENT_LIST' /var/log/openvpn/status.log 2>/dev/null || echo 0
```

### Automatización con Cron

```bash
# Ejecutar diagnóstico diario y enviar por email
0 8 * * * /root/openvpn-diagnostics.sh | mail -s "Diagnóstico OpenVPN $(hostname)" admin@ejemplo.com

# Guardar logs históricos
0 0 * * 0 /root/openvpn-diagnostics.sh > /var/log/openvpn/diagnostics-$(date +\%Y\%m\%d).log
```

### Script de Alerta

```bash
#!/bin/bash
# openvpn-alert.sh

if ! systemctl is-active --quiet openvpn@server; then
    echo "ALERTA: OpenVPN caído en $(hostname)" | \
    mail -s "🚨 OpenVPN DOWN" admin@ejemplo.com
    
    # Intentar reiniciar
    systemctl start openvpn@server
    sleep 5
    
    if systemctl is-active --quiet openvpn@server; then
        echo "OpenVPN recuperado automáticamente en $(hostname)" | \
        mail -s "✅ OpenVPN RECOVERED" admin@ejemplo.com
    fi
fi
```

## Información Adicional

### Archivos Relevantes

```
/etc/openvpn/
├── server.conf                    # Configuración principal
├── ca.crt, server.crt, server.key # Certificados
├── crl.pem                        # Lista de revocación
└── easy-rsa/
    └── pki/
        ├── index.txt              # Base de datos de certificados
        ├── issued/                # Certificados emitidos
        └── private/               # Claves privadas

/var/log/openvpn/
└── status.log                     # Estado en tiempo real

/etc/iptables/
├── add-openvpn-rules.sh          # Script de reglas firewall
└── rm-openvpn-rules.sh           # Script para eliminar reglas
```

### Comandos Útiles Complementarios

```bash
# Ver solo clientes conectados
sudo grep CLIENT_LIST /var/log/openvpn/status.log

# Logs en tiempo real
sudo journalctl -u openvpn@server -f

# Tráfico en interfaz tun0
sudo iftop -i tun0

# Estadísticas de conexiones
sudo netstat -an | grep :1194

# Verificar routing
ip route show table main
```

### Troubleshooting Avanzado

#### Análisis de Paquetes

```bash
# Capturar tráfico OpenVPN
sudo tcpdump -i eth0 'udp port 1194' -w openvpn-capture.pcap

# Ver tráfico en tun0
sudo tcpdump -i tun0 -n
```

#### Debugging Detallado

```bash
# Ejecutar OpenVPN en modo debug
sudo openvpn --config /etc/openvpn/server.conf --verb 6

# O modificar server.conf temporalmente
sudo sed -i 's/^verb .*/verb 6/' /etc/openvpn/server.conf
sudo systemctl restart openvpn@server
sudo journalctl -u openvpn@server -f
```

## Compatibilidad

### Versiones Probadas
- ✅ Debian 11 (Bullseye)
- ✅ Debian 12 (Bookworm)
- ✅ Ubuntu 20.04 LTS (Focal)
- ✅ Ubuntu 22.04 LTS (Jammy)
- ✅ Ubuntu 24.04 LTS (Noble)

### OpenVPN Versions
- OpenVPN 2.4.x
- OpenVPN 2.5.x
- OpenVPN 2.6.x

## Licencia

GPL-3.0 - Ver archivo LICENSE para detalles

## Contribución

Reporta bugs o sugerencias a través de Issues en GitHub.

## Autor

**Mantenedor**: homelab-automation-toolkit  
**Basado en**: Mejores prácticas de diagnóstico OpenVPN  
**Última actualización**: Diciembre 2025

## Ver También

- [openvpn-install.sh](README.md) - Script de instalación de OpenVPN
- [Documentación oficial OpenVPN](https://openvpn.net/community-resources/)
- [OpenVPN Troubleshooting Guide](https://community.openvpn.net/openvpn/wiki/TroubleshootingGuide)

---

**Nota**: Este script es solo para diagnóstico y no modifica la configuración del sistema (excepto intentar iniciar el servicio si está detenido).