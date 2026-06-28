# ansible-security — baseline de seguridad para Linux con Ansible

Colección de **roles idempotentes** para aplicar una base de seguridad razonable en
servidores Debian/Ubuntu, orquestados por `site.yml`. Complementa los scripts de
[`../hardening`](../hardening) y [`../linux-audit`](../linux-audit) con un enfoque
declarativo y reproducible.

## Roles

| Rol | Qué hace |
|-----|----------|
| `sysctl_hardening` | Parámetros de kernel/red de seguridad (rp_filter, syncookies, ASLR, kptr_restrict...) |
| `ssh_hardening` | `sshd` endurecido vía drop-in **validado** (root off, solo claves, algoritmos modernos) |
| `firewall_ufw` | Política `deny` entrante + reglas declarativas con UFW |
| `fail2ban` | Instala y configura fail2ban (jail `sshd`, ignoreip, backend systemd) |
| `auditd` | Despliega reglas base de `auditd` (identidad, sudo, módulos, escaladas) |
| `unattended_upgrades` | Actualizaciones automáticas de seguridad |
| `kerberos_client` | `/etc/krb5.conf` con **solo cifrados AES** para integrarse con el DC |
| `sssd_ad` | Une clientes Linux a Active Directory con **realmd + SSSD**; acceso y `sudo` por grupos de AD |

## Uso

```bash
ansible-galaxy collection install -r requirements.yml
cp inventory.example.ini inventory.ini
ansible-playbook -i inventory.ini site.yml --check        # simulacro
ansible-playbook -i inventory.ini site.yml                # aplicar
ansible-playbook -i inventory.ini site.yml --tags ssh,firewall
```

## Seguridad y precauciones

- **`ssh_hardening` deja `PasswordAuthentication no`**: asegúrate de tener tus claves SSH
  desplegadas y probadas antes, o el acceso por contraseña dejará de funcionar. El drop-in
  se **valida** con `sshd -t` antes de recargar.
- Ejecuta primero con `--check` y por `--tags` en hosts no productivos.
- Ajusta `ufw_rules` y `ssh_allow_users` a tu entorno: una regla demasiado abierta
  reduce la protección.
- `auditd` carga reglas que terminan en `-e 2` (inmutables hasta reinicio) y puede
  generar mucho log: dimensiona el almacenamiento.
- **`sssd_ad` une el equipo al dominio**: requiere `ad_join_password` (cuenta con permiso
  de unión). **Nunca** lo pongas en el repo; pásalo con Ansible Vault o `-e`. La unión es
  idempotente (comprueba `realm list` antes). Ejecuta `kerberos_client` antes en el mismo host.
