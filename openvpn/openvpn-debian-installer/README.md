# OpenVPN Installer - Debian/Ubuntu

Script automatizado para instalación, configuración y gestión de servidor OpenVPN en sistemas Debian/Ubuntu.

## Características

- ✅ Instalación completamente automatizada o interactiva
- 🔐 Configuración de cifrado moderna y segura (ECDSA/RSA, AES-GCM)
- 🌐 Soporte IPv4/IPv6
- 🛡️ Múltiples opciones de DNS (Cloudflare, Quad9, Google, AdGuard, Unbound local)
- 📱 Generación automática de archivos `.ovpn` para clientes
- 🔄 Gestión completa de certificados (crear, revocar)
- 🚀 Detección automática de configuración de red
- 🔥 Configuración automática de firewall (iptables)

## Requisitos del Sistema

### Sistemas Operativos Soportados
- Debian 11 (Bullseye) o superior
- Ubuntu 18.04 LTS o superior
- Raspbian (Debian-based)

### Requisitos Técnicos
- Acceso root o sudo
- Dispositivo TUN/TAP disponible
- Conexión a Internet
- Al menos 512 MB de RAM
- 100 MB de espacio libre en disco

### Paquetes Instalados Automáticamente

El script instalará automáticamente:
```bash
openvpn          # Servidor OpenVPN
iptables         # Firewall y reglas NAT
openssl          # Generación de certificados y cifrado
wget             # Descarga de Easy-RSA
ca-certificates  # Certificados CA para conexiones HTTPS
curl             # Detección de IP pública
unbound          # DNS resolver local (solo si se selecciona opción DNS=2)
```

**Nota**: Easy-RSA se descarga directamente desde GitHub como tarball, no desde repositorios APT.

### Puertos Necesarios
- Puerto personalizable (por defecto: 1194 UDP)
- El puerto debe estar abierto en el firewall externo si existe

## Instalación Rápida

### Modo Interactivo (Recomendado)

```bash
# Descargar el script
wget https://raw.githubusercontent.com/tu-repo/openvpn-install.sh

# Dar permisos de ejecución
chmod +x openvpn-install.sh

# Ejecutar como root
sudo ./openvpn-install.sh
```

El script te guiará paso a paso por todas las opciones de configuración.

### Modo Automático (Sin Interacción)

```bash
sudo AUTO_INSTALL=y ./openvpn-install.sh
```

Esto instalará OpenVPN con la configuración recomendada:
- Puerto 1194 UDP
- Cloudflare DNS
- Cifrado: ECDSA P-256 + AES-128-GCM
- Sin compresión
- Cliente inicial: "client"

## Opciones de Configuración

### Variables de Entorno para Instalación Automática

```bash
AUTO_INSTALL=y          # Instalación sin prompts
APPROVE_INSTALL=y       # Auto-aprobar instalación
APPROVE_IP=y            # Auto-aprobar IP detectada
ENDPOINT=vpn.ejemplo.com # IP pública o hostname
IPV6_SUPPORT=n          # Habilitar IPv6 (y/n)
PORT_CHOICE=1           # 1=1194, 2=custom, 3=random
PORT=1194               # Puerto personalizado (si PORT_CHOICE=2)
PROTOCOL_CHOICE=1       # 1=UDP, 2=TCP
DNS=3                   # Ver sección DNS
COMPRESSION_ENABLED=n   # Habilitar compresión LZ4 (y/n)
CUSTOMIZE_ENC=n         # Personalizar cifrado (y/n)
CLIENT=nombre           # Nombre del primer cliente
PASS=1                  # 1=sin password, 2=con password
```

### Opciones de DNS

| Opción | Proveedor | IPs |
|--------|-----------|-----|
| 1 | Sistema | Del archivo `/etc/resolv.conf` |
| 2 | Unbound | DNS local auto-hospedado |
| 3 | Cloudflare | 1.1.1.1, 1.0.0.1 |
| 4 | Quad9 | 9.9.9.9, 149.112.112.112 |
| 5 | Google | 8.8.8.8, 8.8.4.4 |
| 6 | AdGuard | 94.140.14.14, 94.140.15.15 |
| 7 | Personalizado | Especificar manualmente |

### Ejemplo de Instalación Personalizada

```bash
sudo AUTO_INSTALL=y \
     ENDPOINT=vpn.midominio.com \
     PORT=443 \
     PROTOCOL_CHOICE=2 \
     DNS=4 \
     IPV6_SUPPORT=y \
     CLIENT=usuario1 \
     ./openvpn-install.sh
```

## Configuración de Cifrado

### Predeterminada (Recomendada)
- **Certificados**: ECDSA con curva P-256
- **Cifrado de datos**: AES-128-GCM
- **Canal de control**: TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256
- **DH**: ECDH con curva P-256
- **HMAC**: SHA256
- **TLS**: tls-crypt

### Personalizada
Si estableces `CUSTOMIZE_ENC=y`, podrás elegir:

**Cifrados disponibles:**
- AES-128-GCM (recomendado)
- AES-192-GCM
- AES-256-GCM
- AES-128-CBC
- AES-192-CBC
- AES-256-CBC

**Tipos de certificado:**
- ECDSA (P-256, P-384, P-521)
- RSA (2048, 3072, 4096 bits)

**Diffie-Hellman:**
- ECDH (P-256, P-384, P-521)
- DH clásico (2048, 3072, 4096 bits)

## Gestión del Servidor

### Añadir Nuevos Clientes

```bash
sudo ./openvpn-install.sh
```

Selecciona la opción 1 del menú y proporciona:
- Nombre del cliente (alfanumérico, - y _)
- Protección con contraseña (opcional)

El archivo `.ovpn` se generará en `/root/` o `/home/usuario/`

### Revocar Certificados

```bash
sudo ./openvpn-install.sh
```

Selecciona la opción 2 y elige el cliente a revocar. El certificado se agregará a la CRL (Certificate Revocation List) inmediatamente.

### Verificar Estado del Servicio

```bash
# Estado del servicio
sudo systemctl status openvpn@server

# Ver logs en tiempo real
sudo journalctl -u openvpn@server -f

# Ver clientes conectados
sudo cat /var/log/openvpn/status.log
```

### Reiniciar el Servicio

```bash
sudo systemctl restart openvpn@server
```

## Configuración de Clientes

### Archivos de Configuración

Los archivos `.ovpn` contienen todo lo necesario:
- Certificados CA, cliente y clave privada
- Configuración de conexión
- Claves TLS (tls-crypt o tls-auth)

### Clientes Recomendados

**Windows:**
- OpenVPN GUI oficial
- Descargar de: https://openvpn.net/community-downloads/

**macOS:**
- Tunnelblick (gratuito, open source)
- OpenVPN Connect

**Linux:**
```bash
# Debian/Ubuntu
sudo apt install openvpn
sudo openvpn --config cliente.ovpn

# Con systemd
sudo cp cliente.ovpn /etc/openvpn/client/
sudo systemctl start openvpn-client@cliente
```

**Android:**
- OpenVPN for Android (F-Droid/Play Store)

**iOS:**
- OpenVPN Connect (App Store)

### Importar Configuración

1. Transfiere el archivo `.ovpn` al dispositivo cliente
2. Importa el archivo en la aplicación OpenVPN
3. Conecta usando las credenciales si se configuró con contraseña

## Firewall y Seguridad

### Reglas iptables Automáticas

El script configura automáticamente:
- NAT/Masquerading para clientes VPN
- Forwarding entre interfaces tun0 y la interfaz de red principal
- Permitir tráfico en el puerto OpenVPN

### Verificar Reglas

```bash
# IPv4
sudo iptables -t nat -L -n -v
sudo iptables -L FORWARD -n -v

# IPv6 (si está habilitado)
sudo ip6tables -t nat -L -n -v
sudo ip6tables -L FORWARD -n -v
```

### Firewall Externo

Si usas un firewall externo (ej: AWS Security Group, UFW):

```bash
# UFW ejemplo
sudo ufw allow 1194/udp
sudo ufw enable

# Para TCP en puerto 443
sudo ufw allow 443/tcp
```

## Troubleshooting

### El servicio no inicia

```bash
# Ver logs detallados
sudo journalctl -xeu openvpn@server

# Verificar configuración
sudo openvpn --config /etc/openvpn/server.conf

# Verificar permisos
sudo ls -la /etc/openvpn/
```

### Clientes no pueden conectar

**Verificar:**
1. Puerto abierto en firewall externo
2. IP pública correcta en ENDPOINT
3. Servicio OpenVPN activo: `systemctl status openvpn@server`
4. Logs del servidor: `journalctl -u openvpn@server -f`

**Errores comunes:**
- **TLS Error**: Verifica que el archivo .ovpn tenga las claves correctas
- **Timeout**: El puerto está bloqueado o la IP/hostname es incorrecta
- **Certificate verify failed**: Reloj del cliente/servidor desincronizado

### Clientes conectan pero no hay Internet

```bash
# Verificar IP forwarding
sudo sysctl net.ipv4.ip_forward
# Debe devolver: net.ipv4.ip_forward = 1

# Verificar reglas NAT
sudo iptables -t nat -L POSTROUTING -n -v

# Aplicar reglas manualmente si es necesario
sudo /etc/iptables/add-openvpn-rules.sh
```

### Problemas de DNS

**Desde el cliente VPN:**
```bash
# Verificar DNS asignado (Linux)
nslookup google.com

# Windows (PowerShell)
Get-DnsClientServerAddress
```

**Cambiar DNS del servidor:**
Edita `/etc/openvpn/server.conf` y modifica las líneas `push "dhcp-option DNS x.x.x.x"`, luego reinicia:
```bash
sudo systemctl restart openvpn@server
```

### Rendimiento bajo

**Optimizaciones:**

1. Usar UDP en lugar de TCP
2. Reducir tamaño de clave RSA a 2048 bits
3. Usar ECDSA en lugar de RSA
4. Deshabilitar compresión si la CPU es limitada
5. Ajustar MTU:

```bash
# En /etc/openvpn/server.conf
tun-mtu 1500
mssfix 1450
```

## Desinstalación

```bash
sudo ./openvpn-install.sh
```

Selecciona la opción 3 del menú. El script eliminará:
- Servicio OpenVPN
- Todos los certificados y claves
- Configuraciones de clientes
- Reglas de firewall
- Archivos de configuración

Opcionalmente también eliminará Unbound si fue instalado.

## Estructura de Archivos

```
/etc/openvpn/
├── server.conf              # Configuración principal del servidor
├── ca.crt                   # Certificado de la CA
├── server.crt               # Certificado del servidor
├── server.key               # Clave privada del servidor
├── crl.pem                  # Lista de revocación
├── tls-crypt.key            # Clave tls-crypt
├── dh.pem                   # Parámetros DH (si se usa)
├── client-template.txt      # Template para clientes
├── ipp.txt                  # IPs persistentes de clientes
├── ccd/                     # Client config directory
└── easy-rsa/                # PKI y gestión de certificados
    ├── vars                 # Variables de configuración
    └── pki/                 # Certificados y claves

/etc/iptables/
├── add-openvpn-rules.sh     # Script para añadir reglas
└── rm-openvpn-rules.sh      # Script para eliminar reglas

/var/log/openvpn/
└── status.log               # Estado y clientes conectados
```

## Seguridad

### Mejores Prácticas

1. **Usar certificados ECDSA** con curvas P-256 o superiores
2. **Habilitar tls-crypt** para protección contra análisis de tráfico
3. **No usar compresión** (vulnerable a VORACLE)
4. **Mantener el sistema actualizado**:
   ```bash
   sudo apt update && sudo apt upgrade
   ```
5. **Usar contraseñas fuertes** para claves privadas de clientes críticos
6. **Revocar certificados** inmediatamente cuando un dispositivo se pierde
7. **Monitorizar logs** regularmente
8. **Usar puertos no estándar** si es posible (reduce escaneos)

### Hardening Adicional

**Limitar conexiones por cliente:**
```bash
# En /etc/openvpn/server.conf
duplicate-cn no  # Ya está por defecto
max-clients 50
```

**Firewall más restrictivo:**
```bash
# Solo permitir tráfico específico desde VPN
sudo iptables -A FORWARD -i tun0 -o eth0 -p tcp --dport 443 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -p tcp --dport 80 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -j DROP
```

**Logs más detallados:**
```bash
# En /etc/openvpn/server.conf
verb 4
log-append /var/log/openvpn/openvpn.log
```

## Características Avanzadas

### Configuración por Cliente (CCD)

Crear archivos en `/etc/openvpn/ccd/` con el nombre del cliente:

```bash
# /etc/openvpn/ccd/cliente1
# Asignar IP fija
ifconfig-push 10.8.0.100 255.255.255.0

# Ruta específica
push "route 192.168.100.0 255.255.255.0"

# DNS específico
push "dhcp-option DNS 8.8.8.8"
```

### Alta Disponibilidad

Para configurar múltiples servidores OpenVPN:

```bash
# En el cliente .ovpn
remote vpn1.ejemplo.com 1194 udp
remote vpn2.ejemplo.com 1194 udp
remote-random  # Conectar a servidor aleatorio
```

### Autenticación de Usuario con PAM

Instalar plugin PAM (no incluido en el script):

```bash
sudo apt install openvpn-auth-pam
```

## Soporte y Contribución

### Reportar Problemas

Si encuentras algún problema:
1. Ejecuta con logs detallados: `sudo bash -x ./openvpn-install.sh`
2. Revisa `/var/log/openvpn/` y `journalctl -u openvpn@server`
3. Verifica requisitos del sistema

### Basado en

Este script está basado y optimizado a partir de:
- [angristan/openvpn-install](https://github.com/angristan/openvpn-install)

### Licencia

GPL-3.0 - Ver archivo LICENSE para detalles

## Changelog

### v1.0.0
- Instalación automatizada completa
- Soporte IPv6
- Múltiples opciones de DNS
- Gestión de certificados (crear/revocar)
- Configuración de firewall automática
- Cifrado moderno por defecto (ECDSA + AES-GCM)
- Validación de entrada mejorada
- Sistema de logging con colores
- Documentación completa

---

**Autor**: Basado en el trabajo de Angristan  
**Última actualización**: Diciembre 2025