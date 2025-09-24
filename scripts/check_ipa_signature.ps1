<#!
.SYNOPSIS
  Heuristically inspects an iOS .ipa (on Windows) to classify its signing type.

.DESCRIPTION
  Because Windows cannot run the macOS `codesign` tool, this script performs a
  best‑effort heuristic by inspecting:
    * embedded.mobileprovision (if present)
    * CodeResources for certificate authority strings

  It attempts to classify the IPA as one of:
    - AppStore
    - Development
    - AdHoc
    - Enterprise
    - Unknown

  Exit codes:
    0 = Confirmed / assumed Distribution suitable for App Store (AppStore)
    1 = Script misuse (validation errors)
    2 = IPA file not found
    3 = Payload/.app not found
    4 = Not distribution (Development/AdHoc)
    5 = Extraction failure / unexpected error
    6 = Enterprise (treated separately if you need to block it)
    7 = Unknown (ambiguous – could not classify with confidence)

  NOTE: Only macOS `codesign -dvv <App>.app` is authoritative. Use this script
  as a preflight helper on Windows CI or local checks.

.PARAMETER IpaPath
  Path to the .ipa file.

.PARAMETER WorkDir
  Optional temp extraction directory (will be deleted/recreated).

.PARAMETER Json
  When set, outputs a JSON object with detailed findings instead of human text.

.EXAMPLE
  ./check_ipa_signature.ps1 -IpaPath .\Runner-signed.ipa -Json | ConvertFrom-Json

.EXAMPLE
  powershell -File scripts\check_ipa_signature.ps1 -IpaPath build\Runner.ipa
#>
param(
  [Parameter(Mandatory=$true)] [string]$IpaPath,
  [string]$WorkDir = 'ipa_sig_check',
  [switch]$Json
)

set-strictmode -version latest
$ErrorActionPreference = 'Stop'

function Write-Info($m){ if(-not $Json){ Write-Host "[INFO] $m" -ForegroundColor Cyan } }
function Write-Err($m){ if(-not $Json){ Write-Host "[ERR ] $m" -ForegroundColor Red } }

function Emit-Result {
  param(
    [int]$ExitCode,
    [string]$Classification,
    [string]$Message,
    [hashtable]$Heuristics
  )
  if ($Json) {
    $obj = [ordered]@{
      ipaPath        = (Resolve-Path -LiteralPath $IpaPath -ErrorAction SilentlyContinue).Path
      exitCode       = $ExitCode
      classification = $Classification
      message        = $Message
      heuristics     = $Heuristics
      timestampUtc   = (Get-Date).ToUniversalTime().ToString('o')
    }
    $obj | ConvertTo-Json -Depth 6
  } else {
    if ($ExitCode -eq 0) { Write-Info $Message } else { Write-Err $Message }
    Write-Info "Classification: $Classification";
  }
  exit $ExitCode
}

if (!(Test-Path $IpaPath)) { Emit-Result -ExitCode 2 -Classification 'Unknown' -Message "IPA not found: $IpaPath" -Heuristics @{} }

try {
  if (Test-Path $WorkDir) { Remove-Item -Recurse -Force $WorkDir }
  New-Item -ItemType Directory -Path $WorkDir | Out-Null
  Write-Info "Extracting IPA..."
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($IpaPath, $WorkDir)
} catch {
  Emit-Result -ExitCode 5 -Classification 'Unknown' -Message ("Extraction failed: " + $_.Exception.Message) -Heuristics @{ extraction='failed' }
}

$appPath = Get-ChildItem -Path (Join-Path $WorkDir 'Payload') -Directory | Select-Object -First 1
if (-not $appPath) { Emit-Result -ExitCode 3 -Classification 'Unknown' -Message 'No .app directory found in Payload' -Heuristics @{ payload='missingApp' } }

$heur = @{}

$embeddedProfile = Join-Path $appPath.FullName 'embedded.mobileprovision'
$profileRaw = $null
$hasDevices = $false
$enterprise = $false
$getTaskAllow = $null
if (Test-Path $embeddedProfile) {
  $profileRaw = Get-Content $embeddedProfile -Raw
  $heur.profilePresent = $true
  if ($profileRaw -match 'ProvisionedDevices') { $hasDevices = $true }
  if ($profileRaw -match 'ProvisionsAllDevices') { $enterprise = $true }
  if ($profileRaw -match '<key>get-task-allow</key>\s*<(?<val>true|false)/>') {
    $getTaskAllow = $Matches['val']
  }
  $heur.profileHasDevices = $hasDevices
  $heur.profileEnterprise = $enterprise
  if ($null -ne $getTaskAllow) { $heur.profileGetTaskAllow = $getTaskAllow }
} else {
  $heur.profilePresent = $false
}

$codeResources = Get-ChildItem -Path $appPath.FullName -Recurse -Filter 'CodeResources' | Select-Object -First 1
$crContent = $null
if ($codeResources) {
  $crContent = Get-Content $codeResources.FullName -Raw
  $heur.codeResourcesFound = $true
  $heur.containsAppleDistribution = [bool]($crContent -match 'Apple Distribution')
  $heur.containsAppleDevelopment  = [bool]($crContent -match 'Apple Development')
} else {
  $heur.codeResourcesFound = $false
}

# Classification logic
$classification = 'Unknown'
$exitCode = 7
$message = 'Unable to confidently classify signing.'

if ($enterprise) {
  $classification = 'Enterprise'; $exitCode = 6; $message = 'Enterprise distribution profile detected (ProvisionsAllDevices).' }
elseif ($hasDevices) {
  # Distinguish Development vs AdHoc by presence of Apple Development string and get-task-allow
  if ($heur.containsAppleDevelopment -or ($getTaskAllow -eq 'true')) {
    $classification = 'Development'; $exitCode = 4; $message = 'Development profile (device UDIDs + dev entitlement hints).' }
  else {
    $classification = 'AdHoc'; $exitCode = 4; $message = 'AdHoc distribution (device UDIDs, no dev entitlements).' }
}
else {
  # No device list: either AppStore or ambiguous
  if ($heur.containsAppleDistribution -and -not $heur.containsAppleDevelopment) {
    $classification = 'AppStore'; $exitCode = 0; $message = 'Distribution signature indicator found (Apple Distribution).'
  } elseif ($heur.containsAppleDistribution) {
    $classification = 'AppStore'; $exitCode = 0; $message = 'Apple Distribution present (ignoring Apple Development overlap).'
  }
}

Emit-Result -ExitCode $exitCode -Classification $classification -Message $message -Heuristics $heur