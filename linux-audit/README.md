# linux-audit — auditoría de seguridad de Linux

Herramientas de **solo lectura** para evaluar la postura de seguridad de un host Linux
y para activar trazabilidad con `auditd`. Orientado a ciberseguridad (estilo CIS).

| Recurso | Qué hace |
|---------|----------|
| `security-audit.sh` | Auditoría rápida: cuentas UID 0 / contraseñas vacías, hardening SSH, firewall, SUID/SGID y world-writable, puertos a la escucha, sysctl de red/kernel y actualizaciones de seguridad pendientes |
| `auditd-baseline.rules` | Conjunto base de reglas de `auditd` (identidad, SSH/PAM, sudo, cambios de hora, módulos del kernel, escaladas de privilegio) |

## Uso

```bash
# Auditoría (no modifica nada)
sudo bash security-audit.sh

# Trazabilidad con auditd
sudo apt-get install -y auditd        # o: dnf install audit
sudo cp auditd-baseline.rules /etc/audit/rules.d/99-baseline.rules
sudo augenrules --load
sudo systemctl enable --now auditd
# Consultar eventos por clave:
sudo ausearch -k identity
```

## Notas

- `security-audit.sh` solo informa; **no aplica cambios**. Para endurecer, ver
  [`../hardening`](../hardening).
- `auditd-baseline.rules` termina con `-e 2` (reglas inmutables hasta reiniciar) y puede
  generar **mucho volumen de log**: ajústalo a tu entorno y vigila el espacio.
- Complementa esto con un SIEM/centralización de logs para correlación y alertas.
