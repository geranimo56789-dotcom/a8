Param(
  [Parameter(Mandatory=$true)][string]$P12Path,
  [Parameter(Mandatory=$true)][string]$AppStoreKeyPath, # .p8
  [Parameter(Mandatory=$true)][string]$AppStoreIssuerId,
  [Parameter(Mandatory=$true)][string]$AppStoreKeyId
)

Write-Host "Checking GitHub CLI auth..."
gh auth status -h github.com | Out-Null

if (-not (Test-Path $P12Path)) { throw "P12 file not found: $P12Path" }
if (-not (Test-Path $AppStoreKeyPath)) { throw "App Store .p8 file not found: $AppStoreKeyPath" }

$secure = Read-Host "Enter .p12 password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$P12Password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

Write-Host "Encoding .p12 to base64..."
$p12Bytes = [IO.File]::ReadAllBytes($P12Path)
$p12B64 = [Convert]::ToBase64String($p12Bytes)

Write-Host "Setting GitHub Secrets..."
$env:GH_PROMPT = "disabled"
gh secret set IOS_CERT_P12_BASE64 -b "$p12B64"
gh secret set IOS_CERT_PASSWORD -b "$P12Password"
gh secret set APPSTORE_PRIVATE_KEY -f "$AppStoreKeyPath"
gh secret set APPSTORE_ISSUER_ID -b "$AppStoreIssuerId"
gh secret set APPSTORE_KEY_ID -b "$AppStoreKeyId"

Write-Host "All secrets set successfully."
