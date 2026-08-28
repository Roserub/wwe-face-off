# Retry patient (cooldown 15 min) : meilleures photos Gail Kim + Kristal Marshall
# via Commons puis en.wikipedia (batch), puis build-data.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$imgDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'images')
$ua = 'WWEFaceOffBot/2.0 (local one-shot fan project) PowerShell/5.1'
Write-Host 'Cooldown 900s...'
Start-Sleep -Seconds 900

function Save-Img([string]$url, [string]$slug) {
  if (-not $url) { return $false }
  $ext = 'jpg'
  if ($url -match '\.(jpe?g|png|webp)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $tmp = Join-Path $env:TEMP "rgk-$slug.$ext"
  try { Invoke-WebRequest -Uri $url -OutFile $tmp -Headers @{ 'User-Agent' = $ua } -TimeoutSec 60 -UseBasicParsing } catch { return $false }
  if ((Get-Item $tmp).Length -lt 45KB) { return $false }
  Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $tmp (Join-Path $imgDir "$slug.$ext")
  return $true
}

$jobs = @(
  @{slug='gail-kim';         q='Gail Kim';         tokens=@('gail','kim')},
  @{slug='kristal-marshall'; q='Kristal Marshall'; tokens=@('kristal')}
)
$done = @{}
foreach ($j in $jobs) {
  $api = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2&generator=search&gsrnamespace=6&gsrlimit=12&prop=imageinfo&iiprop=url%7Csize&iiurlwidth=1300&gsrsearch=' + [uri]::EscapeDataString($j.q)
  try {
    $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
    $best = $null; $bw = 0
    foreach ($p in $r.query.pages) {
      $ti = $p.title.ToLowerInvariant()
      if ($ti -notmatch '\.(jpe?g|png)$') { continue }
      $hit = $true; foreach ($tk in $j.tokens) { if (-not $ti.Contains($tk)) { $hit = $false } }
      if (-not $hit) { continue }
      $ii = $p.imageinfo | Select-Object -First 1
      if ($ii -and $ii.width -gt $bw -and $ii.width -ge 550) { $bw = $ii.width; $best = $ii }
    }
    if ($best) {
      $u = if ($best.thumburl) { $best.thumburl } else { $best.url }
      if (Save-Img $u $j.slug) { $done[$j.slug] = 1; Write-Host "OK $($j.slug) <- Commons (${bw}px)" }
    } else { Write-Host "$($j.slug): rien d'assez grand sur Commons" }
  } catch { Write-Host "$($j.slug) Commons FAIL: $($_.Exception.Message)" }
  Start-Sleep -Seconds 20
}

$left = $jobs | Where-Object { -not $done.ContainsKey($_.slug) }
if ($left.Count) {
  $titles = ($left | ForEach-Object { [uri]::EscapeDataString($_.q) }) -join '%7C'
  $api = "https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=thumbnail&pithumbsize=1400&pilimit=max&titles=$titles"
  try {
    $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
    foreach ($p in $r.query.pages) {
      $j = $left | Where-Object { $p.title -match ($_.tokens[0]) -or $_.q -eq $p.title } | Select-Object -First 1
      if ($j -and $p.thumbnail -and $p.thumbnail.source) {
        if (Save-Img $p.thumbnail.source $j.slug) { Write-Host "OK $($j.slug) <- en.wiki" }
      }
    }
  } catch { Write-Host "en.wiki FAIL: $($_.Exception.Message)" }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\build-data.ps1'
