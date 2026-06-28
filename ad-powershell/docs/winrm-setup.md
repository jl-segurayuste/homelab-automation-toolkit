# Conexión a Windows con Ansible (WinRM)

Guía mínima para ejecutar los módulos de [`../library`](../library) (y cualquier módulo
`ansible.windows` / `community.windows`) contra hosts Windows. Windows no usa SSH por
defecto, sino **WinRM**.

## 1. Preparar el host Windows

WinRM escucha en **5985 (HTTP)** y **5986 (HTTPS)**. Para laboratorio existe el script
oficial de Ansible que habilita WinRM:

```powershell
# En PowerShell como Administrador, en el host Windows
$url  = "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "$env:temp\ConfigureRemotingForAnsible.ps1"
(New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file)
powershell.exe -ExecutionPolicy ByPass -File $file
```

> En producción **usa HTTPS (5986)** con un certificado válido y evita
> `ConfigureRemotingForAnsible` (habilita HTTP). Considera Kerberos en dominio.

## 2. Inventario

No pongas contraseñas en claro en el inventario. Define las variables comunes y guarda
las credenciales en **Ansible Vault** o pásalas con `-e`.

```ini
[windows]
win-server01 ansible_host=192.168.1.100

[windows:vars]
ansible_connection=winrm
ansible_user=Administrator
ansible_port=5986
ansible_winrm_transport=credssp
ansible_winrm_server_cert_validation=validate
# ansible_password -> en vault, NUNCA aqui en claro
```

Para empezar en laboratorio (menos seguro): `ansible_port=5985`,
`ansible_winrm_transport=ntlm`, `ansible_winrm_server_cert_validation=ignore`.

Orden de preferencia del transporte: **kerberos** (dominio) > **credssp** > ntlm.

## 3. Dependencias en el controller (Linux)

```bash
pip install "pywinrm"
pip install "pywinrm[credssp]"   # si usas CredSSP
# Para Kerberos: pip install "pywinrm[kerberos]" + paquetes krb5 del sistema
```

## 4. Comprobar conectividad

```bash
ansible -i inventory.ini windows -m ansible.windows.win_ping
```

## 5. Usar los módulos de esta carpeta

Con la conexión lista, los módulos de [`../library`](../library) se usan como cualquier
módulo (ver [`../examples/alta_usuario.yml`](../examples/alta_usuario.yml)):

```yaml
- hosts: windows
  tasks:
    - name: Alta de usuario AD con POSIX
      win_ad_user:
        name: jdoe
        uid_number: 75434
        gid_number: 10625
        unix_home_directory: /home/jdoe
        login_shell: /bin/bash
        gecos: Usuario de ejemplo
        organizational_unit: "OU=usuarios,DC=example,DC=lan"
        generate_password: true
      no_log: true
```

## Seguridad

- Credenciales **siempre** en Vault o `-e`; nunca en el inventario ni en el repo.
- Prefiere **HTTPS (5986)** y `server_cert_validation=validate`.
- Usa una cuenta con los **mínimos privilegios** necesarios sobre la OU/host objetivo.
- `no_log: true` en tareas que manejen contraseñas.
