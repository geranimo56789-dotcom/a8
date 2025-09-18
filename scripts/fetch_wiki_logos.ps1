param(
    [int]$Width = 96
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

function Ensure-Folder {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $root '..')
$assetsDir = Join-Path $projectRoot 'assets\logos\clubs'
Ensure-Folder -Path $assetsDir

function Get-WikiThumbUrl {
    param([string]$PageTitle, [int]$Width)
    $encoded = [uri]::EscapeDataString($PageTitle)
    $url = "https://en.wikipedia.org/api/rest_v1/page/summary/$encoded"
    try {
        $json = Invoke-RestMethod -Method GET -Uri $url -Headers @{ 'User-Agent' = 'Mozilla/5.0 (logo-fetcher) Powershell' }
    } catch { return $null }
    if ($json.thumbnail -and $json.thumbnail.source) {
        $src = [string]$json.thumbnail.source
        # Normalize width to requested size if 'width' param exists; otherwise append
        if ($src -match "[?&]width=\d+") {
            return ($src -replace "width=\d+", "width=$Width")
        } else {
            if ($src.Contains('?')) { return "$src&width=$Width" } else { return "$src?width=$Width" }
        }
    }
    return $null
}

# ~50 clubs (codes + Wikipedia page titles)
$clubs = @(
    @{ Code='MCI'; Title='Manchester City F.C.'; Url='https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Manchester_City_FC_badge.svg/120px-Manchester_City_FC_badge.svg.png' }
    @{ Code='ARS'; Title='Arsenal F.C.'; Url='https://upload.wikimedia.org/wikipedia/en/thumb/5/53/Arsenal_FC.svg/120px-Arsenal_FC.svg.png' }
    @{ Code='RMA'; Title='Real Madrid CF'; Url='https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Real_Madrid_CF.svg/120px-Real_Madrid_CF.svg.png' }
    @{ Code='BAR'; Title='FC Barcelona'; Url='https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/120px-FC_Barcelona_%28crest%29.svg.png' }
    @{ Code='LIV'; Title='Liverpool F.C.'; Url='https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Liverpool_FC.svg/120px-Liverpool_FC.svg.png' }
    @{ Code='MUN'; Title='Manchester United F.C.' }
    @{ Code='CHE'; Title='Chelsea F.C.'; Url='https://upload.wikimedia.org/wikipedia/en/thumb/c/cc/Chelsea_FC.svg/120px-Chelsea_FC.svg.png' }
    @{ Code='TOT'; Title='Tottenham Hotspur F.C.' }
    @{ Code='PSG'; Title='Paris Saint-Germain F.C.' }
    @{ Code='BAY'; Title='FC Bayern Munich' }
    @{ Code='B04'; Title='Bayer 04 Leverkusen' }
    @{ Code='BVB'; Title='Borussia Dortmund' }
    @{ Code='RBL'; Title='RB Leipzig' }
    @{ Code='ATM'; Title='Atlético Madrid' }
    @{ Code='SEV'; Title='Sevilla FC' }
    @{ Code='VIL'; Title='Villarreal CF' }
    @{ Code='RSO'; Title='Real Sociedad' }
    @{ Code='ATH'; Title='Athletic Bilbao' }
    @{ Code='VAL'; Title='Valencia CF' }
    @{ Code='JUV'; Title='Juventus F.C.' }
    @{ Code='INT'; Title='Inter Milan' }
    @{ Code='MIL'; Title='A.C. Milan' }
    @{ Code='NAP'; Title='S.S.C. Napoli' }
    @{ Code='ROM'; Title='A.S. Roma' }
    @{ Code='LAZ'; Title='S.S. Lazio' }
    @{ Code='ATA'; Title='Atalanta B.C.' }
    @{ Code='NEW'; Title='Newcastle United F.C.' }
    @{ Code='BHA'; Title='Brighton & Hove Albion F.C.' }
    @{ Code='AVL'; Title='Aston Villa F.C.' }
    @{ Code='BOG'; Title='Bologna F.C. 1909' }
    @{ Code='AJX'; Title='AFC Ajax' }
    @{ Code='PSV'; Title='PSV Eindhoven' }
    @{ Code='FEY'; Title='Feyenoord' }
    @{ Code='BEN'; Title='S.L. Benfica' }
    @{ Code='POR'; Title='FC Porto' }
    @{ Code='SCP'; Title='Sporting CP' }
    @{ Code='GAL'; Title='Galatasaray S.K.' }
    @{ Code='FEN'; Title='Fenerbahçe S.K.' }
    @{ Code='BES'; Title='Beşiktaş J.K.' }
    @{ Code='MON'; Title='AS Monaco FC' }
    @{ Code='LYO'; Title='Olympique Lyonnais' }
    @{ Code='MAR'; Title='Olympique de Marseille' }
    @{ Code='LIL'; Title='Lille OSC' }
    @{ Code='SAL'; Title='FC Red Bull Salzburg' }
    @{ Code='CEL'; Title='Celtic F.C.' }
    @{ Code='RAN'; Title='Rangers F.C.' }
    @{ Code='ALK'; Title='Al Nassr FC' }
    @{ Code='HIL'; Title='Al Hilal SFC' }
    @{ Code='SAI'; Title='São Paulo FC' }
)

$ok = 0; $fail = 0
foreach ($c in $clubs) {
    $code = $c.Code
    $title = $c.Title
    Write-Host "Processing $code - $title"
    try {
        $url = $null
        if ($c.ContainsKey('Url') -and $c.Url) { $url = $c.Url }
        if (-not $url) { $url = Get-WikiThumbUrl -PageTitle $title -Width $Width }
        if (-not $url) { throw "No thumbnail URL" }
        $outPath = Join-Path $assetsDir ("{0}.png" -f $code.ToLower())
        Write-Host "  URL: $url"
        Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing -Headers @{ 'User-Agent' = 'Mozilla/5.0 (logo-fetcher) Powershell' }
        Write-Host "  -> saved $outPath"
        $ok++
    }
    catch {
        Write-Warning "  !! failed for $code ($title): $_"
        $fail++
    }
}

Write-Host "Done. Success: $ok, Failed: $fail"
