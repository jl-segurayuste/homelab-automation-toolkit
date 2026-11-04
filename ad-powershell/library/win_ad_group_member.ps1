#!powershell

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License
# Modulo Ansible: gestiona la pertenencia de un usuario a grupos de AD.
# state=present anade a los grupos; state=absent los retira (offboarding).

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Modules ActiveDirectory

$spec = @{
    options = @{
        user   = @{ type = "str"; required = $true }
        groups = @{ type = "list"; elements = "str"; required = $true }
        state  = @{ type = "str"; default = "present"; choices = @("present", "absent") }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$user  = $module.Params.user
$state = $module.Params.state
$module.Result.changed = $false
$groupsChanged = @()
$errors = @()

# La pertenencia se mira en el memberOf del usuario. Antes se usaba Get-ADGroupMember con
# SilentlyContinue: si fallaba (grupos de mas de 5000 miembros, miembros de otros dominios), el
# usuario parecia no ser miembro y en state=absent la baja salia bien sin retirarlo del grupo.
$userObj  = Get-ADUser -Identity $user -Properties memberOf -ErrorAction Stop
$memberOf = @($userObj.memberOf)

foreach ($group in $module.Params.groups) {
    try {
        $g = Get-ADGroup -Filter "SamAccountName -eq '$($group -replace "'", "''")'" -ErrorAction Stop
        if (-not $g) {
            $errors += "Grupo '$group' no existe en AD"
            continue
        }

        $isMember = $memberOf -contains $g.DistinguishedName

        if ($state -eq "present") {
            if (-not $isMember) {
                if (-not $module.CheckMode) {
                    Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
                }
                $groupsChanged += $group
                $module.Result.changed = $true
            }
        }
        else {
            if ($isMember) {
                if (-not $module.CheckMode) {
                    Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false -ErrorAction Stop
                }
                $groupsChanged += $group
                $module.Result.changed = $true
            }
        }
    }
    catch {
        $errors += "Error con el grupo '$group': $($_.Exception.Message)"
    }
}

if ($state -eq "present") { $module.Result.groups_added = $groupsChanged }
else { $module.Result.groups_removed = $groupsChanged }

if ($errors.Count -gt 0) {
    $module.Result.errors = $errors
    $module.FailJson("Operacion completada con errores en algunos grupos")
}

$module.Result.msg = "Membresia de grupos actualizada para el usuario $user"
$module.ExitJson()
