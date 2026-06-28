# ansible-dc — gestión de usuarios y grupos en un Domain Controller (Samba AD)

Roles y **módulos Ansible propios** para administrar usuarios y grupos de un
Controlador de Dominio Active Directory basado en Samba 4, de forma **idempotente** y
con enfoque de seguridad. Complementa la sección [`kerberos-linux-dc`](../kerberos-linux-dc).

## Módulos propios (`library/`)

| Módulo | Qué hace |
|--------|----------|
| `samba_ad_user` | Crea/elimina/habilita usuarios; soporta `must_change_password`; la contraseña se marca `no_log` |
| `samba_ad_group` | Crea/elimina grupos y **reconcilia** su membresía (`members` + `purge_members`) |

Ambos envuelven `samba-tool`, así que las tareas se ejecutan **en el propio DC**.

## Roles (`roles/`)

| Rol | Qué hace |
|-----|----------|
| `dc_users` | Asegura los usuarios de `dc_users` y su pertenencia a grupos |
| `dc_groups` | Asegura grupos de `dc_groups` y su membresía exacta |
| `dc_security` | Aplica política de contraseñas (`samba-tool domain passwordsettings`) y audita grupos privilegiados |

## Uso

```bash
cp inventory.example.ini inventory.ini
cp group_vars/domain_controllers.example.yml group_vars/domain_controllers.yml
# Cifra las contrasenas:
ansible-vault encrypt_string 'TuPass' --name 'vault_jdoe_password'

ansible-playbook playbooks/manage-dc.yml --ask-vault-pass
```

## Seguridad

- **Nunca** contraseñas en claro: usa Ansible Vault; las tareas de usuario llevan `no_log: true`.
- Aplica el principio de **mínimo privilegio**; `dc_security` lista los miembros de
  `Domain Admins`/`Enterprise Admins`/`Schema Admins` para que los revises.
- Ejecuta primero en modo comprobación: `--check` (los módulos soportan check mode).
- Combínalo con `kerberos-linux-dc/harden-kerberos.sh` (solo cifrados AES) y la
  auditoría de keytabs.
