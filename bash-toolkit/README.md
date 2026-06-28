# bash-toolkit — librerías reutilizables para scripts Bash

Dos librerías para escribir scripts de shell **robustos** y consistentes, pensadas para
hacer `source` desde tus propios scripts. Sin dependencias salvo utilidades estándar
(`curl`, `jq` opcional, `nc` opcional).

| Fichero | Qué aporta |
|---------|-----------|
| [`lib/bash-template.sh`](lib/bash-template.sh) | Plantilla completa: `set -Eeuo pipefail` + trap con número de línea, logging con niveles/colores/syslog, validación de dependencias/args/ficheros, HTTP con reintentos, manejo de archivos, parsing JSON, temporales con limpieza, barras de progreso y una plantilla de `main`. |
| [`lib/funciones.sh`](lib/funciones.sh) | Funciones mínimas para *checks* de monitorización: `log`, `statusToText`, `nagiosFormat` (salida Nagios/Icinga) y `check_tcp` (prueba TCP host/puerto). |

## Uso

```bash
# Como librería en tu script
source "/ruta/bash-toolkit/lib/funciones.sh"
export SCRIPT_LOG="/var/log/miscripts/mi_check.log"
export TCP_HOST="vpn.example.local"
export TCP_PORT=443

log INFO "Comprobando conectividad..."
if check_tcp; then
    nagiosFormat "$OK" "Servicio accesible" "tcp_connect=1"
else
    nagiosFormat "$CRITICAL" "Servicio inaccesible" "tcp_connect=0"
fi
```

```bash
# Reutilizar utilidades de la plantilla
source "/ruta/bash-toolkit/lib/bash-template.sh"
init_log "/tmp/demo.log" 0
check_dependencies curl jq || exit 1
http_request "https://httpbin.org/get" GET resp.json 3 10 || die "HTTP fallo"
```

## Pruebas

```bash
make test     # comprueba log y statusToText
make lint     # shellcheck (si está instalado)
```

## Notas

- Todo está parametrizado por variables de entorno (`LOG_FILE`/`SCRIPT_LOG`, `DEBUG`,
  `COLOR`, `SYSLOG`, `CONNECTION_TIMEOUT`): nada de rutas ni hosts fijos.
- `bash-template.sh` usa `set -Eeuo pipefail`; revisa los `trap` si lo integras en
  scripts que ya gestionan errores.
