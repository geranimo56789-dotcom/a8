Param(
  [Parameter(Mandatory=$false)][string]$FilePath = "scripts/ios_signing_secrets.txt"
)

function Parse-KVFile([string]$Path) {
  $result = @{}
  Get-Content -Path $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line) { return }
    if ($line.StartsWith('#')) { return }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { return }
    $k = $line.Substring(0, $idx).Trim()
    $v = $line.Substring($idx+1).Trim()
    $result[$k] = $v
  }
  return $result
}

Write-Host "Checking GitHub CLI auth..."
gh auth status -h github.com | Out-Null

if (-not (Test-Path -LiteralPath $FilePath)) {
  throw "File not found: $FilePath (copy scripts/ios_signing_secrets.example.txt to scripts/ios_signing_secrets.txt and fill it)"
}

$cfg = Parse-KVFile -Path $FilePath

function Require([string]$Key) {
  if (-not $cfg.ContainsKey($Key) -or -not $cfg[$Key]) {
    throw "Missing required key '$Key' in $FilePath"
  }
}

Require 'P12_PATH'
Require 'P12_PASSWORD'
Require 'APPSTORE_P8_PATH'
Require 'APPSTORE_ISSUER_ID'
Require 'APPSTORE_KEY_ID'

$p12Path = $cfg['P12_PATH']
$p12Password = $cfg['P12_PASSWORD']
$p8Path = $cfg['APPSTORE_P8_PATH']
$issuer = $cfg['APPSTORE_ISSUER_ID']
$keyId = $cfg['APPSTORE_KEY_ID']

if (-not (Test-Path -LiteralPath $p12Path)) { throw "P12 not found: $p12Path" }
if (-not (Test-Path -LiteralPath $p8Path)) { throw "P8 not found: $p8Path" }

if ($cfg.ContainsKey('IOS_BUNDLE_ID') -and $cfg['IOS_BUNDLE_ID']) {
  gh variable set IOS_BUNDLE_ID -b "$($cfg['IOS_BUNDLE_ID'])"
}
if ($cfg.ContainsKey('IOS_DEVELOPMENT_TEAM') -and $cfg['IOS_DEVELOPMENT_TEAM']) {
  gh variable set IOS_DEVELOPMENT_TEAM -b "$($cfg['IOS_DEVELOPMENT_TEAM'])"
}

Write-Host "Encoding .p12 to base64..."
$p12B64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p12Path))

Write-Host "Setting GitHub Secrets from $FilePath ..."
$env:GH_PROMPT = "disabled"
gh secret set IOS_CERT_P12_BASE64 -b "$p12B64"
gh secret set IOS_CERT_PASSWORD -b "$p12Password"
gh secret set APPSTORE_PRIVATE_KEY -f "$p8Path"
gh secret set APPSTORE_ISSUER_ID -b "$issuer"
gh secret set APPSTORE_KEY_ID -b "$keyId"

Write-Host "All secrets set successfully from file." -ForegroundColor Green
