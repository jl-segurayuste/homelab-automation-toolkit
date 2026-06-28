# Buenas prácticas y errores comunes — Ansible y Bash

Guía breve de patrones recomendados (y antipatrones que evitar) al escribir automatizaciones,
con snippets mínimos listos para copiar.

## Principios

- **Idempotencia**: la misma ejecución dos veces no debe cambiar nada la segunda vez. Usa
  `creates`/`unless` en `command`/`shell`, y módulos con `checksum` en lugar de copiar a ciegas.
- **Handlers + `notify`**: reinicia servicios **solo si la configuración cambió**, no siempre.
- **Condiciona por facts** (`when:`) en vez de asumir el entorno.
- **Valida sin cambiar**: `check_mode`, `--check`, `changed_when: false`, `assert`.
- **Bash robusto**: `set -euo pipefail`, comillas en todas las variables, manejo de errores.

## Errores frecuentes

- Falta de idempotencia (`command`/`shell` sin `creates`/`unless`, `copy` sin checksum).
- Variables sin `default` y templating Jinja2 mal cerrado.
- Bash sin comillas -> globbing y *word splitting* inesperados.
- Reiniciar servicios en cada ejecución en lugar de usar `notify`.

## Snippets

### Bash seguro

```bash
set -euo pipefail
IFS=$'\n\t'
log(){ printf '%s %s\n' "$(date '+%F %T')" "$*"; }
trap 'log ERROR; exit 1' ERR
```

### Copiar config y reiniciar solo si cambió

```yaml
- name: Deploy nginx conf
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
  notify: Restart nginx

- name: Ensure nginx running
  ansible.builtin.service:
    name: nginx
    state: started

handlers:
  - name: Restart nginx
    ansible.builtin.service:
      name: nginx
      state: restarted
```

### Condicionar por facts (solo RedHat 7 y >8 GB de RAM)

```yaml
- hosts: all
  gather_facts: true
  tasks:
    - name: Aplicar solo en RedHat 7 con mas de 8GB de RAM
      ansible.builtin.debug:
        msg: "aplico"
      when:
        - ansible_facts['os_family'] == 'RedHat'
        - ansible_facts['distribution_major_version'] | int == 7
        - ansible_facts['memtotal_mb'] | int > 8192
```

### Validación sin cambios

```yaml
- name: Validar sintaxis de nginx
  ansible.builtin.command: nginx -t
  changed_when: false
```

## Mini-casos

- **Plantilla rota**: ejecuta con `-e 'clave=valor'`, usa `--check` y revisa
  `var | default('')` para variables que pueden no estar definidas.
- **Play lento**: prueba `strategy: free`, `async`/`poll`, `become` solo donde haga falta y
  limita los facts (`gather_subset: min`).

## Checklist rápida

- [ ] Aplica idempotencia y handlers
- [ ] Usa facts y `when`/`failed_when`/`changed_when`
- [ ] Bash con `set -euo pipefail` y comillas correctas
- [ ] Valida con `--check`/`changed_when: false` antes de aplicar
