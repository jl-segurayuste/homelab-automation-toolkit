# homelab-automation-toolkit

Colección de scripts y plantillas de automatización para administración de sistemas,
redes y homelab. Pensado como ayuda para la comunidad: utilidades genéricas,
reutilizables y sin datos sensibles.

> Todo el contenido está anonimizado. No incluye credenciales, nombres propios,
> nombres de empresas ni inventarios reales. Los valores específicos se sustituyen
> por plantillas (`.env.example`, placeholders `<TU_VALOR>`).

## Contenido

| Sección | Descripción | Estado |
|---------|-------------|--------|
| `openvpn/` | Herramientas de gestión de OpenVPN: instalación, diagnóstico, backup, monitorización, rotación de IP pública, checklist de seguridad | Pendiente de migrar |
| `ansible-starter/` | Plantilla genérica de proyecto Ansible (roles common/database/webserver) | Pendiente de migrar |
| `web-form/` | Ejemplo de formulario web PHP con conexión a BD (didáctico) | Pendiente de migrar |
| `scripts/` | Utilidades varias de sysadmin | Pendiente de migrar |

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

## Licencia

MIT — ver [LICENSE](LICENSE).
