# Rol Common / Common Role

Rol de Ansible para configuración común de todos los servidores.

Ansible role for common configuration of all servers.

## Descripción / Description

Este rol configura aspectos básicos y comunes para todos los servidores del proyecto ansible-starter:
- Instalación de paquetes comunes
- Configuración de timezone
- Configuración de DNS
- Hardening básico de SSH
- Configuración de firewall

This role configures basic and common aspects for all ansible-starter project servers:
- Installation of common packages
- Timezone configuration
- DNS configuration
- Basic SSH hardening
- Firewall configuration

## Requisitos / Requirements

- Ansible >= 2.9
- Sistema operativo: Ubuntu 20.04+ o Debian 11+

## Variables

Ver `defaults/main.yml` y `group_vars/all.yml` para todas las variables disponibles.

See `defaults/main.yml` and `group_vars/all.yml` for all available variables.

### Variables Principales / Main Variables

- `common_packages`: Lista de paquetes a instalar
- `timezone`: Zona horaria del sistema
- `dns_servers`: Lista de servidores DNS
- `disable_root_login`: Deshabilitar login de root
- `allow_password_authentication`: Permitir autenticación por contraseña

## Ejemplo de Uso / Usage Example

```yaml
- hosts: all
  roles:
    - common
```

## Licencia / License

MIT
