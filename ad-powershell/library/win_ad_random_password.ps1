#!powershell

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License
# Modulo Ansible: genera una contrasena aleatoria conforme a la politica de AD
# (mayuscula, minuscula, numero y caracter especial) que no contiene el usuario.
# Devuelve la contrasena en un campo no_log. No realiza cambios (changed=false).

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        username = @{ type = "str"; required = $true }
        length   = @{ type = "int"; default = 15 }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$length   = $module.Params.length
$username = $module.Params.username

if ($length -lt 8 -or $length -gt 128) {
    $module.FailJson("length debe estar entre 8 y 128")
}

$upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
$lower = "abcdefghijklmnopqrstuvwxyz"
$nums  = "0123456789"
$spec_ = "~!@#$%&*_-+=|()[]:;<>,."

for ($attempt = 1; $attempt -le 50; $attempt++) {
    $chars = @()
    $chars += $upper[(Get-Random -Maximum $upper.Length)]
    $chars += $lower[(Get-Random -Maximum $lower.Length)]
    $chars += $nums[(Get-Random -Maximum $nums.Length)]
    $chars += $spec_[(Get-Random -Maximum $spec_.Length)]
    $all = $upper + $lower + $nums + $spec_
    for ($i = $chars.Count; $i -lt $length; $i++) {
        $chars += $all[(Get-Random -Maximum $all.Length)]
    }
    # Fisher-Yates.
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $j = Get-Random -Maximum ($i + 1)
        $t = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $t
    }
    $candidate = -join $chars
    $ok = ($candidate -cmatch '[a-z]') -and ($candidate -cmatch '[A-Z]') -and `
          ($candidate -match '\d') -and ($candidate -match '[^0-9a-zA-Z]') -and `
          ($candidate.Length -ge 8) -and ($candidate -notmatch [regex]::Escape($username))
    if ($ok) {
        $module.Result.changed = $false
        $module.Result.password = $candidate
        $module.Result.attempts = $attempt
        $module.ExitJson()
    }
}

$module.FailJson("No se pudo generar una contrasena valida tras 50 intentos")
