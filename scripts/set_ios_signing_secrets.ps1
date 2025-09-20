function Read-NonEmpty([string]$Prompt) {
  while ($true) {
    $v = Read-Host $Prompt
    if ($v -and $v.Trim().Length -gt 0) { return $v.Trim() }
    Write-Host "Value cannot be empty. Please try again." -ForegroundColor Yellow
  }
}

function Read-ExistingFile([string]$Prompt) {
  while ($true) {
    $p = Read-Host $Prompt
    if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
    Write-Host "File not found: $p" -ForegroundColor Yellow
  }
}

function Maybe-Set([string]$key, [string]$value) {
  if ($value -and $value.Trim().Length -gt 0) {
    gh secret set $key -b "$value"
  }
}

Write-Host "Checking GitHub CLI auth..."
gh auth status -h github.com | Out-Null

# Optional: set variables too
$setVars = Read-Host "Set non-sensitive Variables IOS_BUNDLE_ID/IOS_DEVELOPMENT_TEAM? (y/n)"
if ($setVars -match '^(y|Y)') {
  $bundle = Read-Host "IOS_BUNDLE_ID (e.g. com.yourcompany.app)"
  if ($bundle) { gh variable set IOS_BUNDLE_ID -b "$bundle" }
  $team = Read-Host "IOS_DEVELOPMENT_TEAM (10-char Team ID)"
  if ($team) { gh variable set IOS_DEVELOPMENT_TEAM -b "$team" }
}

# Required certificate (.p12)
$P12Path = Read-ExistingFile "Enter FULL PATH to your Apple Distribution .p12 file"
$sec = Read-Host "Enter .p12 password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$P12Password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

Write-Host "Encoding .p12 to base64..."
$p12Bytes = [IO.File]::ReadAllBytes($P12Path)
$p12B64 = [Convert]::ToBase64String($p12Bytes)

$env:GH_PROMPT = "disabled"
gh secret set IOS_CERT_P12_BASE64 -b "$p12B64"
gh secret set IOS_CERT_PASSWORD -b "$P12Password"

# Optional provisioning profile (base64) for non-API-key flow
$useProfile = Read-Host "Do you want to provide a provisioning profile (.mobileprovision) file now? (y/n)"
if ($useProfile -match '^(y|Y)') {
  $profPath = Read-ExistingFile "Enter FULL PATH to your iOS App Store provisioning profile (.mobileprovision)"
  Write-Host "Encoding provisioning profile to base64..."
  $profB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($profPath))
  gh secret set IOS_MOBILEPROVISION_BASE64 -b "$profB64"
}

Write-Host "Choose upload auth method:" -ForegroundColor Cyan
Write-Host "  1) App Store Connect API Key (.p8)" -ForegroundColor Cyan
Write-Host "  2) Apple ID + App-specific password" -ForegroundColor Cyan
$choice = Read-Host "Enter 1 or 2"

if ($choice -eq '1') {
  $AppStoreKeyPath = Read-ExistingFile "Enter FULL PATH to your App Store Connect API key .p8 file"
  $AppStoreIssuerId = Read-NonEmpty "Enter your App Store Connect Issuer ID"
  $AppStoreKeyId = Read-NonEmpty "Enter your App Store Connect Key ID"

  Write-Host "Setting API key secrets..."
  gh secret set APPSTORE_PRIVATE_KEY -f "$AppStoreKeyPath"
  gh secret set APPSTORE_ISSUER_ID -b "$AppStoreIssuerId"
  gh secret set APPSTORE_KEY_ID -b "$AppStoreKeyId"
  Write-Host "All secrets set successfully (API Key)." -ForegroundColor Green
}
elseif ($choice -eq '2') {
  $appleId = Read-NonEmpty "Enter your Apple ID (email)"
  $appPwdSec = Read-Host "Enter your App-specific password (from appleid.apple.com)" -AsSecureString
  $appPwdBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($appPwdSec)
  $appPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($appPwdBstr)
  $provider = Read-Host "Optional: Enter ITC provider short name (if your Apple ID has multiple teams)"

  Write-Host "Setting Apple ID upload secrets..."
  gh secret set APPLE_ID -b "$appleId"
  gh secret set APP_SPECIFIC_PASSWORD -b "$appPassword"
  if ($provider) { gh secret set ITC_PROVIDER -b "$provider" }
  Write-Host "All secrets set successfully (Apple ID)." -ForegroundColor Green
}
else {
  Write-Host "Invalid choice. You can re-run this script to set upload credentials." -ForegroundColor Yellow
}
