# Images demandees : Bron Breakker, Grayson Waller (renders WWE.com full HD, fallback Fandom)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$imgDir = Join-Path $root 'images'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

function Save-Img([string]$url, [string]$slug) {
  if (-not $url) { return $false }
  $ext = 'jpg'
  if ($url -match '\.(jpe?g|png|webp)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $tmp = Join-Path $env:TEMP "fx3-$slug.$ext"
  try { Invoke-WebRequest -Uri $url -OutFile $tmp -Headers @{ 'User-Agent' = $ua; 'Referer' = 'https://www.wwe.com/' } -TimeoutSec 60 -UseBasicParsing } catch { Write-Host "  dl fail"; return $false }
  $kb = [math]::Round((Get-Item $tmp).Length / 1KB)
  if ($kb -lt 40) { Write-Host "  trop petit ($kb KB)"; return $false }
  $head = [IO.File]::ReadAllBytes($tmp)[0..11]
  if ($head[0] -eq 0x52 -and $head[8] -eq 0x57 -and $ext -ne 'webp') { $new = Join-Path $env:TEMP "fx3-$slug.webp"; Move-Item -Force $tmp $new; $tmp = $new; $ext = 'webp' }
  Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $tmp (Join-Path $imgDir "$slug.$ext")
  Write-Host "  OK -> $slug.$ext ($kb KB)"
  return $true
}
$jobs = @(
  @{slug='bron-breakker';  wwe=@('bron-breakker'); fandom=@('Bron Breakker')},
  @{slug='grayson-waller'; wwe=@('grayson-waller'); fandom=@('Grayson Waller')}
)
foreach ($j in $jobs) {
  Write-Host "IMG $($j.slug):"
  $done = $false
  foreach ($ws in $j.wwe) {
    if ($done) { break }
    try {
      $resp = Invoke-WebRequest -Uri "https://www.wwe.com/superstars/$ws" -Headers @{ 'User-Agent' = $ua } -TimeoutSec 40 -UseBasicParsing
      if ($resp.Content -match '<meta property="og:image" content="([^"]+)"') {
        $og = $Matches[1]
        $orig = $og -replace '/f/styles/[^/]+/public/', '/f/'
        if ($orig -ne $og -and (Save-Img $orig $j.slug)) { $done = $true }
        elseif (Save-Img $og $j.slug) { $done = $true }
      } else { Write-Host "  pas d og:image" }
    } catch { Write-Host "  wwe.com fail: $($_.Exception.Message)" }
    Start-Sleep -Milliseconds 1500
  }
  if (-not $done) {
    foreach ($t in $j.fandom) {
      if ($done) { break }
      $api = 'https://prowrestling.fandom.com/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=original&titles=' + [uri]::EscapeDataString($t)
      try {
        $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
        $p = $r.query.pages | Select-Object -First 1
        if ($p.original -and $p.original.source) { if (Save-Img $p.original.source $j.slug) { $done = $true } }
      } catch { Write-Host "  fandom fail" }
      Start-Sleep -Seconds 3
    }
  }
  if (-not $done) { Write-Host "  MISS" }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-data.ps1')
