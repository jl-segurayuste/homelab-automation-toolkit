<#
.SYNOPSIS
    Calcula el siguiente nombre de usuario disponible en Active Directory.

.DESCRIPTION
    Dado un SamAccountName que ya existe en Active Directory, determina el
    siguiente nombre de usuario disponible siguiendo la nomenclatura establecida.

    Reglas de numeración:
    - El usuario base sin dígito (ej.: jdoe) propone jdoe01, jdoe02...
    - El usuario con sufijo numérico (ej.: jdoe01) propone jdoe02, jdoe03...
    - Agotado el rango numérico 01-99 se pasa al alfabético a-z

    Secuencia de propuesta:
    - jdoe   -> jdoe01, jdoe02 ... jdoe99 -> jdoea, jdoeb ... jdoez
    - jdoe01 -> jdoe02, jdoe03 ... jdoe99 -> jdoea, jdoeb ... jdoez
    - jdoe99 -> jdoea, jdoeb ... jdoez
    - asmith   -> asmith01, asmith02 ... (base es el nombre completo)

.PARAMETER UserName
    SamAccountName del usuario que ya existe en Active Directory.

.OUTPUTS
    Objeto (JSON) con las siguientes propiedades:
    - next_username : Siguiente nombre de usuario disponible
    - found         : Booleano que indica si se encontró un candidato
    - error         : Mensaje de error si no se encontró ningún candidato válido

.EXAMPLE
    Get-NextAvailableUsername -UserName "jdoe"
    Get-NextAvailableUsername -UserName "jdoe01"
    Get-NextAvailableUsername -UserName "asmith"
#>
function Get-NextAvailableUsername {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName
    )

    # Detectar únicamente sufijo numérico de 2 dígitos al final del nombre
    # Para usuarios sin dígito la base es el nombre completo y se empieza en 01
    # El sufijo alfabético solo se alcanza tras agotar el rango numérico,
    # nunca como punto de entrada
    $numericMatch = [regex]::Match($UserName, '^(.+?)(\d{2})$')

    if ($numericMatch.Success) {
        # Usuario con sufijo numérico: jdoe01 -> base=jdoe, siguiente=02
        $base     = $numericMatch.Groups[1].Value
        $startNum = [int]$numericMatch.Groups[2].Value + 1
    } else {
        # Usuario sin sufijo numérico: jdoe o asmith -> base=nombre completo, siguiente=01
        $base     = $UserName
        $startNum = 1
    }

    # Buscar en rango numérico 01-99
    if ($startNum -le 99) {
        for ($i = $startNum; $i -le 99; $i++) {
            $candidate = $base + $i.ToString("D2")
            $exists = Get-ADUser -Filter "SamAccountName -eq '$candidate'" `
                                 -ErrorAction SilentlyContinue
            if (-not $exists) {
                return @{
                    found         = $true
                    next_username = $candidate
                }
            }
        }
    }

    # Agotado rango numérico, buscar en rango alfabético a-z
    for ($c = [byte][char]'a'; $c -le [byte][char]'z'; $c++) {
        $candidate = $base + [char]$c
        $exists = Get-ADUser -Filter "SamAccountName -eq '$candidate'" `
                             -ErrorAction SilentlyContinue
        if (-not $exists) {
            return @{
                found         = $true
                next_username = $candidate
            }
        }
    }

    # Sin candidatos disponibles en ningún rango
    return @{
        found         = $false
        next_username = ""
        error         = "No se encontró ningún nombre disponible para la base '$base'. Rango numérico (01-99) y alfabético (a-z) agotados."
    }
}
