# Rol Webserver / Webserver Role

Rol de Ansible para configuración de servidores web Nginx.

Ansible role for Nginx web server configuration.

## Descripción / Description

Este rol instala y configura Nginx para el proyecto ansible-starter.

This role installs and configures Nginx for the ansible-starter project.

## Requisitos / Requirements

- Ansible >= 2.9
- Sistema operativo: Ubuntu 20.04+ o Debian 11+
- Rol `common` aplicado previamente

## Variables

Ver `group_vars/webservers.yml` para todas las variables disponibles.

See `group_vars/webservers.yml` for all available variables.

## Ejemplo de Uso / Usage Example

```yaml
- hosts: webservers
  roles:
    - webserver
```

## Licencia / License

MIT
