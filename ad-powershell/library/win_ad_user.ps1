#!powershell

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License
# Modulo Ansible: gestiona usuarios de Active Directory con atributos POSIX.

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Modules ActiveDirectory

$spec = @{
    options = @{
        name                      = @{ type = "str"; required = $true }
        state                     = @{ type = "str"; default = "present"; choices = @("present", "absent") }
        uid_number                = @{ type = "int" }
        gid_number                = @{ type = "int" }
        unix_home_directory       = @{ type = "str" }
        login_shell               = @{ type = "str" }
        gecos                     = @{ type = "str" }
        description               = @{ type = "str" }
        organizational_unit       = @{ type = "str" }
        password                  = @{ type = "str"; no_log = $true }
        generate_password         = @{ type = "bool"; default = $false }
        password_length           = @{ type = "int"; default = 15 }
        change_password_at_logon  = @{ type = "bool"; default = $false }
        password_never_expires    = @{ type = "bool"; default = $true }
        update_mode               = @{ type = "str"; default = "safe"; choices = @("safe", "force") }
        groups                    = @{ type = "list"; elements = "str"; default = @() }
        extension_attribute10     = @{ type = "str" }
        upn_suffix                = @{ type = "str" }
    }
    required_if = @(
        , @("state", "present", @("uid_number", "gid_number", "unix_home_directory", "login_shell", "gecos", "organizational_unit"))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name  = $module.Params.name
$state = $module.Params.state
$module.Result.changed = $false
$module.Result.warnings_detail = @()

function Get-ExistingUser {
    param([string]$Identity)
    try {
        return Get-ADUser -Identity $Identity `
            -Properties uidNumber, gidNumber, unixHomeDirectory, loginShell, gecos, description, extensionAttribute10, memberOf `
            -ErrorAction Stop
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        return $null
    }
}

function Get-SecureRandomIndex {
    # Indice aleatorio en [0, Max) con el generador criptografico: Get-Random usa System.Random,
    # que no sirve para contrasenas. Se descartan los valores que no completan un multiplo de Max
    # para que todos los caracteres tengan la misma probabilidad.
    param([int]$Max)
    $rng   = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 4
    $limit = [uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$Max)
    try {
        do {
            $rng.GetBytes($bytes)
            $value = [BitConverter]::ToUInt32($bytes, 0)
        } while ($value -ge $limit)
    }
    finally { $rng.Dispose() }
    return [int]($value % [uint32]$Max)
}

function New-CompliantPassword {
    param([int]$Length, [string]$Username)
    $upper   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lower   = "abcdefghijklmnopqrstuvwxyz"
    $nums    = "0123456789"
    $special = '~!@#$%&*_-+=|()[]:;<>,.'
    for ($attempt = 1; $attempt -le 50; $attempt++) {
        $chars = @()
        $chars += $upper[(Get-SecureRandomIndex -Max $upper.Length)]
        $chars += $lower[(Get-SecureRandomIndex -Max $lower.Length)]
        $chars += $nums[(Get-SecureRandomIndex -Max $nums.Length)]
        $chars += $special[(Get-SecureRandomIndex -Max $special.Length)]
        $all = $upper + $lower + $nums + $special
        for ($i = $chars.Count; $i -lt $Length; $i++) {
            $chars += $all[(Get-SecureRandomIndex -Max $all.Length)]
        }
        for ($i = $chars.Count - 1; $i -gt 0; $i--) {
            $j = Get-SecureRandomIndex -Max ($i + 1)
            $t = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $t
        }
        $candidate = -join $chars
        $ok = ($candidate -cmatch '[a-z]') -and ($candidate -cmatch '[A-Z]') -and `
              ($candidate -match '\d') -and ($candidate -match '[^0-9a-zA-Z]') -and `
              ($candidate.Length -ge 8) -and ($candidate -notmatch [regex]::Escape($Username))
        if ($ok) { return $candidate }
    }
    $module.FailJson("No se pudo generar una contrasena valida tras 50 intentos")
}

$existing = Get-ExistingUser -Identity $name

# -----------------------------------------------------------------------------
# state: absent
# -----------------------------------------------------------------------------
if ($state -eq "absent") {
    if ($existing) {
        if (-not $module.CheckMode) {
            Remove-ADUser -Identity $name -Confirm:$false -ErrorAction Stop
        }
        $module.Result.changed = $true
        $module.Result.msg = "Usuario $name eliminado"
    }
    else {
        $module.Result.msg = "El usuario $name no existe"
    }
    $module.ExitJson()
}

# -----------------------------------------------------------------------------
# state: present
# -----------------------------------------------------------------------------
$uid = $module.Params.uid_number
$gid = $module.Params.gid_number

if (-not $existing) {
    # Comprobar conflicto de UID con otro usuario.
    $uidConflict = Get-ADUser -Filter "uidNumber -eq $uid" -Properties uidNumber, SamAccountName -ErrorAction Stop
    if ($uidConflict) {
        $module.FailJson("El UID $uid ya esta en uso por el usuario $($uidConflict.SamAccountName)")
    }

    # Resolver contrasena (proporcionada o generada).
    $plainPassword = $module.Params.password
    if (-not $plainPassword -and $module.Params.generate_password) {
        $plainPassword = New-CompliantPassword -Length $module.Params.password_length -Username $name
        $module.Result.generated_password = $plainPassword
        $module.Result.warnings_detail += "Se genero una contrasena aleatoria: va en generated_password, pon no_log: true en la tarea"
    }

    $posix = @{
        uidNumber         = $uid
        gidNumber         = $gid
        unixHomeDirectory = $module.Params.unix_home_directory
        loginShell        = $module.Params.login_shell
        gecos             = $module.Params.gecos
    }
    if ($module.Params.extension_attribute10) {
        $posix.extensionAttribute10 = $module.Params.extension_attribute10
    }

    $suffix = if ($module.Params.upn_suffix) { $module.Params.upn_suffix } else { (Get-ADDomain -ErrorAction Stop).DNSRoot }
    $params = @{
        Name                 = $name
        SamAccountName       = $name
        UserPrincipalName    = "$name@$suffix"
        Path                 = $module.Params.organizational_unit
        Enabled              = $true
        PasswordNeverExpires = $module.Params.password_never_expires
        OtherAttributes      = $posix
        ErrorAction          = "Stop"
    }
    if ($module.Params.description) { $params.Description = $module.Params.description }
    if ($plainPassword) {
        $params.AccountPassword = (ConvertTo-SecureString $plainPassword -AsPlainText -Force)
        $params.ChangePasswordAtLogon = $module.Params.change_password_at_logon
    }

    if (-not $module.CheckMode) {
        New-ADUser @params
    }
    $module.Result.changed = $true
    $module.Result.msg = "Usuario $name creado con UID $uid y GID $gid"
}
else {
    # Usuario existente: aplicar atributos POSIX segun update_mode.
    $changes  = @()
    $force    = ($module.Params.update_mode -eq "force")
    $replace  = @{}

    $desired = @{
        uidNumber         = $uid
        gidNumber         = $gid
        unixHomeDirectory = $module.Params.unix_home_directory
        loginShell        = $module.Params.login_shell
        gecos             = $module.Params.gecos
    }
    if ($module.Params.description)           { $desired.description = $module.Params.description }
    if ($module.Params.extension_attribute10) { $desired.extensionAttribute10 = $module.Params.extension_attribute10 }

    foreach ($attr in $desired.Keys) {
        $current = $existing.$attr
        $want    = $desired[$attr]
        if (-not $current) {
            $replace[$attr] = $want
            $changes += "$attr sin contenido -> $want"
        }
        elseif ("$current" -ne "$want") {
            if ($force) {
                $replace[$attr] = $want
                $changes += "${attr}: $current -> $want"
            }
            else {
                $module.Result.warnings_detail += "ADVERTENCIA: $attr actual '$current', solicitado '$want'. NO modificado (update_mode=safe)."
            }
        }
    }

    if ($replace.Count -gt 0) {
        if (-not $module.CheckMode) {
            Set-ADUser -Identity $name -Replace $replace -ErrorAction Stop
        }
        $module.Result.changed = $true
    }
    $module.Result.changes = $changes
    $module.Result.msg = if ($changes.Count -gt 0) { "Atributos POSIX actualizados" } else { "Sin cambios en atributos POSIX" }
}

# -----------------------------------------------------------------------------
# Membresia de grupos (idempotente).
# -----------------------------------------------------------------------------
# La pertenencia se mira en el memberOf del usuario: Get-ADGroupMember falla con grupos de mas de
# 5000 miembros o con miembros de otros dominios, y antes ese fallo solo dejaba un aviso: el usuario
# se quedaba sin el grupo y la tarea salia "ok".
$groupsAdded = @()
$memberOf = @()
if ($module.Params.groups.Count -gt 0) {
    $current = Get-ExistingUser -Identity $name
    if ($current) { $memberOf = @($current.memberOf) }
}
foreach ($group in $module.Params.groups) {
    $g = Get-ADGroup -Identity $group -ErrorAction Stop
    if ($memberOf -notcontains $g.DistinguishedName) {
        if (-not $module.CheckMode) {
            Add-ADGroupMember -Identity $group -Members $name -ErrorAction Stop
        }
        $groupsAdded += $group
        $module.Result.changed = $true
    }
}
if ($groupsAdded.Count -gt 0) { $module.Result.groups_added = $groupsAdded }

$module.ExitJson()
