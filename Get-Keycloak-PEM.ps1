<#
.SYNOPSIS
    Fetches the JWKS from a Keycloak realm, finds the signature key,
    and converts it to PEM format.

.DESCRIPTION
    This script connects to the specified Keycloak certs endpoint,
    parses the JSON Web Key Set (JWKS), filters for the key used
    for signing ('sig'), and then constructs and outputs the
    corresponding RSA Public Key in PEM format.

.PARAMETER RealmUrl
    The base URL of the Keycloak realm.
    Example: http://13.250.36.84:8080/realms/demo

.EXAMPLE
    .\Get-Keycloak-PEM.ps1 -RealmUrl http://13.250.36.84:8080/realms/demo
#>
param(
    [Parameter(Mandatory=$false)]
    [string]$RealmUrl = "http://13.250.36.84:8080/realms/demo"
)

# Helper function to convert from Base64Url to a standard Base64 string
function Convert-Base64Url-ToBase64($base64Url) {
    $base64 = $base64Url.Replace('-', '+').Replace('_', '/')
    switch ($base64.Length % 4) {
        2 { $base64 += '==' }
        3 { $base64 += '=' }
    }
    return $base64
}

try {
    Write-Host "Fetching keys from Keycloak..."
    $jwksUrl = "$($RealmUrl.TrimEnd('/'))/protocol/openid-connect/certs"
    $response = Invoke-RestMethod -Uri $jwksUrl -Method Get

    # Find the key used for signing ("use": "sig")
    $sigKey = $response.keys | Where-Object { $_.use -eq 'sig' }

    if (-not $sigKey) {
        throw "No signature key ('use: sig') found in the JWKS response."
    }

    # We only need the first signature key if there are multiple
    $jwk = $sigKey[0]

    if ($jwk.kty -ne 'RSA') {
        throw "Signature key is not an RSA key. Found type: $($jwk.kty)"
    }

    Write-Host "Found RSA signature key. Converting to PEM..."

    # Convert the Modulus (n) and Exponent (e) from Base64Url to byte arrays
    $modulusBytes = [System.Convert]::FromBase64String((Convert-Base64Url-ToBase64 $jwk.n))
    $exponentBytes = [System.Convert]::FromBase64String((Convert-Base64Url-ToBase64 $jwk.e))

    # Create RSA parameters
    $rsaParams = New-Object System.Security.Cryptography.RSAParameters
    $rsaParams.Modulus = $modulusBytes
    $rsaParams.Exponent = $exponentBytes

    # Import parameters into an RSA crypto provider
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportParameters($rsaParams)

    # Export the public key in PEM format
    $pemKey = $rsa.ExportSubjectPublicKeyInfo()
    $pemString = "-----BEGIN PUBLIC KEY-----`n"
    $pemString += [System.Convert]::ToBase64String($pemKey, 'InsertLineBreaks')
    $pemString += "`n-----END PUBLIC KEY-----"

    Write-Host "`n--- COPY THE PEM KEY BELOW ---`n" -ForegroundColor Green
    Write-Output $pemString
    Write-Host "`n--- END OF PEM KEY ---`n" -ForegroundColor Green

}
catch {
    Write-Error "An error occurred: $_"
}
