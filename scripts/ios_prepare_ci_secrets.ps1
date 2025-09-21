param(
    [string]$Repo
)

# Helper: convert SecureString to plain text
function ConvertFrom-SecureStringPlain {
    param([System.Security.SecureString]$Secure)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Write-Host "Preparing GitHub Actions secrets and variables for iOS CI..." -ForegroundColor Cyan

# Check gh CLI
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "The GitHub CLI ('gh') is not installed or not on PATH. Install from https://github.com/cli/cli and sign in with 'gh auth login'."
    exit 1
}

# Detect repo owner/name if not provided
if (-not $Repo) {
    try {
        $remoteUrl = git config --get remote.origin.url 2>$null
        if ($remoteUrl -match "github.com[:/](.+?)/(.+?)(?:\.git)?$") {
            $Repo = "$($Matches[1])/$($Matches[2])"
        }
    } catch {}
}

if (-not $Repo) {
    $Repo = Read-Host "Enter GitHub repo in owner/name format (e.g. geranimo56789-dotcom/a8)"
}

Write-Host "Using repo: $Repo" -ForegroundColor Yellow

# Required: Bundle ID and Team ID (as repository variables)
$bundleId = Read-Host "Enter iOS Bundle ID (e.g. com.company.app)"
$teamId = Read-Host "Enter Apple Developer Team ID (10 chars)"

if ([string]::IsNullOrWhiteSpace($bundleId) -or [string]::IsNullOrWhiteSpace($teamId)) {
    Write-Error "Bundle ID and Team ID are required."
    exit 1
}

# Set repository variables
& gh variable set IOS_BUNDLE_ID -R $Repo -b "$bundleId"
& gh variable set IOS_DEVELOPMENT_TEAM -R $Repo -b "$teamId"

# Distribution certificate (.p12)
$p12Path = Read-Host "Path to Apple Distribution .p12"
if (-not (Test-Path $p12Path)) { Write-Error ".p12 file not found: $p12Path"; exit 1 }
$p12PassSec = Read-Host -AsSecureString "Password for .p12"
$p12Pass = ConvertFrom-SecureStringPlain $p12PassSec
$p12Bytes = [IO.File]::ReadAllBytes($p12Path)
$p12B64 = [Convert]::ToBase64String($p12Bytes)

& gh secret set IOS_CERT_P12_BASE64 -R $Repo -b "$p12B64"
& gh secret set IOS_CERT_PASSWORD -R $Repo -b "$p12Pass"

# App Store Connect API key (recommended path)
$useApi = Read-Host "Will you use App Store Connect API key for CI? (Y/N)"
if ($useApi -match '^(y|yes)$') {
    $keyId = Read-Host "App Store Connect Key ID"
    $issuerId = Read-Host "App Store Connect Issuer ID"
    $p8Path = Read-Host "Path to API private key (.p8)"
    if (-not (Test-Path $p8Path)) { Write-Error ".p8 file not found: $p8Path"; exit 1 }

    & gh secret set APPSTORE_KEY_ID -R $Repo -b "$keyId"
    & gh secret set APPSTORE_ISSUER_ID -R $Repo -b "$issuerId"
    & gh secret set APPSTORE_PRIVATE_KEY -R $Repo -f "$p8Path"
} else {
    Write-Host "Skipping API key. The workflow will require a provisioning profile or Apple ID uploader creds."
}

# Optional: Manual provisioning profile (App Store distribution profile)
$provPath = Read-Host "Path to App Store provisioning profile (.mobileprovision) [optional, press ENTER to skip]"
if (-not [string]::IsNullOrWhiteSpace($provPath)) {
    if (-not (Test-Path $provPath)) { Write-Error ".mobileprovision not found: $provPath"; exit 1 }
    $provBytes = [IO.File]::ReadAllBytes($provPath)
    $provB64 = [Convert]::ToBase64String($provBytes)
    & gh secret set IOS_MOBILEPROVISION_BASE64 -R $Repo -b "$provB64"
}

# Optional: Apple ID fallback uploader
$appleId = Read-Host "Apple ID for iTMSTransporter upload [optional]"
if (-not [string]::IsNullOrWhiteSpace($appleId)) {
    $appPwdSec = Read-Host -AsSecureString "App-specific password (never your Apple ID password)"
    $appPwd = ConvertFrom-SecureStringPlain $appPwdSec
    $itcProvider = Read-Host "iTunes Connect provider short name [optional]"

    & gh secret set APPLE_ID -R $Repo -b "$appleId"
    & gh secret set APP_SPECIFIC_PASSWORD -R $Repo -b "$appPwd"
    if (-not [string]::IsNullOrWhiteSpace($itcProvider)) {
        & gh secret set ITC_PROVIDER -R $Repo -b "$itcProvider"
    }
}

Write-Host "Done. Secrets and variables set for $Repo." -ForegroundColor Green
Write-Host "Next: push to main or dispatch the 'Build and Upload iOS (TestFlight)' workflow." -ForegroundColor Green
