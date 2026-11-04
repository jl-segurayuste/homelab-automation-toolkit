# Módulo ActiveDirectory falso para probar las funciones sin dominio. Cada cmdlet llama al
# scriptblock global del mismo nombre, que define cada prueba.
$names = 'Get-ADUser', 'Get-ADGroup', 'Get-ADGroupMember', 'Set-ADUser', 'Set-ADGroup', 'New-ADUser',
         'New-ADGroup', 'Remove-ADUser', 'Remove-ADGroup', 'Add-ADGroupMember', 'Remove-ADGroupMember',
         'Get-ADDomain'
foreach ($n in $names) {
    $body = @"
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments)]`$Rest, `$Identity, `$Filter, `$Properties, `$Members,
      `$Replace, `$Enabled, [switch]`$Confirm)
`$global:Calls += ,@('$n', `$PSBoundParameters)
`$sb = `$global:Stub['$n']
if (`$sb) { & `$sb `$PSBoundParameters }
"@
    New-Item -Path "function:script:$n" -Value ([scriptblock]::Create($body)) | Out-Null
}
Export-ModuleMember -Function $names
