# docker — administración y hardening de Docker con Ansible

Playbooks para instalar, **endurecer** y gestionar Docker, más una auditoría de
seguridad rápida. Orientado a ciberseguridad (estilo CIS Docker Benchmark).

| Recurso | Qué hace |
|---------|----------|
| `playbooks/install-docker.yml` | Instala Docker CE desde el repo oficial (clave GPG verificada) |
| `playbooks/harden-docker.yml` | Despliega un `daemon.json` endurecido (`no-new-privileges`, `icc=false`, `live-restore`, límites de log) |
| `playbooks/manage-containers.yml` | Despliega contenedores de forma declarativa con opciones seguras por defecto (`read_only`, `cap_drop: ALL`, bind a `127.0.0.1`) |
| `templates/daemon.json.j2` | Plantilla del daemon endurecido (opción `userns-remap`) |
| `scripts/docker-security-audit.sh` | Auditoría de solo lectura: privilegiados, socket montado, contenedores root, puertos en `0.0.0.0` |

## Uso

```bash
ansible-galaxy collection install community.docker
ansible-playbook -i inventory.ini playbooks/install-docker.yml
ansible-playbook -i inventory.ini playbooks/harden-docker.yml
bash docker/scripts/docker-security-audit.sh
```

## Principios de seguridad aplicados

- **Sin privilegios extra**: `no-new-privileges` en daemon y contenedores.
- **Menos superficie de red**: `icc=false`; publica en `127.0.0.1`, no en `0.0.0.0`.
- **Menos capacidades**: `cap_drop: [ALL]` y añade solo las imprescindibles.
- **Sistema de ficheros de solo lectura** cuando sea posible (`read_only: true`).
- **No montar `/var/run/docker.sock`** en contenedores (equivale a root del host).
- **Usuario no-root** dentro de la imagen (`USER` en el Dockerfile).
- Considera **`userns-remap`** y/o el modo **rootless** para aislar del host.
