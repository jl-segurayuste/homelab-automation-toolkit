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

foreach ($group in $module.Params.groups) {
    try {
        $g = Get-ADGroup -Filter "SamAccountName -eq '$group'" -ErrorAction SilentlyContinue
        if (-not $g) {
            $errors += "Grupo '$group' no existe en AD"
            continue
        }

        $isMember = Get-ADGroupMember -Identity $group -ErrorAction SilentlyContinue |
            Where-Object { $_.SamAccountName -eq $user }

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
