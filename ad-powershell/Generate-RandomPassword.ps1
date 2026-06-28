#Requires -Version 5.1

# =============================================================================
# GENERACIÓN DE PASSWORDS ALEATORIAS PARA ACTIVE DIRECTORY
# Rol: user_management
# Propósito: Generar passwords seguras que cumplan políticas de AD
# =============================================================================

<#
.SYNOPSIS
    Genera una password aleatoria válida según políticas de AD
.DESCRIPTION
    Genera password con al menos:
    - 1 letra mayúscula (A-Z)
    - 1 letra minúscula (a-z)
    - 1 número (0-9)
    - 1 carácter especial
    - Longitud mínima 8 caracteres

    Valida que la password NO contenga el nombre de usuario
    Reintenta hasta 50 veces si no cumple requisitos

    Algoritmo Fisher-Yates para desordenar caracteres
.PARAMETER Length
    Longitud de la password (mínimo 8, máximo 128, por defecto 15)
.PARAMETER Username
    Nombre del usuario (para validar que password no lo contenga)
.OUTPUTS
    Hashtable con:
    - success (bool): true si se generó correctamente
    - password (string): password generada (solo si success=true)
    - attempts (int): número de intentos necesarios
    - error (string): mensaje de error (solo si success=false)
.EXAMPLE
    Generate-RandomPassword -Length 15 -Username "jdoe"

    Retorna:
    @{
        success  = $true
        password = "<password-generada>"
        attempts = 3
    }
.EXAMPLE
    Generate-RandomPassword -Length 12 -Username "asmith"

    Genera password de 12 caracteres que no contiene "asmith"
.NOTES
    Author: homelab-automation-toolkit
    Version: 1.1
    Corrección: uso de [regex]::Escape para evitar WildcardPatternException
    con contraseñas que contienen caracteres especiales como * [ ]
#>
function Generate-RandomPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateRange(8, 128)]
        [int]$Length = 15,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Username
    )

    # Número máximo de intentos
    $maxAttempts = 50
    $attempt     = 0

    do {
        $attempt++

        # Definir conjuntos de caracteres
        $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        $lowercase = "abcdefghijklmnopqrstuvwxyz"
        $numbers   = "0123456789"
        $specials  = "~!@#$%&*_-+=|()[]:;<>,."

        # Paso 1: Asegurar al menos un carácter de cada tipo (requisito de AD)
        $password  = @()
        $password += $uppercase[(Get-Random -Maximum $uppercase.Length)]
        $password += $lowercase[(Get-Random -Maximum $lowercase.Length)]
        $password += $numbers[(Get-Random -Maximum $numbers.Length)]
        $password += $specials[(Get-Random -Maximum $specials.Length)]

        # Paso 2: Rellenar el resto con caracteres aleatorios
        $allChars = $uppercase + $lowercase + $numbers + $specials
        for ($i = $password.Count; $i -lt $Length; $i++) {
            $password += $allChars[(Get-Random -Maximum $allChars.Length)]
        }

        # Paso 3: Desordenar la password usando algoritmo Fisher-Yates
        for ($i = $password.Count - 1; $i -gt 0; $i--) {
            $j        = Get-Random -Maximum ($i + 1)
            $temp     = $password[$i]
            $password[$i] = $password[$j]
            $password[$j] = $temp
        }

        # Convertir array a string
        $passwordString = -join $password

        # Paso 4: Validar password según políticas de AD
        $hasLowercase = $passwordString -cmatch '[a-z]'
        $hasUppercase = $passwordString -cmatch '[A-Z]'
        $hasNumber    = $passwordString -match '\d'
        $hasSpecial   = $passwordString -ne ($passwordString -replace '[^0-9a-zA-Z]', '')
        $minLength    = $passwordString.Length -ge 8

        # Validar que la password NO contiene el username
        # Se usa [regex]::Escape para evitar WildcardPatternException cuando
        # la password contiene caracteres especiales como * [ ] que PowerShell
        # podría interpretar como wildcards con el operador -like
        $notContainsUsername = $passwordString -notmatch [regex]::Escape($Username)

        # Si cumple TODAS las validaciones retornar éxito
        if ($hasLowercase -and $hasUppercase -and $hasNumber -and $hasSpecial -and $minLength -and $notContainsUsername) {
            return @{
                success  = $true
                password = $passwordString
                attempts = $attempt
            }
        }

    } while ($attempt -lt $maxAttempts)

    # Si llegamos aquí fallaron todos los intentos
    return @{
        success  = $false
        error    = "No se pudo generar password válida después de $maxAttempts intentos"
        attempts = $attempt
    }
}
