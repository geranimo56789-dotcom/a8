Param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the .mobileprovision file")]
    [string]$ProfilePath,

    [Parameter(Mandatory = $true, HelpMessage = "GitHub repository in owner/name format")]
    [string]$Repo,

    [Parameter(Mandatory = $false, HelpMessage = "Secret name to set (defaults to IOS_MOBILEPROVISION_BASE64)")]
    [string]$SecretName = 'IOS_MOBILEPROVISION_BASE64'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ProfilePath)) {
    Write-Error "Provisioning profile not found at: $ProfilePath"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI 'gh' not found. Install from https://cli.github.com/ and run 'gh auth login' first."
}

if (-not ($Repo -match '^[^/]+/[^/]+$')) {
    Write-Error "Repo must be in 'owner/name' format. Got: '$Repo'"
}

Write-Host "Reading profile: $ProfilePath"
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ProfilePath))
$b64 = [System.Convert]::ToBase64String($bytes)

Write-Host "Setting secret '$SecretName' in repo '$Repo' via GitHub CLI..."
# Use --body to avoid env-file parsing; pass raw base64 as the secret value.
gh secret set $SecretName -R $Repo --body $b64 | Write-Host

Write-Host "Done. Secret '$SecretName' updated for $Repo."
