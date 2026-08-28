# Photos v3 : renders officiels WWE.com (og:image + original) pour les manquants ET les basse-res,
# fallback Wikimedia Commons. Puis build-data.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$imgDir = Join-Path $root 'images'
$tmp = Join-Path $env:TEMP 'wwe-img-tmp'
if (-not (Test-Path $tmp)) { New-Item -ItemType Directory -Force $tmp | Out-Null }
$uaWeb = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$uaWiki = 'WWEFaceOffBot/2.0 (local one-shot fan project) PowerShell/5.1'

$rows = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'roster.csv') | ConvertFrom-Csv
function Get-Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
  }
  ($sb.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')
}
$nameBySlug = @{}
foreach ($r in $rows) { $nameBySlug[(Get-Slug $r.name)] = $r.name }

# cibles : sans image OU image < 450px
$targets = @()
foreach ($r in $rows) {
  $slug = Get-Slug $r.name
  $f = Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $f) { $targets += $slug; continue }
  try {
    $im = [System.Drawing.Image]::FromFile($f.FullName)
    if ($im.Width -lt 450 -or $im.Height -lt 450) { $targets += $slug }
    $im.Dispose()
  } catch { $targets += $slug }
}
Write-Host ("CIBLES ({0}): {1}" -f $targets.Count, ($targets -join ', '))

$wweAlt = @{
  'humberto-carrillo' = @('humberto-carrillo','humberto','berto')
  'hardcore-holly'    = @('hardcore-holly','bob-holly')
  'ted-dibiase-jr'    = @('ted-dibiase')
  'snitsky'           = @('snitsky','gene-snitsky')
  'tensai'            = @('tensai','lord-tensai')
  'kristal-marshall'  = @('kristal','kristal-marshall')
  'andrade'           = @('andrade','andrade-cien-almas')
  'john-morrison'     = @('john-morrison')
  'eugene'            = @('eugene')
}

function Save-IfGood([string]$url, [string]$slug, [int]$minW) {
  if (-not $url) { return $false }
  $ext = 'jpg'
  if ($url -match '\.(jpe?g|png|webp)(?:$|\?)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $tf = Join-Path $tmp "$slug.$ext"
  try {
    Invoke-WebRequest -Uri $url -OutFile $tf -Headers @{ 'User-Agent' = $uaWeb; 'Referer' = 'https://www.wwe.com/' } -TimeoutSec 60 -UseBasicParsing
  } catch { return $false }
  if (-not (Test-Path $tf) -or (Get-Item $tf).Length -lt 25KB) { return $false }
  try {
    $im = [System.Drawing.Image]::FromFile($tf)
    $w = $im.Width; $h = $im.Height; $im.Dispose()
    if ($w -lt $minW -or $h -lt 300) { return $false }
  } catch { return $false }
  Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $tf (Join-Path $imgDir "$slug.$ext")
  return $true
}

$fixed = @(); $failed = @()
foreach ($slug in $targets) {
  $done = $false
  $cands = if ($wweAlt.ContainsKey($slug)) { $wweAlt[$slug] } else { @($slug) }
  foreach ($ws in $cands) {
    if ($done) { break }
    try {
      $resp = Invoke-WebRequest -Uri "https://www.wwe.com/superstars/$ws" -Headers @{ 'User-Agent' = $uaWeb } -TimeoutSec 40 -UseBasicParsing
      if ($resp.Content -match '<meta property="og:image" content="([^"]+)"') {
        $og = $Matches[1]
        $orig = $og -replace '/f/styles/[^/]+/public/', '/f/'
        if ($orig -ne $og -and (Save-IfGood $orig $slug 500)) { $done = $true; Write-Host "OK   $slug <- WWE.com original ($ws)" }
        elseif (Save-IfGood $og $slug 500) { $done = $true; Write-Host "OK   $slug <- WWE.com og:image ($ws)" }
      }
    } catch { }
    Start-Sleep -Milliseconds 1500
  }
  if (-not $done) {
    # fallback Commons
    $name = $nameBySlug[$slug]
    $api = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2&generator=search&gsrnamespace=6&gsrlimit=10&prop=imageinfo&iiprop=url%7Csize&iiurlwidth=1400&gsrsearch=' + [uri]::EscapeDataString($name)
    try {
      $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $uaWiki } -TimeoutSec 30
      $tokens = ($name.ToLowerInvariant() -split '[^a-z0-9]+') | Where-Object { $_.Length -gt 2 }
      $best = $null; $bestW = 0
      foreach ($p in $r.query.pages) {
        $ti = $p.title.ToLowerInvariant()
        if ($ti -notmatch '\.(jpe?g|png)$') { continue }
        $hit = $false; foreach ($tk in $tokens) { if ($ti.Contains($tk)) { $hit = $true } }
        if (-not $hit) { continue }
        $ii = $p.imageinfo | Select-Object -First 1
        if ($ii -and $ii.width -gt $bestW) { $bestW = $ii.width; $best = $ii }
      }
      if ($best) {
        $u = if ($best.thumburl) { $best.thumburl } else { $best.url }
        if (Save-IfGood $u $slug 450) { $done = $true; Write-Host "OK   $slug <- Commons" }
      }
    } catch { Write-Host "Commons FAIL $slug : $($_.Exception.Message)" }
    Start-Sleep -Seconds 4
  }
  if ($done) { $fixed += $slug } else { $failed += $slug; Write-Host "MISS $slug" }
}
Write-Host '----'
Write-Host ("CORRIGEES: {0}/{1}" -f $fixed.Count, $targets.Count)
if ($failed.Count) { Write-Host ("ECHECS: " + ($failed -join ', ')) }
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-data.ps1')
