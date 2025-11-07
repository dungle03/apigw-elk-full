#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine repo root (parent of this script's directory)
$repoRoot = Split-Path $PSScriptRoot -Parent
$envPath = Join-Path $repoRoot '.env'

$kongTemplatePath = Join-Path $repoRoot 'kong/kong.yml.tmpl'
$kongOutputPath   = Join-Path $repoRoot 'kong/kong.yml'

$realmTemplatePath = Join-Path $repoRoot 'keycloak/realm-export.json.tmpl'
$realmOutputPath   = Join-Path $repoRoot 'keycloak/realm-export.json'

$authTemplatePath = Join-Path $repoRoot 'usersvc/src/auth.service.ts.tmpl'
$authOutputPath   = Join-Path $repoRoot 'usersvc/src/auth.service.ts'

if (-not (Test-Path $envPath)) {
  throw ".env not found at $envPath"
}

# Parse .env into a hashtable
$vars = @{}
Get-Content -Path $envPath | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq '' -or $line.StartsWith('#')) { return }
  $idx = $line.IndexOf('=')
  if ($idx -lt 1) { return }
  $key = $line.Substring(0, $idx).Trim()
  $val = $line.Substring($idx + 1).Trim()
  # Remove surrounding quotes if present
  if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
    $val = $val.Substring(1, $val.Length - 2)
  }
  $vars[$key] = $val
}

if (-not $vars.ContainsKey('PUBLIC_IP')) {
  throw "PUBLIC_IP not found in .env"
}

$publicIp = $vars['PUBLIC_IP']

Write-Host ("Using PUBLIC_IP={0} from .env" -f $publicIp) -ForegroundColor Cyan

# Helper: simple literal ${VAR} replacement
function Render-Template {
  param(
    [Parameter(Mandatory = $true)][string]$TemplatePath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][hashtable]$Variables,
    [string]$Description
  )

  if (-not (Test-Path $TemplatePath)) {
    throw "Template not found: $TemplatePath"
  }

  $content = Get-Content -Path $TemplatePath -Raw

  foreach ($key in $Variables.Keys) {
    $placeholder = '${' + $key + '}'
    $value = $Variables[$key]
    $content = $content.Replace($placeholder, $value)
  }

  $content | Set-Content -Path $OutputPath -NoNewline

  if ($Description) {
    Write-Host ("Rendered {0}: {1} -> {2}" -f $Description, $TemplatePath, $OutputPath) -ForegroundColor Green
  } else {
    Write-Host ("Rendered: {0} -> {1}" -f $TemplatePath, $OutputPath) -ForegroundColor Green
  }
}

# Core variables passed to templates
$templateVars = @{
  'PUBLIC_IP'           = $publicIp
  'KEYCLOAK_REALM_ISS'  = "http://$publicIp`:8080/realms/demo"
  'KEYCLOAK_REALM_BASE' = "http://$publicIp`:8080/realms/demo"
}

# 1) Render kong.yml from template
Render-Template -TemplatePath $kongTemplatePath -OutputPath $kongOutputPath -Variables $templateVars -Description 'kong/kong.yml'

# 2) Render keycloak/realm-export.json (issuer)
if (Test-Path $realmTemplatePath) {
  Render-Template -TemplatePath $realmTemplatePath -OutputPath $realmOutputPath -Variables $templateVars -Description 'keycloak/realm-export.json'
} else {
  Write-Host "realm-export.json.tmpl not found, skipping realm-export.json render." -ForegroundColor Yellow
}

# 3) Render usersvc/src/auth.service.ts (KEYCLOAK_REALM_URL / kcRealmBase)
if (Test-Path $authTemplatePath) {
  Render-Template -TemplatePath $authTemplatePath -OutputPath $authOutputPath -Variables $templateVars -Description 'usersvc/src/auth.service.ts'
} else {
  Write-Host "auth.service.ts.tmpl not found, skipping AuthService render." -ForegroundColor Yellow
}

Write-Host "All render steps completed."
