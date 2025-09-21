# Converts an Apple Distribution .cer and matching private key to a password-protected .p12 using OpenSSL.
#
# Usage (PowerShell):
#   scripts/make_ios_p12.ps1
#   scripts/make_ios_p12.ps1 -CerPath "C:\Users\<you>\ios_dist_cert\apple_dist.cer" -KeyPath "C:\Users\<you>\ios_dist_cert\apple_dist.key"
#
# This script prompts for the .p12 password locally (not echoed), then invokes:
#   "C:\Program Files\OpenSSL-Win64\bin\openssl.exe" pkcs12 -export ...

param(
  [string]$CerPath = "$env:USERPROFILE\ios_dist_cert\apple_dist.cer",
  [string]$KeyPath = "$env:USERPROFILE\ios_dist_cert\apple_dist.key",
  [string]$OutPath = "$env:USERPROFILE\ios_dist_cert\apple_dist.p12",
  [string]$OpenSslExe = "C:\\Program Files\\OpenSSL-Win64\\bin\\openssl.exe",
  [string]$CertName = "Apple Distribution"
)

if (-not (Test-Path -LiteralPath $CerPath)) {
  Write-Error "Certificate (.cer) not found: $CerPath"; exit 1
}
if (-not (Test-Path -LiteralPath $KeyPath)) {
  Write-Error "Private key (.key) not found: $KeyPath"; exit 1
}
if (-not (Test-Path -LiteralPath $OpenSslExe)) {
  Write-Error "OpenSSL not found at: $OpenSslExe"; exit 1
}

Write-Host "Using OpenSSL at: $OpenSslExe"
Write-Host "  Cer : $CerPath"
Write-Host "  Key : $KeyPath"
Write-Host "  Out : $OutPath"

# Prompt for password without echoing
$sec = Read-Host "Enter a password for the .p12 (will not echo)" -AsSecureString

# Convert SecureString to plain for OpenSSL (kept in-memory only, not printed)
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try {
  $p12Password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
}
finally {
  if ($bstr -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

& $OpenSslExe pkcs12 -export -inkey $KeyPath -in $CerPath -out $OutPath -name $CertName -passout "pass:$p12Password"
$exit = $LASTEXITCODE

# Attempt to reduce exposure (cannot reliably zero immutable .NET strings)
$p12Password = $null
$sec = $null

if ($exit -ne 0) {
  throw "OpenSSL pkcs12 export failed with exit code $exit"
}

Write-Host "Created: $OutPath"
