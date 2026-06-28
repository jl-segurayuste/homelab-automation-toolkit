#Requires -Version 5.1
#Requires -Modules ActiveDirectory

# =============================================================================
# FUNCIONES PARA GESTIÓN DE GRUPOS EN ACTIVE DIRECTORY
# Rol: user_management
# Propósito: Operaciones sobre grupos con soporte para gidNumber
# =============================================================================

<#
.SYNOPSIS
    Verifica si un grupo existe en Active Directory
.DESCRIPTION
    Busca un grupo por nombre y retorna su estado y gidNumber
.PARAMETER GroupName
    Nombre del grupo (SamAccountName)
.OUTPUTS
    Hashtable con: exists, gidNumber, dn
.EXAMPLE
    Test-ADGroupExists -GroupName "appgroup"
#>
function Test-ADGroupExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupName
    )

    try {
        $group = Get-ADGroup -Identity $GroupName `
                             -Properties gidNumber `
                             -ErrorAction Stop

        return @{
            exists         = $true
            samAccountName = $group.SamAccountName
            gidNumber      = $group.gidNumber
            dn             = $group.DistinguishedName
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        return @{exists = $false}
    }
    catch {
        throw "Error al buscar grupo $GroupName : $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Verifica si un GID está en uso
.DESCRIPTION
    Busca si existe algún grupo con el GID especificado
.PARAMETER GID
    Identificador numérico del grupo (gidNumber)
.PARAMETER ExcludeGroup
    Nombre de grupo a excluir de la búsqueda (opcional)
.OUTPUTS
    Hashtable con: in_use, used_by, gid
.EXAMPLE
    Test-ADGIDInUse -GID 10625
    Test-ADGIDInUse -GID 10625 -ExcludeGroup "appgroup"
#>
function Test-ADGIDInUse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$GID,

        [Parameter(Mandatory=$false)]
        [string]$ExcludeGroup = ""
    )

    try {
        $groups = Get-ADGroup -Filter "gidNumber -eq $GID" `
                              -Properties gidNumber,SamAccountName `
                              -ErrorAction Stop

        if ($ExcludeGroup) {
            $groups = $groups | Where-Object { $_.SamAccountName -ne $ExcludeGroup }
        }

        if ($groups) {
            return @{
                in_use   = $true
                used_by  = ($groups | Select-Object -ExpandProperty SamAccountName) -join ', '
                gid      = $GID
            }
        }

        return @{
            in_use = $false
            gid    = $GID
        }
    }
    catch {
        throw "Error al verificar GID $GID : $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Crea un grupo con gidNumber de forma segura con comprobación de GID duplicado
.DESCRIPTION
    Comprueba si el grupo existe:
    - Si NO existe: comprueba que el GID no esté en uso y lo crea
    - Si existe SIN gidNumber: añade el gidNumber
    - Si existe CON gidNumber DIFERENTE: avisa pero NO actualiza (prevención de errores)
    - Si existe CON gidNumber IGUAL: no hace nada (idempotencia)

    IMPORTANTE: Esta función NO sobrescribe gidNumber si ya tiene un valor diferente
                y NO permite crear grupos con GID ya en uso por otro grupo
.PARAMETER GroupName
    Nombre del grupo (SamAccountName)
.PARAMETER GID
    Identificador numérico del grupo (gidNumber)
.PARAMETER OrganizationalUnit
    DN de la OU donde crear el grupo
.PARAMETER Description
    Descripción del grupo
.PARAMETER GroupScope
    Ámbito del grupo: Global, Universal, DomainLocal
.PARAMETER GroupCategory
    Categoría del grupo: Security, Distribution
.OUTPUTS
    Hashtable con: success, action, message, warning
.EXAMPLE
    New-ADGroupWithGIDSafe -GroupName "appgroup" -GID 10625 -OrganizationalUnit "OU=grupos,DC=prod,DC=example,DC=com" -Description "Grupo funcional de ejemplo"
#>
function New-ADGroupWithGIDSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupName,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$GID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$OrganizationalUnit,

        [Parameter(Mandatory=$false)]
        [string]$Description = "",

        [Parameter(Mandatory=$false)]
        [ValidateSet('Global', 'Universal', 'DomainLocal')]
        [string]$GroupScope = 'Global',

        [Parameter(Mandatory=$false)]
        [ValidateSet('Security', 'Distribution')]
        [string]$GroupCategory = 'Security'
    )

    try {
        $existingGroup = Get-ADGroup -Filter "SamAccountName -eq '$GroupName'" `
                                     -Properties gidNumber `
                                     -ErrorAction SilentlyContinue

        if ($existingGroup) {
            if (!$existingGroup.gidNumber) {
                # Grupo existe SIN gidNumber -> AÑADIR
                Set-ADGroup -Identity $GroupName -Replace @{gidNumber = $GID}
                return @{
                    success = $true
                    action  = "updated"
                    message = "Grupo $GroupName ya existía sin gidNumber. Se añadió gidNumber $GID"
                    gid     = $GID
                }
            }
            elseif ($existingGroup.gidNumber -eq $GID) {
                # Grupo existe CON gidNumber IGUAL -> IDEMPOTENCIA
                return @{
                    success = $true
                    action  = "none"
                    message = "Grupo $GroupName ya existe con gidNumber $GID correcto"
                    gid     = $GID
                }
            }
            else {
                # Grupo existe CON gidNumber DIFERENTE -> ADVERTENCIA
                return @{
                    success       = $true
                    action        = "none"
                    message       = "Grupo $GroupName ya existe"
                    warning       = "ADVERTENCIA: Grupo tiene gidNumber $($existingGroup.gidNumber), se solicitó $GID. NO se actualizó (prevención de error humano). Verificar si el GID existente es correcto."
                    gid_current   = $existingGroup.gidNumber
                    gid_requested = $GID
                }
            }
        }
        else {
            # El grupo NO EXISTE -> comprobar que el GID no esté en uso
            $gidConflict = Get-ADGroup -Filter "gidNumber -eq $GID" `
                                        -Properties gidNumber,SamAccountName `
                                        -ErrorAction SilentlyContinue

            if ($gidConflict) {
                return @{
                    success    = $false
                    error      = "El GID $GID ya está en uso por el grupo $($gidConflict.SamAccountName). Asigna un GID libre del rango definido en tu organización."
                    error_type = "GIDConflict"
                    gid        = $GID
                    used_by    = $gidConflict.SamAccountName
                }
            }

            # GID libre -> CREAR
            $params = @{
                Name            = $GroupName
                SamAccountName  = $GroupName
                GroupScope      = $GroupScope
                GroupCategory   = $GroupCategory
                Path            = $OrganizationalUnit
                OtherAttributes = @{gidNumber = $GID}
                ErrorAction     = "Stop"
            }

            if ($Description) { $params.Description = $Description }

            New-ADGroup @params

            return @{
                success   = $true
                action    = "created"
                message   = "Grupo $GroupName creado con gidNumber $GID"
                groupName = $GroupName
                gid       = $GID
            }
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADException] {
        return @{
            success    = $false
            error      = $_.Exception.Message
            error_type = "ADException"
        }
    }
    catch [System.UnauthorizedAccessException] {
        return @{
            success    = $false
            error      = "Sin permisos para crear o modificar grupo $GroupName"
            error_type = "UnauthorizedAccess"
        }
    }
    catch {
        return @{
            success    = $false
            error      = $_.Exception.Message
            error_type = $_.Exception.GetType().Name
        }
    }
}

<#
.SYNOPSIS
    Elimina un grupo de Active Directory
.DESCRIPTION
    Elimina un grupo de forma segura comprobando que existe previamente
.PARAMETER GroupName
    Nombre del grupo a eliminar (SamAccountName)
.OUTPUTS
    Hashtable con: success, message
.EXAMPLE
    Remove-ADGroupSafe -GroupName "appgroup"
#>
function Remove-ADGroupSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupName
    )

    try {
        Get-ADGroup -Identity $GroupName -ErrorAction Stop
        Remove-ADGroup -Identity $GroupName -Confirm:$false -ErrorAction Stop

        return @{
            success   = $true
            message   = "Grupo $GroupName eliminado correctamente"
            groupName = $GroupName
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        return @{
            success    = $false
            error      = "Grupo $GroupName no existe en AD"
            error_type = "NotFound"
        }
    }
    catch {
        return @{
            success    = $false
            error      = $_.Exception.Message
            error_type = $_.Exception.GetType().Name
        }
    }
}

# Exportar todas las funciones
#Export-ModuleMember -Function Test-ADGroupExists, Test-ADGIDInUse, New-ADGroupWithGIDSafe, Remove-ADGroupSafe
