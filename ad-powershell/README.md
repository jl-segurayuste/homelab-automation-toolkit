# ad-powershell — administración segura de usuarios y grupos en Active Directory

Funciones PowerShell para gestionar usuarios y grupos de Active Directory con
**atributos POSIX (RFC2307)**, pensadas para entornos AD integrados con Linux/Unix.
Requieren el módulo `ActiveDirectory` (RSAT) y PowerShell 5.1+.

Enfoque de ciberseguridad: contraseñas aleatorias robustas, validación de entradas,
operaciones idempotentes y retorno estructurado (apto para automatización/Ansible).

| Script | Función |
|--------|---------|
| `Generate-RandomPassword.ps1` | Genera contraseñas aleatorias que cumplen la política de AD (4 clases de caracteres, Fisher-Yates) y que **no contienen** el nombre de usuario |
| `Get-NextAvailableUsername.ps1` | Calcula el siguiente `SamAccountName` libre siguiendo una nomenclatura (sufijo numérico 01-99 y luego a-z) |
| `ad_user_operations.ps1` | Librería de funciones de usuario: alta con atributos POSIX (UID/GID/home/shell/gecos), pertenencia a grupos, etc. |
| `ad_group_operations.ps1` | Librería de funciones de grupo: creación con GID seguro, gestión de membresía |
| `Remove-ADUserFromGroups.ps1` | Quita un usuario de uno o varios grupos (útil en bajas/offboarding); tolerante a errores y con reporte |

## Uso

```powershell
# Importar (dot-sourcing) las librerías
. .\ad_user_operations.ps1
. .\ad_group_operations.ps1
. .\Generate-RandomPassword.ps1

# Contraseña robusta para un alta
$r = Generate-RandomPassword -Length 16 -Username "jdoe"
if ($r.success) { $pwd = ConvertTo-SecureString $r.password -AsPlainText -Force }

# Alta de usuario con atributos POSIX (ejemplo; usa tu OU real)
New-ADUserWithPosix -UserName "jdoe" -UID 75434 -GID 10625 `
  -UnixHomeDirectory "/home/jdoe" -LoginShell "/bin/bash" `
  -OrganizationalUnit "OU=usuarios,DC=example,DC=lan" -Password $pwd
```

## Notas de seguridad

- No incrustes contraseñas: genera con `Generate-RandomPassword` o pásalas como `SecureString`.
- Ejecuta con una cuenta con los **mínimos privilegios** necesarios sobre la OU objetivo.
- Las funciones devuelven objetos/JSON: revisa `success`/`errors` antes de continuar.
- Audita periódicamente la pertenencia a grupos privilegiados (Domain/Enterprise Admins).
