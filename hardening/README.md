# hardening — endurecimiento básico de servidores Linux

Scripts para aplicar una base de seguridad razonable en servidores Debian/Ubuntu.
Todos usan variables/placeholders; **revisa y ajusta antes de ejecutar**.

| Script | Qué hace |
|--------|----------|
| `setup-sysctl.sh` | Límites del kernel (inotify, somaxconn, vm.max_map_count) |
| `setup-firewall.sh` | Reglas UFW base: deny entrante, SSH solo desde redes de confianza, ejemplos comentados |
| `security-hardening.sh` | Fail2ban + UFW + rkhunter + unattended-upgrades + hardening SSH + escaneo diario |

## Uso

```bash
# Revisa SIEMPRE el script antes de ejecutarlo con sudo.
sudo SSH_USER=miusuario ALERT_EMAIL=yo@dominio.com LAN_CIDR=192.168.1.0/24 \
     bash security-hardening.sh
```

## Avisos

- `security-hardening.sh` deja `PasswordAuthentication yes`. Cuando tengas tus claves
  SSH copiadas y verificadas, cámbialo a `no` y reinicia `sshd`.
- Ajusta `LAN_CIDR`/`VPN_CIDR` a tus redes reales; reglas demasiado abiertas reducen
  la protección.
- Haz pruebas en un entorno no productivo antes de aplicarlo en un servidor real.
