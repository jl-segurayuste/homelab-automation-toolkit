# =============================================================================
# Remove-ADUserFromGroups
# Elimina un usuario de uno o varios grupos de AD.
# Simétrica a Add-ADUserToGroups de ad_user_operations.ps1
#
# Parámetros:
#   -UserName : SamAccountName del usuario
#   -Groups   : Array de nombres de grupos (SamAccountName)
#
# Retorna JSON con:
#   success        : bool
#   message        : string
#   groups_removed : lista de grupos de los que se eliminó al usuario
#   errors         : lista de errores si los hubiera
#
# Comportamiento:
#   - Si el grupo no existe en AD   -> registra error, continúa con el siguiente
#   - Si el usuario no es miembro   -> registra como "ya no era miembro", continúa
#   - Si falla la eliminación       -> registra error, continúa con el siguiente
#   - Retorna success=false solo si hubo errores reales
# =============================================================================
function Remove-ADUserFromGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Groups
    )

    $groups_removed = @()
    $errors         = @()

    # La pertenencia se mira en el memberOf del usuario. Antes se usaba Get-ADGroupMember con
    # SilentlyContinue: si fallaba (grupos de más de 5000 miembros, miembros de otros dominios),
    # el usuario parecía no ser miembro y la función decía que ya no lo era sin retirarlo.
    try {
        $memberOf = @((Get-ADUser -Identity $UserName -Properties memberOf -ErrorAction Stop).memberOf)
    }
    catch {
        return @{
            success        = $false
            message        = "No se pudo leer el usuario '$UserName': $($_.Exception.Message)"
            groups_removed = @()
            errors         = @($_.Exception.Message)
        }
    }

    foreach ($group in $Groups) {
        try {
            $g = Get-ADGroup -Filter "SamAccountName -eq '$($group -replace "'", "''")'" `
                             -ErrorAction Stop
            if (-not $g) {
                $errors += "Grupo '$group' no existe en AD"
                continue
            }

            $isMember = $memberOf -contains $g.DistinguishedName

            if (-not $isMember) {
                $groups_removed += "$group (el usuario ya no era miembro)"
                continue
            }

            Remove-ADGroupMember -Identity $group `
                                 -Members $UserName `
                                 -Confirm:$false `
                                 -ErrorAction Stop

            $groups_removed += $group

        } catch {
            $errors += "Error al eliminar de '$group': $($_.Exception.Message)"
        }
    }

    $success = ($errors.Count -eq 0)

    return @{
        success        = $success
        message        = if ($success) {
                             "Usuario '$UserName' eliminado de los grupos correctamente"
                         } else {
                             "Operación completada con errores"
                         }
        groups_removed = $groups_removed
        errors         = $errors
    }
}
