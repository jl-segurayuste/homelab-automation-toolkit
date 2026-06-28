# Rol Database / Database Role

Rol de Ansible para configuración de servidores de base de datos PostgreSQL.

Ansible role for PostgreSQL database server configuration.

## Descripción / Description

Este rol instala y configura PostgreSQL para el proyecto ansible-starter.

This role installs and configures PostgreSQL for the ansible-starter project.

## Requisitos / Requirements

- Ansible >= 2.9
- Sistema operativo: Ubuntu 20.04+ o Debian 11+
- Rol `common` aplicado previamente

## Variables

Ver `group_vars/databases.yml` para todas las variables disponibles.

See `group_vars/databases.yml` for all available variables.

## Seguridad / Security

**IMPORTANTE:** Las contraseñas deben almacenarse en Ansible Vault.

**IMPORTANT:** Passwords should be stored in Ansible Vault.

```bash
ansible-vault create group_vars/databases/vault.yml
```

## Ejemplo de Uso / Usage Example

```yaml
- hosts: databases
  roles:
    - database
```

## Licencia / License

MIT
