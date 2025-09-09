<#
Run this script in an elevated PowerShell (Run as Administrator)
1) Imports the signing certificate (for dev/testing with self-signed cert)
2) Installs the app via App Installer (.appinstaller)
   - If App Installer path fails, falls back to installing the MSIX directly
#>

$ErrorActionPreference = "Stop"

# Ensure TLS 1.2 for downloads
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$BaseUrl = "https://epl-3-the-brief.web.app"
$CerUrl  = "$BaseUrl/BrieFly.cer"               # Upload your public cert as BrieFly.cer next to this script
$AppUrl  = "$BaseUrl/BrieFly.appinstaller"
$MsixUrl = "$BaseUrl/BrieFly_1.0.0.0_x64.msix"  # Update this when you bump version

$TempDir = Join-Path $env:TEMP "BrieFlyInstall"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

$CerPath  = Join-Path $TempDir "BrieFly.cer"
$AppPath  = Join-Path $TempDir "BrieFly.appinstaller"
$MsixPath = Join-Path $TempDir "BrieFly.msix"

Write-Host "Downloading certificate..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $CerUrl -OutFile $CerPath

Write-Host "Importing certificate to CurrentUser\\TrustedPeople..." -ForegroundColor Cyan
Import-Certificate -FilePath $CerPath -CertStoreLocation Cert:\CurrentUser\TrustedPeople | Out-Null

Write-Host "Downloading appinstaller..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $AppUrl -OutFile $AppPath

Write-Host "Installing via App Installer (.appinstaller)..." -ForegroundColor Cyan
try {
  # Correct parameter name is -ForceApplicationShutdown
  Add-AppxPackage -AppInstallerFile $AppPath -ForceApplicationShutdown
  Write-Host "Installed successfully via App Installer." -ForegroundColor Green
}
catch {
  Write-Warning "App Installer path failed: $($_.Exception.Message)"
  Write-Host "Falling back to direct MSIX install..." -ForegroundColor Yellow

  Write-Host "Downloading MSIX..." -ForegroundColor Cyan
  Invoke-WebRequest -Uri $MsixUrl -OutFile $MsixPath

  # Try direct MSIX install
  Add-AppxPackage -Path $MsixPath -ForceApplicationShutdown
  Write-Host "Installed successfully via direct MSIX." -ForegroundColor Green
}

Write-Host "Done. You can launch the app from the Start menu." -ForegroundColor Green
