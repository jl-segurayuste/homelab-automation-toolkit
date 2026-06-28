#Requires -Version 5.1
#Requires -Modules ActiveDirectory

# =============================================================================
# FUNCIONES PARA GESTIÓN DE USUARIOS EN ACTIVE DIRECTORY
# Rol: user_management
# Propósito: Operaciones sobre usuarios con soporte para atributos POSIX
# =============================================================================

<#
.SYNOPSIS
    Verifica si un usuario existe en Active Directory
.DESCRIPTION
    Busca un usuario por nombre y retorna su estado y atributos POSIX
.PARAMETER UserName
    Nombre del usuario (SamAccountName)
.OUTPUTS
    Hashtable con: exists, uidNumber, gidNumber, unixHomeDirectory, loginShell, memberOf
.EXAMPLE
    Test-ADUserExists -UserName "jdoe"
#>
function Test-ADUserExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName
    )

    try {
        $user = Get-ADUser -Identity $UserName `
                           -Properties uidNumber,gidNumber,unixHomeDirectory,loginShell,gecos,memberOf,description,extensionAttribute10 `
                           -ErrorAction Stop

        return @{
            exists               = $true
            samAccountName       = $user.SamAccountName
            uidNumber            = $user.uidNumber
            gidNumber            = $user.gidNumber
            unixHomeDirectory    = $user.unixHomeDirectory
            loginShell           = $user.loginShell
            gecos                = $user.gecos
            description          = $user.description
            extensionAttribute10 = $user.extensionAttribute10
            memberOf             = $user.memberOf
            dn                   = $user.DistinguishedName
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        return @{exists = $false}
    }
    catch {
        throw "Error al buscar usuario $UserName : $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Verifica si un UID está en uso
.DESCRIPTION
    Busca si existe algún usuario con el UID especificado
.PARAMETER UID
    Identificador numérico del usuario (uidNumber)
.PARAMETER ExcludeUser
    Nombre de usuario a excluir de la búsqueda (opcional)
.OUTPUTS
    Hashtable con: in_use, used_by, uid
.EXAMPLE
    Test-ADUIDInUse -UID 75434
    Test-ADUIDInUse -UID 75434 -ExcludeUser "jdoe"
#>
function Test-ADUIDInUse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$UID,

        [Parameter(Mandatory=$false)]
        [string]$ExcludeUser = ""
    )

    try {
        $users = Get-ADUser -Filter "uidNumber -eq $UID" `
                            -Properties uidNumber,SamAccountName `
                            -ErrorAction Stop

        if ($ExcludeUser) {
            $users = $users | Where-Object { $_.SamAccountName -ne $ExcludeUser }
        }

        if ($users) {
            return @{
                in_use  = $true
                used_by = ($users | Select-Object -ExpandProperty SamAccountName) -join ', '
                uid     = $UID
            }
        }

        return @{
            in_use = $false
            uid    = $UID
        }
    }
    catch {
        throw "Error al verificar UID $UID : $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Crea un usuario en Active Directory con atributos POSIX
.DESCRIPTION
    Crea un usuario con uidNumber, gidNumber, unixHomeDirectory, loginShell.
    Incluye configuración para usuarios funcionales:
    - PasswordNeverExpires = true
    - extensionAttribute10 = "SinKeytab"

    Comprobaciones previas a la creación:
    - UID no en uso por otro usuario
    - GID asociado al grupo funcional correcto
    - Grupo funcional existe en AD (obligatorio antes de crear el usuario)

    Para usuarios PAM usar SkipGroupCreation=$true y FunctionalGroup con el
    nombre del grupo funcional (sin la secuencia pX del usuario).
.PARAMETER UserName
    Nombre del usuario (SamAccountName)
.PARAMETER UID
    Identificador numérico del usuario (uidNumber)
.PARAMETER GID
    Identificador numérico del grupo primario (gidNumber)
.PARAMETER UnixHomeDirectory
    Directorio home en sistemas UNIX/Linux
.PARAMETER LoginShell
    Shell de login
.PARAMETER Gecos
    Campo GECOS (descripción del usuario)
.PARAMETER OrganizationalUnit
    DN de la OU donde crear el usuario
.PARAMETER Description
    Descripción del usuario
.PARAMETER Password
    Contraseña inicial (SecureString)
.PARAMETER ChangePasswordAtLogon
    Si es true, fuerza cambio de contraseña en primer login
.PARAMETER PasswordNeverExpires
    Si es true, la password nunca expira (por defecto true para funcionales)
.PARAMETER SkipGroupCreation
    Si es true, indica que el grupo funcional ya existe previamente (PAM)
.PARAMETER FunctionalGroup
    Nombre del grupo funcional asociado al usuario.
    Obligatorio cuando SkipGroupCreation=$true (usuarios PAM)
.OUTPUTS
    Hashtable con: success, message, error
.EXAMPLE
    $pwd = ConvertTo-SecureString "Temporal123!" -AsPlainText -Force
    New-ADUserWithPosix -UserName "jdoe" -UID 75434 -GID 10625 -UnixHomeDirectory "/home/jdoe" -LoginShell "/bin/bash" -Gecos "Usuario de ejemplo" -OrganizationalUnit "OU=usuarios,DC=prod,DC=example,DC=com" -Password $pwd
.EXAMPLE
    # Usuario PAM (grupo ya creado previamente)
    New-ADUserWithPosix -UserName "asmith" -UID 79801 -GID 10701 -UnixHomeDirectory "/home/asmith" -LoginShell "/usr/bin/ksh" -Gecos "Usuario de ejemplo" -OrganizationalUnit "OU=fun,OU=usr,DC=example,DC=lan" -SkipGroupCreation $true -FunctionalGroup "asmith" -Password $pwd
#>
function New-ADUserWithPosix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$UID,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$GID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UnixHomeDirectory,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$LoginShell,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Gecos,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$OrganizationalUnit,

        [Parameter(Mandatory=$false)]
        [string]$Description = "",

        [Parameter(Mandatory=$false)]
        [SecureString]$Password,

        [Parameter(Mandatory=$false)]
        [bool]$ChangePasswordAtLogon = $false,

        [Parameter(Mandatory=$false)]
        [bool]$PasswordNeverExpires = $true,

        [Parameter(Mandatory=$false)]
        [bool]$SkipGroupCreation = $false,

        [Parameter(Mandatory=$false)]
        [string]$FunctionalGroup = ""
    )

    try {
        # =====================================================================
        # COMPROBAR UID NO EN USO
        # =====================================================================
        $uidConflict = Get-ADUser -Filter "uidNumber -eq $UID" `
                                   -Properties uidNumber,SamAccountName `
                                   -ErrorAction SilentlyContinue

        if ($uidConflict) {
            return @{
                success    = $false
                error      = "El UID $UID ya está en uso por el usuario $($uidConflict.SamAccountName). Asigna un UID libre del rango definido en tu organización."
                error_type = "UIDConflict"
                uid        = $UID
                used_by    = $uidConflict.SamAccountName
            }
        }

        # =====================================================================
        # COMPROBAR GRUPO FUNCIONAL Y GID
        # =====================================================================
        $groupToCheck = if ($FunctionalGroup) { $FunctionalGroup } else { $UserName }

        if ($SkipGroupCreation) {
            # PAM: el grupo debe existir previamente
            $existingGroup = Get-ADGroup -Filter "SamAccountName -eq '$groupToCheck'" `
                                          -Properties gidNumber `
                                          -ErrorAction SilentlyContinue
            if (-not $existingGroup) {
                return @{
                    success    = $false
                    error      = "El grupo funcional $groupToCheck no existe en AD. Debe crearse antes que el usuario."
                    error_type = "GroupNotFound"
                }
            }

            # Verificar que el GID del grupo coincide con el solicitado
            if ($existingGroup.gidNumber -and $existingGroup.gidNumber -ne $GID) {
                return @{
                    success       = $false
                    error         = "El grupo $groupToCheck existe pero su gidNumber ($($existingGroup.gidNumber)) no coincide con el GID solicitado ($GID)."
                    error_type    = "GIDMismatch"
                    gid_group     = $existingGroup.gidNumber
                    gid_requested = $GID
                }
            }
        }
        else {
            # No PAM: verificar que el GID no esté en uso por un grupo diferente
            $gidConflict = Get-ADGroup -Filter "gidNumber -eq $GID" `
                                        -Properties gidNumber,SamAccountName `
                                        -ErrorAction SilentlyContinue

            if ($gidConflict -and $gidConflict.SamAccountName -ne $groupToCheck) {
                return @{
                    success    = $false
                    error      = "El GID $GID ya está en uso por el grupo $($gidConflict.SamAccountName) que no coincide con el grupo funcional esperado $groupToCheck. Asigna un GID libre del rango definido en tu organización."
                    error_type = "GIDConflict"
                    gid        = $GID
                    used_by    = $gidConflict.SamAccountName
                }
            }
        }

        # =====================================================================
        # CREAR USUARIO
        # =====================================================================
        $posixAttributes = @{
            uidNumber            = $UID
            gidNumber            = $GID
            unixHomeDirectory    = $UnixHomeDirectory
            loginShell           = $LoginShell
            gecos                = $Gecos
            extensionAttribute10 = "SinKeytab"
        }

        $domain = (Get-ADDomain).DNSRoot
        $upn    = "$UserName@$domain"

        $params = @{
            Name                = $UserName
            SamAccountName      = $UserName
            UserPrincipalName   = $upn
            Path                = $OrganizationalUnit
            Enabled             = $true
            PasswordNeverExpires = $PasswordNeverExpires
            OtherAttributes     = $posixAttributes
            ErrorAction         = "Stop"
        }

        if ($Description) { $params.Description          = $Description }
        if ($Password)     { $params.AccountPassword      = $Password
                             $params.ChangePasswordAtLogon = $ChangePasswordAtLogon }

        New-ADUser @params
        Set-ADUser -Identity $UserName -Enabled $true

        return @{
            success  = $true
            message  = "Usuario $UserName creado con UID $UID y GID $GID"
            userName = $UserName
            uid      = $UID
            gid      = $GID
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
            error      = "Sin permisos para crear usuario $UserName"
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
    Actualiza atributos POSIX de forma segura (comportamiento idempotente)
.DESCRIPTION
    Revisa CADA atributo:
    - Si está vacío: lo asigna
    - Si es diferente: ADVIERTE pero NO actualiza (prevención de errores)
    - Si es igual: no hace nada (idempotencia)
.PARAMETER UserName
    Nombre del usuario
.PARAMETER UID
    uidNumber deseado
.PARAMETER GID
    gidNumber deseado
.PARAMETER UnixHomeDirectory
    unixHomeDirectory deseado
.PARAMETER LoginShell
    loginShell deseado
.PARAMETER Gecos
    gecos deseado
.PARAMETER Description
    description deseada (opcional)
.OUTPUTS
    Hashtable con: success, changes, warnings, changed
.EXAMPLE
    Update-ADUserPosixAttributesSafe -UserName "jdoe" -UID 75434 -GID 10625 -UnixHomeDirectory "/home/jdoe" -LoginShell "/bin/bash" -Gecos "Usuario de ejemplo"
#>
function Update-ADUserPosixAttributesSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$UID,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$GID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UnixHomeDirectory,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$LoginShell,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Gecos,

        [Parameter(Mandatory=$false)]
        [string]$Description = ""
    )

    try {
        $user = Get-ADUser -Identity $UserName `
                           -Properties uidNumber,gidNumber,unixHomeDirectory,loginShell,gecos,description `
                           -ErrorAction Stop

        $changes  = @()
        $warnings = @()

        # uidNumber
        if (!$user.uidNumber) {
            Set-ADUser -Identity $UserName -Replace @{uidNumber = $UID}
            $changes += "uidNumber sin contenido -> agregado: $UID"
        }
        elseif ($user.uidNumber -ne $UID) {
            $warnings += "ADVERTENCIA: uidNumber actual $($user.uidNumber), solicitado $UID. NO modificado."
        }

        # gidNumber
        if (!$user.gidNumber) {
            Set-ADUser -Identity $UserName -Replace @{gidNumber = $GID}
            $changes += "gidNumber sin contenido -> agregado: $GID"
        }
        elseif ($user.gidNumber -ne $GID) {
            $warnings += "ADVERTENCIA: gidNumber actual $($user.gidNumber), solicitado $GID. NO modificado."
        }

        # unixHomeDirectory
        if (!$user.unixHomeDirectory) {
            Set-ADUser -Identity $UserName -Replace @{unixHomeDirectory = $UnixHomeDirectory}
            $changes += "unixHomeDirectory sin contenido -> agregado: $UnixHomeDirectory"
        }
        elseif ($user.unixHomeDirectory -ne $UnixHomeDirectory) {
            $warnings += "ADVERTENCIA: unixHomeDirectory actual $($user.unixHomeDirectory), solicitado $UnixHomeDirectory. NO modificado."
        }

        # loginShell
        if (!$user.loginShell) {
            Set-ADUser -Identity $UserName -Replace @{loginShell = $LoginShell}
            $changes += "loginShell sin contenido -> agregado: $LoginShell"
        }
        elseif ($user.loginShell -ne $LoginShell) {
            $warnings += "ADVERTENCIA: loginShell actual $($user.loginShell), solicitado $LoginShell. NO modificado."
        }

        # gecos
        if (!$user.gecos) {
            Set-ADUser -Identity $UserName -Replace @{gecos = $Gecos}
            $changes += "gecos sin contenido -> agregado: $Gecos"
        }
        elseif ($user.gecos -ne $Gecos) {
            $warnings += "ADVERTENCIA: gecos actual '$($user.gecos)', solicitado '$Gecos'. NO modificado."
        }

        # description
        if ($Description) {
            if (!$user.description) {
                Set-ADUser -Identity $UserName -Replace @{description = $Description}
                $changes += "description sin contenido -> agregado: $Description"
            }
            elseif ($user.description -ne $Description) {
                $warnings += "ADVERTENCIA: description actual '$($user.description)', solicitado '$Description'. NO modificado."
            }
        }

        return @{
            success  = $true
            message  = if ($changes.Count -gt 0) { "Atributos actualizados" } else { "Sin cambios necesarios" }
            changes  = $changes
            warnings = $warnings
            changed  = ($changes.Count -gt 0)
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
    Actualiza atributos POSIX forzando la sobreescritura de valores existentes
.DESCRIPTION
    A diferencia de Update-ADUserPosixAttributesSafe, esta función SIEMPRE
    actualiza todos los atributos especificados, independientemente de si ya
    tienen valor. Usar con precaución, solo cuando se necesite corregir
    atributos POSIX ya existentes.
.PARAMETER UserName
    Nombre del usuario
.PARAMETER UID
    uidNumber a establecer
.PARAMETER GID
    gidNumber a establecer
.PARAMETER UnixHomeDirectory
    unixHomeDirectory a establecer
.PARAMETER LoginShell
    loginShell a establecer
.PARAMETER Gecos
    gecos a establecer
.PARAMETER Description
    description a establecer (opcional)
.OUTPUTS
    Hashtable con: success, changes, message
.EXAMPLE
    Update-ADUserPosixAttributesForce -UserName "jdoe" -UID 75434 -GID 10625 -UnixHomeDirectory "/home/jdoe" -LoginShell "/bin/bash" -Gecos "Usuario de ejemplo corregido"
#>
function Update-ADUserPosixAttributesForce {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$UID,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 999999)]
        [int]$GID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UnixHomeDirectory,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$LoginShell,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Gecos,

        [Parameter(Mandatory=$false)]
        [string]$Description = ""
    )

    try {
        $user = Get-ADUser -Identity $UserName `
                           -Properties uidNumber,gidNumber,unixHomeDirectory,loginShell,gecos,description `
                           -ErrorAction Stop

        $changes = @()

        # Forzar actualización de todos los atributos POSIX
        $replaceAttrs = @{
            uidNumber         = $UID
            gidNumber         = $GID
            unixHomeDirectory = $UnixHomeDirectory
            loginShell        = $LoginShell
            gecos             = $Gecos
        }

        if ($Description) { $replaceAttrs.description = $Description }

        Set-ADUser -Identity $UserName -Replace $replaceAttrs -ErrorAction Stop

        # Registrar qué cambió
        if ($user.uidNumber -ne $UID)                       { $changes += "uidNumber: $($user.uidNumber) -> $UID" }
        if ($user.gidNumber -ne $GID)                       { $changes += "gidNumber: $($user.gidNumber) -> $GID" }
        if ($user.unixHomeDirectory -ne $UnixHomeDirectory) { $changes += "unixHomeDirectory: $($user.unixHomeDirectory) -> $UnixHomeDirectory" }
        if ($user.loginShell -ne $LoginShell)               { $changes += "loginShell: $($user.loginShell) -> $LoginShell" }
        if ($user.gecos -ne $Gecos)                         { $changes += "gecos: '$($user.gecos)' -> '$Gecos'" }
        if ($Description -and $user.description -ne $Description) { $changes += "description: '$($user.description)' -> '$Description'" }

        return @{
            success = $true
            message = if ($changes.Count -gt 0) { "Atributos POSIX actualizados forzosamente" } else { "Sin cambios necesarios" }
            changes = $changes
            changed = ($changes.Count -gt 0)
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
    Añade un usuario a uno o más grupos de Active Directory
.DESCRIPTION
    Gestiona membresía de grupos de forma idempotente.
    Si el usuario ya es miembro de un grupo, lo indica pero no falla.
.PARAMETER UserName
    Nombre del usuario (SamAccountName)
.PARAMETER Groups
    Array de nombres de grupos (SamAccountName)
.OUTPUTS
    Hashtable con: success, message, groups_added, errors
.EXAMPLE
    Add-ADUserToGroups -UserName "jdoe" -Groups @("appgroup", "appgroup01")
#>
function Add-ADUserToGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Groups
    )

    try {
        $addedGroups = @()
        $errors      = @()

        foreach ($group in $Groups) {
            try {
                Add-ADGroupMember -Identity $group `
                                  -Members $UserName `
                                  -ErrorAction Stop
                $addedGroups += $group
            }
            catch [Microsoft.ActiveDirectory.Management.ADException] {
                if ($_.Exception.Message -like "*already a member*") {
                    $addedGroups += "$group (ya miembro)"
                }
                else {
                    $errors += "Grupo $group : $($_.Exception.Message)"
                }
            }
        }

        if ($errors.Count -gt 0) {
            return @{
                success      = $false
                message      = "Algunos grupos fallaron"
                groups_added = $addedGroups
                errors       = $errors
            }
        }

        return @{
            success      = $true
            message      = "Usuario $UserName agregado a $($addedGroups.Count) grupos"
            groups_added = $addedGroups
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
    Elimina un usuario de Active Directory
.DESCRIPTION
    Elimina un usuario de forma segura comprobando que existe previamente
.PARAMETER UserName
    Nombre del usuario a eliminar (SamAccountName)
.OUTPUTS
    Hashtable con: success, message
.EXAMPLE
    Remove-ADUserSafe -UserName "jdoe"
#>
function Remove-ADUserSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName
    )

    try {
        Get-ADUser -Identity $UserName -ErrorAction Stop
        Remove-ADUser -Identity $UserName -Confirm:$false -ErrorAction Stop

        return @{
            success  = $true
            message  = "Usuario $UserName eliminado correctamente"
            userName = $UserName
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        return @{
            success    = $false
            error      = "Usuario $UserName no existe en AD"
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
#Export-ModuleMember -Function Test-ADUserExists, Test-ADUIDInUse, New-ADUserWithPosix, Update-ADUserPosixAttributesSafe, Update-ADUserPosixAttributesForce, Add-ADUserToGroups, Remove-ADUserSafe
