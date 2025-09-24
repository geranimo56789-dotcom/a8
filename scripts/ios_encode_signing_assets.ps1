<#!
.SYNOPSIS
  Encodes iOS distribution signing assets (p12 + provisioning profile) to base64 for GitHub Actions secrets.

.PARAMETER P12Path
  Path to Apple Distribution .p12 file (exported from Keychain).

.PARAMETER ProvisionProfilePath
  Path to App Store provisioning profile (.mobileprovision).

.PARAMETER OutputDir
  Optional directory to write base64 output files (defaults to current directory).

.EXAMPLE
  ./ios_encode_signing_assets.ps1 -P12Path C:\certs\dist.p12 -ProvisionProfilePath C:\certs\var6_appstore.mobileprovision

After running, copy contents of:
  dist.p12.b64  -> IOS_DIST_CERT_B64
  profile.mobileprovision.b64 -> IOS_PROVISION_PROFILE_B64

Set IOS_DIST_CERT_PASSWORD to the password you used while exporting the .p12
IMPORTANT: Never commit the raw .p12 or provisioning profile to source control.
#>
param(
  [Parameter(Mandatory=$true)] [string]$P12Path,
  [Parameter(Mandatory=$true)] [string]$ProvisionProfilePath,
  [Parameter(Mandatory=$false)] [string]$ApiKeyPath, # Path to AuthKey_xxxxxxxx.p8 OR already-built AuthKey.json
  [Parameter(Mandatory=$false)] [switch]$ApiKeyIsJson, # Indicate if ApiKeyPath points directly to JSON format expected by fastlane
  [Parameter(Mandatory=$false)] [string]$OutputDir = (Get-Location).Path
)

set-strictmode -version latest
$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERR ] $msg" -ForegroundColor Red }

if (!(Test-Path $P12Path)) { Write-Err "P12 file not found: $P12Path"; exit 1 }
if (!(Test-Path $ProvisionProfilePath)) { Write-Err "Provisioning profile not found: $ProvisionProfilePath"; exit 1 }
if (!(Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$p12Out = Join-Path $OutputDir 'dist.p12.b64'
$profileOut = Join-Path $OutputDir 'profile.mobileprovision.b64'
$apiOut = if ($ApiKeyPath) { Join-Path $OutputDir 'appstore_api_key.json.b64' } else { $null }

Write-Info "Encoding $P12Path -> $p12Out"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($P12Path)) | Out-File -Encoding ascii $p12Out

Write-Info "Encoding $ProvisionProfilePath -> $profileOut"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($ProvisionProfilePath)) | Out-File -Encoding ascii $profileOut

if ($ApiKeyPath) {
  if (!(Test-Path $ApiKeyPath)) { Write-Err "API key path not found: $ApiKeyPath"; exit 1 }
  Write-Info "Encoding $ApiKeyPath -> $apiOut"
  if ($ApiKeyIsJson) {
    # Directly base64 the JSON file
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($ApiKeyPath)) | Out-File -Encoding ascii $apiOut
  } else {
    # Assume .p8 private key; wrap into minimal JSON user must edit for issuer/key id
    $rawP8 = Get-Content $ApiKeyPath -Raw
    $escaped = ($rawP8 -replace "\r", '') -replace "\n","\\n"
    $templateJson = @"
{
  \"key_id\": \"CHANGE_KEY_ID\",
  \"issuer_id\": \"CHANGE_ISSUER_ID\",
  \"key\": \"$escaped\"
}
"@
    $tmpJson = Join-Path $OutputDir 'AuthKey_template.json'
    $templateJson | Out-File -Encoding utf8 $tmpJson
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($tmpJson)) | Out-File -Encoding ascii $apiOut
    Write-Warn "Generated AuthKey_template.json. Edit key_id & issuer_id then (optionally) re-run with -ApiKeyPath that JSON and -ApiKeyIsJson to get final base64."
  }
}

# Attempt lightweight validation of provisioning profile type and bundle id
try {
  $raw = [IO.File]::ReadAllBytes($ProvisionProfilePath)
  $text = [System.Text.Encoding]::UTF8.GetString($raw)
  if ($text -match 'ProvisionedDevices') { Write-Warn 'Profile appears to contain device UDIDs (development/ad-hoc). Ensure you are using an App Store profile without UDIDs.' }
  if ($text -match '<key>ExpirationDate</key>') { Write-Info 'Found expiration metadata.' }
  if ($text -match '<key>Entitlements</key>') { Write-Info 'Entitlements block detected.' }
} catch { Write-Warn "Could not parse provisioning profile text: $_" }

Write-Info "DONE. Suggested GitHub Actions secrets:"
Write-Host ("  IOS_P12_BASE64                : contents of {0}" -f $p12Out) -ForegroundColor Green
Write-Host ("  IOS_MOBILEPROVISION_BASE64    : contents of {0}" -f $profileOut) -ForegroundColor Green
if ($ApiKeyPath) {
  Write-Host ("  APP_STORE_CONNECT_API_KEY_JSON_BASE64 : contents of {0}" -f $apiOut) -ForegroundColor Green
}
Write-Host "  IOS_P12_PASSWORD              : your .p12 export password" -ForegroundColor Green

# Optional: basic certificate type hint (requires OpenSSL if installed) – skipped on Windows by default.
try {
  $hasOpenSSL = $null -ne (Get-Command openssl -ErrorAction SilentlyContinue)
  if ($hasOpenSSL) {
    Write-Info 'Attempting to inspect certificate (may prompt for password if encrypted).'
    $tmpCert = Join-Path $env:TEMP 'dist_cert_inspect.txt'
    # Extract certificate info without exposing key: this command will fail if password wrong; we ignore errors.
    & openssl pkcs12 -in $P12Path -clcerts -nokeys -nodes -passin pass:INVALID 2>$tmpCert | Out-Null
    $content = Get-Content $tmpCert -Raw
    if ($content -match 'Apple Distribution') { Write-Info 'Apple Distribution certificate string detected.' }
    Remove-Item $tmpCert -Force -ErrorAction SilentlyContinue
  }
} catch { Write-Warn 'OpenSSL inspection skipped.' }

Write-Info 'All done.'