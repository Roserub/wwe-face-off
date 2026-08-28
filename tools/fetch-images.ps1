# Telecharge les images Wikipedia (thumbnail ~1400px) pour chaque entree de roster.csv
# Idempotent : saute les fichiers deja presents. Log: tools\imglog.csv, echecs: tools\misses.txt
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root   = Split-Path -Parent $PSScriptRoot          # ...\wwe
$csv    = Join-Path $root 'roster.csv'
$imgDir = Join-Path $root 'images'
$logF   = Join-Path $PSScriptRoot 'imglog.csv'
$missF  = Join-Path $PSScriptRoot 'misses.txt'
if (-not (Test-Path $imgDir)) { New-Item -ItemType Directory -Force $imgDir | Out-Null }

$ua = 'WWE-FaceOff-local-ranker/1.0 (personal offline project; contact via talk page)'
$rows = Get-Content -Raw -Encoding UTF8 $csv | ConvertFrom-Csv

function Get-Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
  }
  $x = $sb.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", '-'
  return $x.Trim('-')
}

$log = @()
$miss = @()
$i = 0
foreach ($r in $rows) {
  $i++
  $slug = Get-Slug $r.name
  $existing = Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($existing) {
    $log += [pscustomobject]@{ name=$r.name; slug=$slug; file=$existing.Name; status='cached' }
    continue
  }
  $title = [uri]::EscapeDataString($r.wiki)
  $api = "https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=thumbnail&pithumbsize=1400&titles=$title"
  $src = $null
  try {
    $resp = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
    $page = $resp.query.pages | Select-Object -First 1
    if ($page -and $page.thumbnail -and $page.thumbnail.source) { $src = $page.thumbnail.source }
  } catch {
    Write-Host "[$i] API FAIL $($r.name): $($_.Exception.Message)"
  }
  if (-not $src -or $src -match '\.svg') {
    $miss += "$($r.name)|$($r.wiki)|no-image"
    $log += [pscustomobject]@{ name=$r.name; slug=$slug; file=''; status='miss' }
    Write-Host "[$i/$($rows.Count)] MISS  $($r.name) ($($r.wiki))"
    Start-Sleep -Milliseconds 150
    continue
  }
  $ext = 'jpg'
  if ($src -match '\.(jpe?g|png|gif|webp)(?:$|\?)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $out = Join-Path $imgDir "$slug.$ext"
  try {
    Invoke-WebRequest -Uri $src -OutFile $out -Headers @{ 'User-Agent' = $ua } -TimeoutSec 60 -UseBasicParsing
    $kb = [math]::Round((Get-Item $out).Length / 1KB)
    $log += [pscustomobject]@{ name=$r.name; slug=$slug; file="$slug.$ext"; status="ok ($kb KB)" }
    Write-Host "[$i/$($rows.Count)] OK    $($r.name) -> $slug.$ext ($kb KB)"
  } catch {
    $miss += "$($r.name)|$($r.wiki)|download-fail"
    $log += [pscustomobject]@{ name=$r.name; slug=$slug; file=''; status='dl-fail' }
    Write-Host "[$i/$($rows.Count)] DLFAIL $($r.name)"
  }
  Start-Sleep -Milliseconds 200
}

$log | Export-Csv -Path $logF -NoTypeInformation -Encoding UTF8
$miss | Set-Content -Path $missF -Encoding UTF8
Write-Host "----"
Write-Host ("TOTAL: {0}  OK/cached: {1}  MISS: {2}" -f $rows.Count, (($log | Where-Object { $_.status -ne 'miss' -and $_.status -ne 'dl-fail' }).Count), $miss.Count)
