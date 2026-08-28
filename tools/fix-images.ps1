# Remplace les photos demandees par un render full HD.
# Usage : fix-images.ps1 -Slugs "the-miz,mickie-james"   (chaine WWE.com -> Fandom -> Wikipedia)
# Alias WWE.com / titres Fandom specifiques dans $alt.
param([string]$Slugs = '')
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$imgDir = Join-Path $root 'images'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$uaWiki = 'WWEFaceOffBot/2.0 (local one-shot fan project) PowerShell/5.1'

# slug -> @{ wwe = alias wwe.com ; wiki = titres wikipedia/fandom }
$alt = @{
  'awesome-kong' = @{ wwe = @('kharma','awesome-kong'); wiki = @('Awesome Kong','Kia Stevens') }
  'lance-cade'   = @{ wwe = @('lance-cade');            wiki = @('Lance Cade') }
  'sarah-logan'  = @{ wwe = @('sarah-logan');           wiki = @('Sarah Logan','Valhalla (wrestler)') }
  'the-miz'      = @{ wwe = @('the-miz','miz');         wiki = @('The Miz') }
  'mickie-james' = @{ wwe = @('mickie-james');          wiki = @('Mickie James') }
  'roxanne-perez'= @{ wwe = @('roxanne-perez');         wiki = @('Roxanne Perez') }
}

function Get-Dim([string]$path) {
  try { $im = [System.Drawing.Image]::FromFile($path); $d = @($im.Width, $im.Height); $im.Dispose(); return $d }
  catch { return @(0,0) }   # webp : GDI+ ne sait pas lire, on jugera sur le poids
}
function Save-Img([string]$url, [string]$slug, [int]$minKb) {
  if (-not $url) { return $false }
  $ext = 'jpg'
  if ($url -match '\.(jpe?g|png|webp)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $tmp = Join-Path $env:TEMP "fi-$slug.$ext"
  try { Invoke-WebRequest -Uri $url -OutFile $tmp -Headers @{ 'User-Agent' = $ua; 'Referer' = 'https://www.wwe.com/' } -TimeoutSec 60 -UseBasicParsing }
  catch { Write-Host "    dl fail"; return $false }
  $kb = [math]::Round((Get-Item $tmp).Length / 1KB)
  if ($kb -lt $minKb) { Write-Host "    rejete : $kb KB (< $minKb)"; return $false }
  $head = [IO.File]::ReadAllBytes($tmp)[0..11]
  if ($head[0] -eq 0x52 -and $head[8] -eq 0x57 -and $ext -ne 'webp') {
    $new = Join-Path $env:TEMP "fi-$slug.webp"; Move-Item -Force $tmp $new; $tmp = $new; $ext = 'webp'
  }
  $d = Get-Dim $tmp
  if ($d[0] -gt 0 -and ($d[0] -lt 400 -or $d[1] -lt 400)) { Write-Host "    rejete : $($d[0])x$($d[1])"; return $false }
  Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $tmp (Join-Path $imgDir "$slug.$ext")
  $dim = if ($d[0] -gt 0) { "$($d[0])x$($d[1])" } else { 'webp' }
  Write-Host "    OK -> $slug.$ext ($kb KB, $dim)"
  return $true
}

foreach ($slug in ($Slugs -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
  Write-Host "IMG $slug :"
  $cfg = if ($alt.ContainsKey($slug)) { $alt[$slug] } else { @{ wwe = @($slug); wiki = @(($slug -split '-' | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join ' ') } }
  $done = $false
  # 1) WWE.com (render officiel, original haute def)
  foreach ($ws in $cfg.wwe) {
    if ($done) { break }
    try {
      $resp = Invoke-WebRequest -Uri "https://www.wwe.com/superstars/$ws" -Headers @{ 'User-Agent' = $ua } -TimeoutSec 40 -UseBasicParsing
      if ($resp.Content -match '<meta property="og:image" content="([^"]+)"') {
        $og = $Matches[1]
        $orig = $og -replace '/f/styles/[^/]+/public/', '/f/'
        Write-Host "  wwe.com/$ws"
        if ($orig -ne $og -and (Save-Img $orig $slug 60)) { $done = $true }
        elseif (Save-Img $og $slug 60) { $done = $true }
      } else { Write-Host "  wwe.com/$ws : pas d og:image" }
    } catch { Write-Host "  wwe.com/$ws : $($_.Exception.Message)" }
    Start-Sleep -Milliseconds 1200
  }
  # 2) Fandom (API seule : le HTML renvoie 403)
  if (-not $done) {
    foreach ($t in $cfg.wiki) {
      if ($done) { break }
      $api = 'https://prowrestling.fandom.com/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=original&titles=' + [uri]::EscapeDataString($t)
      try {
        $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
        $p = $r.query.pages | Select-Object -First 1
        Write-Host "  fandom [$t]"
        if ($p.original -and $p.original.source) { if (Save-Img $p.original.source $slug 60) { $done = $true } }
      } catch { Write-Host "  fandom [$t] : $($_.Exception.Message)" }
      Start-Sleep -Seconds 2
    }
  }
  # 3) Wikipedia (vignette 1400px)
  if (-not $done) {
    foreach ($t in $cfg.wiki) {
      if ($done) { break }
      $api = 'https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=thumbnail&pithumbsize=1400&titles=' + [uri]::EscapeDataString($t)
      try {
        $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $uaWiki } -TimeoutSec 30
        $p = $r.query.pages | Select-Object -First 1
        Write-Host "  wikipedia [$t]"
        if ($p.thumbnail -and $p.thumbnail.source) { if (Save-Img $p.thumbnail.source $slug 45) { $done = $true } }
      } catch { Write-Host "  wikipedia [$t] : $($_.Exception.Message)" }
      Start-Sleep -Seconds 3
    }
  }
  if (-not $done) { Write-Host "  MISS (photo actuelle conservee)" }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-data.ps1')
