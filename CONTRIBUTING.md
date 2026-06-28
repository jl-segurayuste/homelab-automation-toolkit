# Guía de contribución

Gracias por tu interés. Este repositorio reúne automatizaciones genéricas y
reutilizables para sysadmin/homelab. Para mantenerlo seguro y útil, sigue estas pautas.

## Reglas obligatorias (las verifican los hooks)

1. **Sin secretos.** Nada de contraseñas, tokens, claves privadas o cadenas de conexión
   reales. Usa variables de entorno o ficheros `*.example` con placeholders
   (`<TU_VALOR>`, `tu-email@ejemplo.com`).
2. **Sin nombres propios.** Ni de personas, ni de empresas, ni de clientes, ni dominios o
   hostnames internos. Todo debe ser genérico (`example.com`, `miusuario`, `192.168.1.0/24`).
3. **Sin iconos/emojis en scripts** (cualquier lenguaje: `.sh`, `.py`, `.php`, `.yml`…).
   Rompen encodings, shebangs y portabilidad. En la salida usa texto plano: `[OK]`, `[ERROR]`.

> En documentación Markdown (`.md`) los emojis sí están permitidos.

## Antes de enviar cambios

```bash
# 1. Activa los hooks (una sola vez tras clonar)
git config core.hooksPath .githooks

# 2. Pasa el escaneo completo: debe terminar en "limpio, apto para publicar"
bash scripts/security/scan-repo.sh
```

El hook `pre-commit` bloquea automáticamente cualquier commit con secretos, términos
vetados o iconos en scripts. Si necesitas vetar nombres concretos en tu copia local,
copia `scripts/security/blacklist.example.txt` a `blacklist.local.txt` (gitignored).

## Cómo añadir una automatización nueva

1. Crea una carpeta por tema en la raíz (p. ej. `docker/`, `backup/`, `monitoring/`).
2. Incluye un `README.md` con: qué hace, requisitos, uso y avisos de seguridad.
3. Parametriza todo lo específico (rutas, IPs, usuarios) con variables al inicio del script.
4. Scripts ejecutables con shebang (`#!/usr/bin/env bash`) y `set -e` cuando aplique.
5. Ejecuta el escaneo y abre el Pull Request.

## Estilo

- Mensajes de commit: `tipo(ámbito): descripción` (p. ej. `feat(docker): ...`).
- Prefiere scripts idempotentes y con mensajes claros de progreso/errores.
- Comenta el "por qué", no el "qué" obvio.

## Licencia

Al contribuir, aceptas que tu aportación se publique bajo la licencia [MIT](LICENSE).
