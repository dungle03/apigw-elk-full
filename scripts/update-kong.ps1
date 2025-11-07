#Requires -Version 7.0
[CmdletBinding()]
param(
  [switch]$EnsureEnv = $true,
  [string]$PublicIp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$envPath = Join-Path $repoRoot '.env'
$envExamplePath = Join-Path $repoRoot '.env.example'
$renderScript = Join-Path $repoRoot 'scripts/render-kong.ps1'

# 1) Ensure .env exists
if ($EnsureEnv -and -not (Test-Path $envPath)) {
  if (Test-Path $envExamplePath) {
    Copy-Item -Path $envExamplePath -Destination $envPath -Force
    Write-Host "Created .env from .env.example. Please edit PUBLIC_IP if needed." -ForegroundColor Yellow
  } else {
    Write-Host ".env.example not found. Creating minimal .env..." -ForegroundColor Yellow
    @(
      '# Global configuration',
      '# Change this when your VPS IP changes',
      'PUBLIC_IP=<YOUR_VPS_PUBLIC_IP_OR_DOMAIN>'
    ) | Set-Content -Path $envPath -NoNewline:$false
    Write-Host "Created minimal .env at $envPath. Update PUBLIC_IP before rendering if needed." -ForegroundColor Yellow
  }
}

# 1b) Optionally set/override PUBLIC_IP via parameter
if ($PublicIp) {
  $envLines = @()
  if (Test-Path $envPath) {
    $envLines = Get-Content -Path $envPath
  }
  $updated = $false
  $envLines = $envLines | ForEach-Object {
    if ($_ -match '^\s*PUBLIC_IP\s*=') {
      $updated = $true
      "PUBLIC_IP=$PublicIp"
    } else {
      $_
    }
  }
  if (-not $updated) {
    $envLines += "PUBLIC_IP=$PublicIp"
  }
  $envLines | Set-Content -Path $envPath -NoNewline:$false
  Write-Host "PUBLIC_IP set to $PublicIp in .env" -ForegroundColor Green
}

# 1c) Quick check for PUBLIC_IP presence
try {
  $envContent = Get-Content -Path $envPath -ErrorAction Stop
  $currentIp = ($envContent | Where-Object { $_ -match '^\s*PUBLIC_IP\s*=' } | Select-Object -First 1) -replace '^\s*PUBLIC_IP\s*=\s*',''
  if ([string]::IsNullOrWhiteSpace($currentIp) -or $currentIp -like '<*>' ) {
    Write-Warning "PUBLIC_IP is not set to a concrete value in .env. Rendering may use a placeholder."
  } else {
    Write-Host "Using PUBLIC_IP=$currentIp from .env" -ForegroundColor Cyan
  }
} catch {
  Write-Warning "Could not read .env to verify PUBLIC_IP. Proceeding. $_"
}

# 2) Render kong.yml from template
if (-not (Test-Path $renderScript)) {
  throw "Render script not found: $renderScript"
}
& pwsh -NoProfile -ExecutionPolicy Bypass -File $renderScript

#Write-Host "Done. kong/kong.yml has been rendered from template." -ForegroundColor Green

