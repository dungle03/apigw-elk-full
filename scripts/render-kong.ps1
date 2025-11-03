#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine repo root (parent of this script's directory)
$repoRoot = Split-Path $PSScriptRoot -Parent
$envPath = Join-Path $repoRoot '.env'
$templatePath = Join-Path $repoRoot 'kong/kong.yml.tmpl'
$outputPath = Join-Path $repoRoot 'kong/kong.yml'

if (-not (Test-Path $envPath)) {
  throw ".env not found at $envPath"
}
if (-not (Test-Path $templatePath)) {
  throw "Template not found at $templatePath"
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

# Render template: simple ${VAR} replacement (literal, not regex)
$content = Get-Content -Path $templatePath -Raw
$rendered = $content.Replace('${PUBLIC_IP}', $vars['PUBLIC_IP'])

# Write output
$rendered | Set-Content -Path $outputPath -NoNewline

Write-Host "Rendered $templatePath -> $outputPath using PUBLIC_IP=$($vars['PUBLIC_IP'])" -ForegroundColor Green
