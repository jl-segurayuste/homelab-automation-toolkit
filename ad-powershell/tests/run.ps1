# Pruebas de las funciones de dot-sourcing con un módulo ActiveDirectory simulado (sin dominio).
#   pwsh -NoProfile -File ad-powershell/tests/run.ps1
param([string]$Repo = (Resolve-Path "$PSScriptRoot/../.."))
# Como en una consola normal: los errores no terminantes no paran el script, así las pruebas
# detectan las llamadas que olvidan -ErrorAction Stop.
$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
namespace Microsoft.ActiveDirectory.Management {
    public class ADException : System.Exception { public ADException(string m) : base(m) {} }
    public class ADIdentityNotFoundException : ADException { public ADIdentityNotFoundException(string m) : base(m) {} }
}
'@
$env:PSModulePath = "$PSScriptRoot" + [IO.Path]::PathSeparator + $env:PSModulePath
Import-Module ActiveDirectory -Force
$d = Join-Path $Repo 'ad-powershell'
. "$d/Generate-RandomPassword.ps1"
. "$d/Get-NextAvailableUsername.ps1"
. "$d/Remove-ADUserFromGroups.ps1"
. "$d/ad_group_operations.ps1"
. "$d/ad_user_operations.ps1"

$script:fail = 0
function Check([string]$name, [bool]$ok) {
    if ($ok) { "  ok   $name" } else { "  FALLO $name"; $script:fail++ }
}
function Reset { $global:Calls = @(); $global:Stub = @{} }
function U($sam, $memberOf) { [pscustomobject]@{ SamAccountName = $sam; memberOf = $memberOf; DistinguishedName = "CN=$sam,OU=u,DC=x" } }
function G($sam) { [pscustomobject]@{ SamAccountName = $sam; DistinguishedName = "CN=$sam,OU=g,DC=x"; gidNumber = $null } }

"Contraseñas"
$all = 1..300 | ForEach-Object { Generate-RandomPassword -Length 15 -Username 'jdoe' }
Check 'todas válidas' (($all | Where-Object { -not $_.success }).Count -eq 0)
Check 'longitud 15' (($all | Where-Object { $_.password.Length -ne 15 }).Count -eq 0)
Check 'sin repetidas' ((($all.password | Sort-Object -Unique).Count) -eq 300)
if (Get-Command Get-SecureRandomIndex -ErrorAction SilentlyContinue) {
    $idx = 1..5000 | ForEach-Object { Get-SecureRandomIndex -Max 3 }
    Check 'índice en rango y todos los valores' ((($idx | Sort-Object -Unique) -join ',') -eq '0,1,2')
    Check 'reparto parejo' ((($idx | Group-Object | Where-Object { $_.Count -lt 1500 }).Count) -eq 0)
} else { Check 'generador criptográfico' $false }

"Siguiente usuario"
Reset
$existentes = @('jdoe01', 'jdoe02')
$global:Stub['Get-ADUser'] = { param($p) if ($p.Filter -match "'(.+)'") { if ($existentes -contains $Matches[1]) { U $Matches[1] } } }
$r = Get-NextAvailableUsername -UserName 'jdoe'
Check 'salta los existentes' ($r.next_username -eq 'jdoe03')
Reset
$global:Stub['Get-ADUser'] = { param($p) $global:Filtro = $p.Filter }
$null = Get-NextAvailableUsername -UserName "o'brien"
Check 'apóstrofo escapado en el filtro' ($global:Filtro -eq "SamAccountName -eq 'o''brien01'")
Reset
$global:Stub['Get-ADUser'] = { param($p) Write-Error 'El servidor no responde' }
$lanzo = $false
try { $null = Get-NextAvailableUsername -UserName 'jdoe' } catch { $lanzo = $true }
Check 'DC caído: error, no un nombre «libre»' $lanzo

"Quitar de grupos"
Reset
$global:Stub['Get-ADUser'] = { param($p) U 'ana' @('CN=g1,OU=g,DC=x') }
$global:Stub['Get-ADGroup'] = { param($p) if ($p.Filter -match "'(.+)'") { G $Matches[1] } }
$global:Stub['Get-ADGroupMember'] = { throw 'no debería usarse' }
$r = Remove-ADUserFromGroups -UserName 'ana' -Groups 'g1', 'g2'
$quitados = @($global:Calls | Where-Object { $_[0] -eq 'Remove-ADGroupMember' })
Check 'retira solo donde era miembro' ($quitados.Count -eq 1 -and $r.success)
Check 'g2 marcado como no miembro' ($r.groups_removed -contains 'g2 (el usuario ya no era miembro)')
Reset
$global:Stub['Get-ADUser'] = { param($p) Write-Error 'Acceso denegado' }
$r = Remove-ADUserFromGroups -UserName 'ana' -Groups 'g1'
Check 'usuario ilegible: success=false' (-not $r.success)

"Grupos"
Reset
$global:Stub['Get-ADGroup'] = { param($p) if ($p.Identity) { G $p.Identity } }
$r = Remove-ADGroupSafe -GroupName 'g1'
Check 'Remove-ADGroupSafe devuelve un solo resultado' ($r -is [hashtable] -and $r.success)
Reset
$global:Stub['Get-ADGroup'] = { param($p) if ("$($p.Filter)" -like 'gidNumber*') { Write-Error 'Timeout' } }
$r = New-ADGroupWithGIDSafe -GroupName 'g9' -GID 10625 -OrganizationalUnit 'OU=g,DC=x'
$creados = @($global:Calls | Where-Object { $_[0] -eq 'New-ADGroup' })
Check 'fallo al comprobar el GID: no crea el grupo' ((-not $r.success) -and $creados.Count -eq 0)
Reset
$global:Stub['Get-ADGroup'] = { param($p) if ("$($p.Filter)" -like 'SamAccountName*') { G 'g1' } }
$global:Stub['Set-ADGroup'] = { param($p) Write-Error 'Sin permisos' }
$r = New-ADGroupWithGIDSafe -GroupName 'g1' -GID 10625 -OrganizationalUnit 'OU=g,DC=x'
Check 'Set-ADGroup falla: success=false' (-not $r.success)

"Usuarios"
Reset
$global:Stub['Get-ADUser'] = { param($p) if ($p.Identity) { U $p.Identity } }
$r = Remove-ADUserSafe -UserName 'ana'
Check 'Remove-ADUserSafe devuelve un solo resultado' ($r -is [hashtable] -and $r.success)
Reset
$global:Stub['Get-ADUser'] = { param($p) [pscustomobject]@{ SamAccountName = 'ana'; uidNumber = $null; gidNumber = 1; unixHomeDirectory = '/h'; loginShell = '/bin/bash'; gecos = 'x' } }
$global:Stub['Set-ADUser'] = { param($p) Write-Error 'Sin permisos' }
$r = Update-ADUserPosixAttributesSafe -UserName 'ana' -UID 5 -GID 1 -UnixHomeDirectory '/h' -LoginShell '/bin/bash' -Gecos 'x'
Check 'Set-ADUser falla: success=false' (-not $r.success)
Reset
$global:Stub['Get-ADUser'] = { param($p) U 'ana' @('CN=g1,OU=g,DC=x') }
$global:Stub['Get-ADGroup'] = { param($p) G $p.Identity }
$global:Stub['Add-ADGroupMember'] = { param($p) throw [Microsoft.ActiveDirectory.Management.ADException]::new('La cuenta ya es miembro del grupo') }
$r = Add-ADUserToGroups -UserName 'ana' -Groups 'g1'
Check 'ya miembro (DC en español): sin error' ($r.success -and ($r.groups_added -contains 'g1 (ya miembro)'))
Reset
$global:Stub['Get-ADUser'] = { param($p) if ("$($p.Filter)" -like 'uidNumber*') { Write-Error 'Timeout' } }
$r = New-ADUserWithPosix -UserName 'ana' -UID 5 -GID 1 -UnixHomeDirectory '/h' -LoginShell '/bin/bash' -Gecos 'x' -OrganizationalUnit 'OU=u,DC=x'
$creados = @($global:Calls | Where-Object { $_[0] -eq 'New-ADUser' })
Check 'fallo al comprobar el UID: no crea el usuario' ((-not $r.success) -and $creados.Count -eq 0)

if ($script:fail) { "$($script:fail) FALLOS"; exit 1 } else { 'TODO OK' }
