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

Write-Host "Checking GitHub CLI auth..."
gh auth status -h github.com | Out-Null

$P12Path = Read-ExistingFile "Enter FULL PATH to your Apple Distribution .p12 file"
$sec = Read-Host "Enter .p12 password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$P12Password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

$AppStoreKeyPath = Read-ExistingFile "Enter FULL PATH to your App Store Connect API key .p8 file"
$AppStoreIssuerId = Read-NonEmpty "Enter your App Store Connect Issuer ID"
$AppStoreKeyId = Read-NonEmpty "Enter your App Store Connect Key ID"

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

Write-Host "All secrets set successfully." -ForegroundColor Green
