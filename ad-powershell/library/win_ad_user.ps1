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
            -Properties uidNumber, gidNumber, unixHomeDirectory, loginShell, gecos, description, memberOf `
            -ErrorAction Stop
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        return $null
    }
}

function New-CompliantPassword {
    param([int]$Length, [string]$Username)
    $upper   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lower   = "abcdefghijklmnopqrstuvwxyz"
    $nums    = "0123456789"
    $special = "~!@#$%&*_-+=|()[]:;<>,."
    for ($attempt = 1; $attempt -le 50; $attempt++) {
        $chars = @()
        $chars += $upper[(Get-Random -Maximum $upper.Length)]
        $chars += $lower[(Get-Random -Maximum $lower.Length)]
        $chars += $nums[(Get-Random -Maximum $nums.Length)]
        $chars += $special[(Get-Random -Maximum $special.Length)]
        $all = $upper + $lower + $nums + $special
        for ($i = $chars.Count; $i -lt $Length; $i++) {
            $chars += $all[(Get-Random -Maximum $all.Length)]
        }
        for ($i = $chars.Count - 1; $i -gt 0; $i--) {
            $j = Get-Random -Maximum ($i + 1)
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
    $uidConflict = Get-ADUser -Filter "uidNumber -eq $uid" -Properties uidNumber, SamAccountName -ErrorAction SilentlyContinue
    if ($uidConflict) {
        $module.FailJson("El UID $uid ya esta en uso por el usuario $($uidConflict.SamAccountName)")
    }

    # Resolver contrasena (proporcionada o generada).
    $plainPassword = $module.Params.password
    if (-not $plainPassword -and $module.Params.generate_password) {
        $plainPassword = New-CompliantPassword -Length $module.Params.password_length -Username $name
        $module.Result.generated_password = $plainPassword
        $module.Result.warnings_detail += "Se genero una contrasena aleatoria (campo no_log)"
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

    $suffix = if ($module.Params.upn_suffix) { $module.Params.upn_suffix } else { (Get-ADDomain).DNSRoot }
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
                $changes += "$attr: $current -> $want"
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
$groupsAdded = @()
foreach ($group in $module.Params.groups) {
    $member = $null
    try {
        $member = Get-ADGroupMember -Identity $group -ErrorAction Stop | Where-Object { $_.SamAccountName -eq $name }
    }
    catch {
        $module.Result.warnings_detail += "No se pudo comprobar el grupo ${group}: $($_.Exception.Message)"
        continue
    }
    if (-not $member) {
        if (-not $module.CheckMode) {
            Add-ADGroupMember -Identity $group -Members $name -ErrorAction Stop
        }
        $groupsAdded += $group
        $module.Result.changed = $true
    }
}
if ($groupsAdded.Count -gt 0) { $module.Result.groups_added = $groupsAdded }

$module.ExitJson()
