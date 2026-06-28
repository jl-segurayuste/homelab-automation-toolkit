# ai-stack — utilidades para un stack de IA local (Ollama + Open WebUI)

Scripts de **solo lectura** para operar y vigilar un servidor de IA local basado en
[Ollama](https://ollama.com) y [Open WebUI](https://openwebui.com). Sin datos de
infraestructura: todo por `localhost`/variables.

| Script | Qué hace |
|--------|----------|
| `verify-ai-stack.sh` | Verificación puntual: servicio Ollama, API, modelos, contenedor Open WebUI, conectividad, firewall y recursos |
| `ai-dashboard.sh` | Panel en vivo (`watch`): acceso, servicios, modelo cargado, recursos, conexiones activas y batería |
| `ai-diagnose.sh` | Diagnóstico de rendimiento puntual (CPU/RAM/temperatura/frecuencia) + test rápido de inferencia |

## Uso

```bash
bash verify-ai-stack.sh                 # comprobacion rapida
bash ai-dashboard.sh                    # panel en vivo (Ctrl+C para salir)
TEST_MODEL=llama3.2 bash ai-diagnose.sh # diagnostico + test del modelo indicado
```

Variables útiles: `OLLAMA_URL` (def. `http://localhost:11434`), `WEBUI_PORT` (def. `3000`),
`WEBUI_CONTAINER` (def. `open-webui`), `INTERVAL` (refresco del dashboard), `TEST_MODEL`.

## Notas

- `ai-dashboard.sh` y algunas comprobaciones usan `sudo ss`/`docker`: ejecútalos con los
  permisos adecuados.
- Requieren `jq` para leer la API de Ollama y `lm-sensors` para la temperatura (opcional).
- Son utilidades de observación; no modifican el sistema.
