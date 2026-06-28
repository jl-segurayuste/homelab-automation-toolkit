# network-tools — utilidades de diagnóstico de red

Herramientas de diagnóstico y gestión de conectividad, sin dependencias de infraestructura
concreta (todo por parámetros).

| Script | Función |
|--------|---------|
| [`ip-diagnostics.py`](ip-diagnostics.py) | Diagnóstico de IPs: ping, prueba de puertos comunes, escaneo `nmap -F`, comprobación HTTP/HTTPS, traceroute y whois. Compara escaneos, genera listas de exclusión de IPs que no responden y resúmenes. |

## Uso

```bash
python3 ip-diagnostics.py            # menú interactivo
# o invoca las funciones desde tu propio flujo
```

## Notas

- Requiere las utilidades del sistema que uses: `ping`, `nc`, `nmap`, `curl`, `traceroute`,
  `whois`. Las funciones degradan con elegancia si falta alguna.
- Los directorios de informes y los ficheros de IPs se pasan como parámetros: no hay rutas,
  hosts ni rangos fijos en el código.
- Pensado para diagnóstico **autorizado** sobre tu propia red/inventario.
