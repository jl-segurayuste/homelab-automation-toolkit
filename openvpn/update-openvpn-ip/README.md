# OpenVPN Dynamic IP Monitor

Script para monitorear y actualizar automáticamente la IP pública en la configuración de OpenVPN cuando cambia.

## Descripción

Este conjunto de scripts monitorea periódicamente la IP pública del servidor y actualiza automáticamente el archivo `server.conf` de OpenVPN cuando detecta un cambio. Esto es útil para servidores OpenVPN con IP pública dinámica.

## Requisitos

- Servidor Linux con systemd
- OpenVPN instalado y configurado
- curl instalado
- Permisos de root para la instalación

## Instalación

1. **Descargar los scripts:**

```bash
# Descargar los tres scripts
wget https://tudominio.com/update-openvpn-ip.sh
wget https://tudominio.com/install-ip-monitor.sh
wget https://tudominio.com/force-update-ip.sh

# Dar permisos de ejecución
chmod +x *.sh