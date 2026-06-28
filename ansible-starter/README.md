# Ansible - Automatización de Infraestructura

Este directorio contiene la configuración de Ansible para el proyecto ansible-starter.

This directory contains the Ansible configuration for the ansible-starter project.

## Estructura / Structure

```
ansible/
├── ansible.cfg              # Configuración de Ansible
├── playbooks/               # Playbooks de Ansible
│   ├── site.yml            # Playbook principal
│   ├── deploy.yml          # Playbook de despliegue
│   └── maintenance.yml     # Playbook de mantenimiento
├── roles/                   # Roles de Ansible
│   ├── common/             # Rol común para todos los servidores
│   ├── webserver/          # Rol para servidores web
│   └── database/           # Rol para servidores de base de datos
├── inventory/               # Inventarios de hosts
│   ├── production          # Inventario de producción
│   ├── staging             # Inventario de staging
│   ├── development         # Inventario de desarrollo
│   ├── group_vars/         # Variables por grupo
│   │   ├── all.yml         # Variables para todos los grupos
│   │   ├── webservers.yml  # Variables para servidores web
│   │   └── databases.yml   # Variables para bases de datos
│   └── host_vars/          # Variables por host individual
├── templates/               # Plantillas Jinja2
├── files/                   # Archivos estáticos a copiar
└── vars/                    # Variables adicionales
```

## Configuración Inicial / Initial Setup

### 1. Instalación de Ansible / Installing Ansible
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install ansible

# CentOS/RHEL
sudo yum install ansible

# macOS
brew install ansible

# Python pip
pip install ansible
```

### 2. Verificar Instalación / Verify Installation
```bash
ansible --version
```

### 3. Configurar SSH Keys / Configure SSH Keys
```bash
# Generar clave SSH (si no existe)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copiar clave al servidor remoto
ssh-copy-id usuario@servidor
```

## Uso Básico / Basic Usage

### Ejecutar un Playbook / Run a Playbook
```bash
# Ejecutar playbook principal
ansible-playbook -i inventory/production playbooks/site.yml

# Ejecutar con límite a hosts específicos
ansible-playbook -i inventory/production playbooks/deploy.yml --limit webservers

# Modo dry-run (no hace cambios)
ansible-playbook -i inventory/production playbooks/site.yml --check

# Modo verbose para debug
ansible-playbook -i inventory/production playbooks/site.yml -vvv
```

### Comandos Ad-hoc / Ad-hoc Commands
```bash
# Ping a todos los hosts
ansible all -i inventory/production -m ping

# Verificar espacio en disco
ansible all -i inventory/production -m shell -a "df -h"

# Reiniciar un servicio
ansible webservers -i inventory/production -m service -a "name=nginx state=restarted"

# Copiar un archivo
ansible all -i inventory/production -m copy -a "src=/local/file dest=/remote/file"
```

### Verificar Sintaxis / Check Syntax
```bash
# Verificar sintaxis de un playbook
ansible-playbook playbooks/site.yml --syntax-check

# Listar hosts que se verían afectados
ansible-playbook -i inventory/production playbooks/site.yml --list-hosts

# Listar tareas que se ejecutarían
ansible-playbook -i inventory/production playbooks/site.yml --list-tasks
```

## Inventarios / Inventories

### Formato INI
```ini
[webservers]
web1.example.com
web2.example.com

[databases]
db1.example.com

[all:vars]
ansible_user=admin
ansible_python_interpreter=/usr/bin/python3
```

### Formato YAML
```yaml
all:
  children:
    webservers:
      hosts:
        web1.example.com:
        web2.example.com:
    databases:
      hosts:
        db1.example.com:
  vars:
    ansible_user: admin
    ansible_python_interpreter: /usr/bin/python3
```

## Buenas Prácticas / Best Practices

### Seguridad / Security
- **NUNCA** almacenar contraseñas en texto plano
- Usar **Ansible Vault** para datos sensibles
- Mantener claves SSH seguras y rotarlas regularmente
- Usar `no_log: true` para tareas con datos sensibles

### Organización / Organization
- Usar roles para modularizar la configuración
- Mantener playbooks simples y enfocados
- Documentar todas las variables
- Usar nombres descriptivos para tareas

### Variables / Variables
- Definir variables en el nivel apropiado
- Usar `group_vars` para configuración compartida
- Usar `host_vars` para configuración específica
- Evitar hardcodear valores

### Testing
- Siempre usar `--check` primero
- Probar en desarrollo antes de producción
- Usar `--diff` para ver cambios
- Mantener un inventario de desarrollo

## Ansible Vault

### Encriptar Datos / Encrypt Data
```bash
# Crear archivo encriptado
ansible-vault create vars/secrets.yml

# Encriptar archivo existente
ansible-vault encrypt vars/secrets.yml

# Editar archivo encriptado
ansible-vault edit vars/secrets.yml

# Desencriptar archivo
ansible-vault decrypt vars/secrets.yml

# Ver contenido sin desencriptar
ansible-vault view vars/secrets.yml
```

### Usar Vault en Playbooks / Use Vault in Playbooks
```bash
# Ejecutar playbook con vault
ansible-playbook -i inventory/production playbooks/site.yml --ask-vault-pass

# Usar archivo de contraseña
ansible-playbook -i inventory/production playbooks/site.yml --vault-password-file ~/.vault_pass
```

## Estructura de un Rol / Role Structure

```
roles/nombre_rol/
├── tasks/           # Tareas principales
│   └── main.yml
├── handlers/        # Handlers (acciones trigger)
│   └── main.yml
├── templates/       # Plantillas Jinja2
│   └── config.j2
├── files/           # Archivos estáticos
├── vars/            # Variables del rol
│   └── main.yml
├── defaults/        # Variables por defecto
│   └── main.yml
├── meta/            # Metadatos y dependencias
│   └── main.yml
└── README.md        # Documentación del rol
```

## Crear un Nuevo Rol / Create a New Role

```bash
# Crear estructura de rol
ansible-galaxy init roles/nombre_rol

# Instalar rol desde Ansible Galaxy
ansible-galaxy install usuario.nombre_rol

# Instalar desde requirements.yml
ansible-galaxy install -r requirements.yml
```

## Variables Comunes / Common Variables

### Precedencia de Variables (menor a mayor) / Variable Precedence (lowest to highest)
1. role defaults (`defaults/main.yml`)
2. inventory file or script group vars
3. inventory `group_vars/all`
4. playbook `group_vars/all`
5. inventory `group_vars/*`
6. playbook `group_vars/*`
7. inventory file or script host vars
8. inventory `host_vars/*`
9. playbook `host_vars/*`
10. host facts
11. play vars
12. play vars_prompt
13. play vars_files
14. role vars (`vars/main.yml`)
15. block vars
16. task vars
17. extra vars (`-e` en línea de comandos)

## Solución de Problemas / Troubleshooting

### Problemas Comunes / Common Issues

#### Conexión SSH falla
```bash
# Verificar conectividad
ansible all -i inventory/production -m ping -vvv

# Usar usuario y puerto específicos
ansible all -i inventory/production -m ping -u usuario -k --ask-pass
```

#### Permisos insuficientes
```bash
# Usar sudo
ansible-playbook -i inventory/production playbooks/site.yml -b --ask-become-pass

# Especificar método de privilegios
ansible-playbook -i inventory/production playbooks/site.yml -b --become-method=sudo
```

#### Python no encontrado
```bash
# Especificar intérprete de Python
ansible all -i inventory/production -m ping -e "ansible_python_interpreter=/usr/bin/python3"
```

## Recursos / Resources

### Documentación Oficial / Official Documentation
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/)
- [Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

### Módulos Útiles / Useful Modules
- `apt/yum/dnf` - Gestión de paquetes
- `service/systemd` - Gestión de servicios
- `copy/template` - Gestión de archivos
- `user/group` - Gestión de usuarios
- `git` - Operaciones con Git
- `docker_container` - Gestión de contenedores
- `shell/command` - Ejecución de comandos

---

*Última Actualización: 2025-11-25*
*Versión: 1.0.0*
