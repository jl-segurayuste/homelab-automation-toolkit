# incident-response — triaje y caza de amenazas (Linux)

Herramientas **defensivas y de solo lectura** para responder ante un posible
compromiso: recolección de estado volátil y búsqueda de mecanismos de persistencia.

| Script | Qué hace |
|--------|----------|
| `ir-triage.sh` | Recolecta una foto del sistema (procesos, red, persistencia, usuarios, ficheros recientes, logs) en un directorio con marca de tiempo |
| `detect-persistence.sh` | Busca persistencia típica: cron/systemd sospechosos, `rc.local`/perfiles de shell, `LD_PRELOAD`, claves SSH, UID 0 extra, SUID y procesos en rutas temporales |

## Uso

```bash
sudo bash ir-triage.sh /var/tmp/ir-caso-001
sudo bash detect-persistence.sh
```

## Notas (manejo de incidentes)

- **No modifican el host**: recolectan/inspeccionan. Aun así, en un incidente real
  preserva la **cadena de custodia** (hashes, copias, trabajar sobre la copia).
- Si confirmas compromiso: **aísla** el host de la red antes que apagarlo (no perder
  la memoria volátil), notifica según tu plan de respuesta y conserva evidencias.
- Estas herramientas **marcan cosas a revisar**; no sustituyen a un EDR/forense.
- Compleméntalas con `linux-audit/` (postura) y `monitoring/` (detección continua).
