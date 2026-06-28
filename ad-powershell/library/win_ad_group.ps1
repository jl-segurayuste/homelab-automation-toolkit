#!powershell

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License
# Modulo Ansible: gestiona grupos de Active Directory con gidNumber (POSIX).

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Modules ActiveDirectory

$spec = @{
    options = @{
        name                = @{ type = "str"; required = $true }
        state               = @{ type = "str"; default = "present"; choices = @("present", "absent") }
        gid_number          = @{ type = "int" }
        organizational_unit = @{ type = "str" }
        description         = @{ type = "str" }
        scope               = @{ type = "str"; default = "Global"; choices = @("Global", "Universal", "DomainLocal") }
        category            = @{ type = "str"; default = "Security"; choices = @("Security", "Distribution") }
    }
    required_if = @(
        , @("state", "present", @("gid_number", "organizational_unit"))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name  = $module.Params.name
$state = $module.Params.state
$gid   = $module.Params.gid_number
$module.Result.changed = $false

function Get-ExistingGroup {
    param([string]$Identity)
    try {
        return Get-ADGroup -Identity $Identity -Properties gidNumber -ErrorAction Stop
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        return $null
    }
}

$existing = Get-ExistingGroup -Identity $name

# -----------------------------------------------------------------------------
# state: absent
# -----------------------------------------------------------------------------
if ($state -eq "absent") {
    if ($existing) {
        if (-not $module.CheckMode) {
            Remove-ADGroup -Identity $name -Confirm:$false -ErrorAction Stop
        }
        $module.Result.changed = $true
        $module.Result.msg = "Grupo $name eliminado"
    }
    else {
        $module.Result.msg = "El grupo $name no existe"
    }
    $module.ExitJson()
}

# -----------------------------------------------------------------------------
# state: present
# -----------------------------------------------------------------------------
if ($existing) {
    if (-not $existing.gidNumber) {
        # Existe sin gidNumber -> anadirlo.
        if (-not $module.CheckMode) {
            Set-ADGroup -Identity $name -Replace @{ gidNumber = $gid } -ErrorAction Stop
        }
        $module.Result.changed = $true
        $module.Result.action = "updated"
        $module.Result.msg = "Grupo $name ya existia sin gidNumber; anadido gidNumber $gid"
    }
    elseif ([int]$existing.gidNumber -eq $gid) {
        $module.Result.action = "none"
        $module.Result.msg = "Grupo $name ya existe con gidNumber $gid correcto"
    }
    else {
        # gidNumber distinto: no se sobrescribe (prevencion de error humano).
        $module.Result.action = "none"
        $module.Result.msg = "Grupo $name ya existe con gidNumber $($existing.gidNumber); se solicito $gid. NO modificado."
        $module.Result.warnings_detail = @("gidNumber actual $($existing.gidNumber) distinto del solicitado $gid. Verificar cual es correcto.")
    }
    $module.ExitJson()
}

# El grupo no existe: comprobar que el GID este libre y crearlo.
$gidConflict = Get-ADGroup -Filter "gidNumber -eq $gid" -Properties gidNumber, SamAccountName -ErrorAction SilentlyContinue
if ($gidConflict) {
    $module.FailJson("El GID $gid ya esta en uso por el grupo $($gidConflict.SamAccountName)")
}

$params = @{
    Name            = $name
    SamAccountName  = $name
    GroupScope      = $module.Params.scope
    GroupCategory   = $module.Params.category
    Path            = $module.Params.organizational_unit
    OtherAttributes = @{ gidNumber = $gid }
    ErrorAction     = "Stop"
}
if ($module.Params.description) { $params.Description = $module.Params.description }

if (-not $module.CheckMode) {
    New-ADGroup @params
}
$module.Result.changed = $true
$module.Result.action = "created"
$module.Result.msg = "Grupo $name creado con gidNumber $gid"

$module.ExitJson()
