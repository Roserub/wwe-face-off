# Recupere les photos de la vague 3 a partir de tools\wave3.psv
# Format PSV : slug|wwe_slug(s virgule, vide si aucun)|titres wikipedia/fandom (virgule)
# Chaine : WWE.com (og:image original) -> Fandom prowrestling -> Wikipedia (vignette 1400px)
# Ecrit en ASCII pur : PowerShell 5.1 lit les .ps1 sans BOM en ANSI et abimerait tout accent.
param([string]$Only = '')
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing

$root   = Split-Path -Parent $PSScriptRoot
$imgDir = Join-Path $root 'images'
$psvF   = Join-Path $PSScriptRoot 'wave3.psv'
$ua     = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$uaWiki = 'WWEFaceOffBot/2.0 (local one-shot fan project) PowerShell/5.1'

function Get-Dim([string]$path) {
  try { $im = [System.Drawing.Image]::FromFile($path); $d = @($im.Width, $im.Height); $im.Dispose(); return $d }
  catch { return @(0, 0) }        # webp : GDI+ ne sait pas lire, on juge au poids
}

function Save-Img([string]$url, [string]$slug, [int]$minKb) {
  if (-not $url) { return $false }
  $ext = 'jpg'
  if ($url -match '\.(jpe?g|png|webp)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg', 'jpg' }
  $tmp = Join-Path $env:TEMP "w3-$slug.$ext"
  try {
    Invoke-WebRequest -Uri $url -OutFile $tmp -Headers @{ 'User-Agent' = $ua; 'Referer' = 'https://www.wwe.com/' } -TimeoutSec 60 -UseBasicParsing
  } catch { Write-Host "    dl fail"; return $false }
  $kb = [math]::Round((Get-Item $tmp).Length / 1KB)
  if ($kb -lt $minKb) { Write-Host "    rejete : $kb KB (< $minKb)"; return $false }
  # signature RIFF....WEBP : renommer meme si l'URL disait jpg
  $head = [IO.File]::ReadAllBytes($tmp)[0..11]
  if ($head[0] -eq 0x52 -and $head[8] -eq 0x57 -and $ext -ne 'webp') {
    $new = Join-Path $env:TEMP "w3-$slug.webp"; Move-Item -Force $tmp $new; $tmp = $new; $ext = 'webp'
  }
  $d = Get-Dim $tmp
  if ($d[0] -gt 0 -and ($d[0] -lt 400 -or $d[1] -lt 400)) { Write-Host "    rejete : $($d[0])x$($d[1])"; return $false }
  Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $tmp (Join-Path $imgDir "$slug.$ext")
  $dim = if ($d[0] -gt 0) { "$($d[0])x$($d[1])" } else { 'webp' }
  Write-Host "    OK -> $slug.$ext ($kb KB, $dim)"
  return $true
}

# NB : ne PAS nommer cette variable $only. Les noms de variables PowerShell sont insensibles
# a la casse, donc $only serait le meme que le parametre [string]$Only ; PowerShell reappliquerait
# alors le type declare et reconvertirait le tableau en chaine (Count vaut 1 meme vide, et
# -notcontains degenere en comparaison d'egalite) => toutes les lignes etaient sautees.
$sel = @($Only -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if (-not (Test-Path $psvF)) { throw "wave3.psv introuvable : $psvF" }
$rows = @()
foreach ($l in (Get-Content -Encoding UTF8 $psvF)) {
  if ($l -match '^\s*#' -or $l -notmatch '\|') { continue }
  $p = $l.Split('|')
  if ($p[0].Trim() -eq 'slug') { continue }
  $rows += [pscustomobject]@{
    slug = $p[0].Trim()
    wwe  = @($p[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    wiki = @($p[2] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  }
}

if ($rows.Count -eq 0) { throw "wave3.psv lu mais aucune ligne exploitable ($psvF)" }
Write-Host ("wave3.psv : {0} profil(s) a traiter" -f $rows.Count)

$okCount = 0; $missList = @()
foreach ($r in $rows) {
  if ($sel.Count -and $sel -notcontains $r.slug) { continue }
  Write-Host "IMG $($r.slug) :"
  $done = $false

  # 1) WWE.com : /f/styles/<style>/public/ -> /f/ donne l'original haute def
  foreach ($ws in $r.wwe) {
    if ($done) { break }
    try {
      $resp = Invoke-WebRequest -Uri "https://www.wwe.com/superstars/$ws" -Headers @{ 'User-Agent' = $ua } -TimeoutSec 40 -UseBasicParsing
      if ($resp.Content -match '<meta property="og:image" content="([^"]+)"') {
        $og = $Matches[1]
        $orig = $og -replace '/f/styles/[^/]+/public/', '/f/'
        Write-Host "  wwe.com/$ws"
        if ($orig -ne $og -and (Save-Img $orig $r.slug 60)) { $done = $true }
        elseif (Save-Img $og $r.slug 60) { $done = $true }
      } else { Write-Host "  wwe.com/$ws : pas d'og:image" }
    } catch { Write-Host "  wwe.com/$ws : indisponible" }
    Start-Sleep -Milliseconds 1200
  }

  # 2) Fandom prowrestling (API seule : le HTML renvoie 403)
  if (-not $done) {
    foreach ($t in $r.wiki) {
      if ($done) { break }
      $api = 'https://prowrestling.fandom.com/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=original&titles=' + [uri]::EscapeDataString($t)
      try {
        $resp = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
        $pg = $resp.query.pages | Select-Object -First 1
        Write-Host "  fandom [$t]"
        if ($pg.original -and $pg.original.source) { if (Save-Img $pg.original.source $r.slug 60) { $done = $true } }
      } catch { Write-Host "  fandom [$t] : indisponible" }
      Start-Sleep -Seconds 2
    }
  }

  # 3) Wikipedia (vignette 1400px)
  if (-not $done) {
    foreach ($t in $r.wiki) {
      if ($done) { break }
      $api = 'https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=thumbnail&pithumbsize=1400&titles=' + [uri]::EscapeDataString($t)
      try {
        $resp = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $uaWiki } -TimeoutSec 30
        $pg = $resp.query.pages | Select-Object -First 1
        Write-Host "  wikipedia [$t]"
        if ($pg.thumbnail -and $pg.thumbnail.source) { if (Save-Img $pg.thumbnail.source $r.slug 45) { $done = $true } }
      } catch { Write-Host "  wikipedia [$t] : indisponible" }
      Start-Sleep -Seconds 3
    }
  }

  if ($done) { $okCount++ } else { Write-Host "  MISS"; $missList += $r.slug }
}

Write-Host ""
Write-Host ("VAGUE 3 : {0} image(s) recuperee(s), {1} manquante(s)" -f $okCount, $missList.Count)
if ($missList.Count) { Write-Host ("MANQUANTS : " + ($missList -join ', ')) }
