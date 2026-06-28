# monitoring — monitorización y alertas

Observabilidad y detección básica, con foco en seguridad.

| Recurso | Qué hace |
|---------|----------|
| `playbooks/install-node-exporter.yml` | Instala Prometheus `node_exporter` como servicio systemd **endurecido**, escuchando solo en `127.0.0.1` |
| `auth-monitor.sh` | Vigila el log de autenticación: fuerza bruta SSH por IP, usuarios inválidos y fallos de `sudo`; notifica por ntfy/webhook |
| `health-alerts.sh` | Chequeo de salud (disco, RAM, servicios systemd y contenedores Docker configurables) con alerta por email |
| `verify-ai-stack.sh` | Verificación de solo lectura de un stack de IA local (Ollama + Open WebUI): servicio, API, modelos, conectividad, firewall y recursos |

## Uso

```bash
# Métricas de sistema (expón con reverse proxy + auth/TLS o por VPN)
ansible-playbook -i inventory.ini playbooks/install-node-exporter.yml

# Detección de fuerza bruta (cron cada 10 min)
sudo THRESHOLD=10 NTFY_URL=https://ntfy.example.com/seguridad bash auth-monitor.sh
```

## Notas de seguridad

- `node_exporter` escucha en **localhost**: nunca lo publiques en `0.0.0.0` sin
  autenticación/TLS delante. Expón métricas por red privada/VPN o reverse proxy.
- `auth-monitor.sh` **no banea**: para bloqueo activo usa `fail2ban`
  (ver [`../hardening`](../hardening)); este script aporta visibilidad/alerta.
- Centraliza logs (Loki/ELK) y define alertas para correlación más allá de un host.
