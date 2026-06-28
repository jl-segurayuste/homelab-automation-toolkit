#!powershell

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License
# Modulo Ansible: calcula el siguiente SamAccountName libre siguiendo la
# nomenclatura sufijo numerico 01-99 y, agotado, alfabetico a-z.
# Solo lectura: nunca cambia nada (changed=false).

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Modules ActiveDirectory

$spec = @{
    options = @{
        username = @{ type = "str"; required = $true }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$userName = $module.Params.username
$module.Result.changed = $false

# Detectar sufijo numerico de 2 digitos al final.
$numericMatch = [regex]::Match($userName, '^(.+?)(\d{2})$')
if ($numericMatch.Success) {
    $base     = $numericMatch.Groups[1].Value
    $startNum = [int]$numericMatch.Groups[2].Value + 1
}
else {
    $base     = $userName
    $startNum = 1
}

# Rango numerico 01-99.
if ($startNum -le 99) {
    for ($i = $startNum; $i -le 99; $i++) {
        $candidate = $base + $i.ToString("D2")
        $exists = Get-ADUser -Filter "SamAccountName -eq '$candidate'" -ErrorAction SilentlyContinue
        if (-not $exists) {
            $module.Result.found = $true
            $module.Result.next_username = $candidate
            $module.ExitJson()
        }
    }
}

# Agotado el numerico, rango alfabetico a-z.
for ($c = [byte][char]'a'; $c -le [byte][char]'z'; $c++) {
    $candidate = $base + [char]$c
    $exists = Get-ADUser -Filter "SamAccountName -eq '$candidate'" -ErrorAction SilentlyContinue
    if (-not $exists) {
        $module.Result.found = $true
        $module.Result.next_username = $candidate
        $module.ExitJson()
    }
}

$module.Result.found = $false
$module.Result.next_username = ""
$module.FailJson("No se encontro nombre disponible para la base '$base' (numerico 01-99 y alfabetico a-z agotados)")
