# homelab-automation-toolkit

Colección de scripts y plantillas de automatización para administración de sistemas,
redes y homelab. Pensado como ayuda para la comunidad: utilidades genéricas,
reutilizables y sin datos sensibles.

> Todo el contenido está anonimizado. No incluye credenciales, nombres propios,
> nombres de empresas ni inventarios reales. Los valores específicos se sustituyen
> por plantillas (`.env.example`, placeholders `<TU_VALOR>`).

## Contenido

| Sección | Descripción |
|---------|-------------|
| `openvpn/` | Herramientas de gestión de OpenVPN: instalación, diagnóstico, backup, monitorización, rotación de IP pública, checklist de seguridad |
| `ansible-starter/` | Plantilla genérica de proyecto Ansible (roles common/database/webserver, inventarios, playbooks) |
| `hardening/` | Endurecimiento básico de servidores Linux (sysctl, UFW, fail2ban, rkhunter, SSH, unattended-upgrades) |
| `maintenance/` | Mantenimiento de servidores: limpieza de containerd/K3s y dumps de bases de datos en Docker |
| `web-form/` | Ejemplo didáctico de formulario web PHP con conexión a BD |

## Normas del repositorio (forzadas por hook pre-commit)

1. **Sin secretos**: ningún token, clave privada o contraseña incrustada.
2. **Sin nombres confidenciales**: copia `scripts/security/blacklist.example.txt` a
   `blacklist.local.txt` (gitignored) y lista ahí los términos a bloquear.
3. **Sin iconos/emojis en scripts** (cualquier lenguaje): rompen encodings y portabilidad.

Antes de publicar o en cualquier momento: `bash scripts/security/scan-repo.sh`.

## Instalación de los hooks (tras clonar)

```bash
git config core.hooksPath .githooks
```

## Contribuir

¿Quieres aportar una automatización? Lee la [guía de contribución](CONTRIBUTING.md).
Reglas clave: sin secretos, sin nombres propios y sin iconos en scripts.

## Licencia

MIT — ver [LICENSE](LICENSE).
