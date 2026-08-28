# Corrige les 2 faux positifs songs (artiste WWE exige, sinon ambiance) et retente 2 images.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$imgDir = Join-Path $root 'images'
$psvF = Join-Path $root 'tools\themes-found.psv'
$uaWeb = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

# ---------- IMAGES (verbeux) ----------
function Save-Img([string]$url, [string]$slug) {
  if (-not $url) { return $false }
  $ext = 'jpg'
  if ($url -match '\.(jpe?g|png|webp)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $tmp = Join-Path $env:TEMP "fx2-$slug.$ext"
  try { Invoke-WebRequest -Uri $url -OutFile $tmp -Headers @{ 'User-Agent' = $uaWeb } -TimeoutSec 60 -UseBasicParsing } catch { Write-Host "  dl fail: $($_.Exception.Message)"; return $false }
  $kb = [math]::Round((Get-Item $tmp).Length / 1KB)
  if ($kb -lt 30) { Write-Host "  trop petit ($kb KB)"; return $false }
  $head = [IO.File]::ReadAllBytes($tmp)[0..11]
  if ($head[0] -eq 0x52 -and $head[8] -eq 0x57 -and $ext -ne 'webp') { $new = Join-Path $env:TEMP "fx2-$slug.webp"; Move-Item -Force $tmp $new; $tmp = $new; $ext = 'webp' }
  Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $tmp (Join-Path $imgDir "$slug.$ext")
  Write-Host "  sauve $slug.$ext ($kb KB)"
  return $true
}
$imgJobs = @(
  @{slug='gail-kim';         fandom=@('Gail Kim','Gail Kim-Irvine'); commons='Gail Kim'},
  @{slug='kristal-marshall'; fandom=@('Kristal Marshall','Kristal'); commons='Kristal Marshall'}
)
foreach ($j in $imgJobs) {
  Write-Host "IMG $($j.slug):"
  $done = $false
  foreach ($t in $j.fandom) {
    if ($done) { break }
    $api = 'https://prowrestling.fandom.com/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=original&titles=' + [uri]::EscapeDataString($t)
    try {
      $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $uaWeb } -TimeoutSec 30
      $p = $r.query.pages | Select-Object -First 1
      Write-Host "  fandom [$t] -> $($p.title) img=$([bool]($p.original -and $p.original.source))"
      if ($p.original -and $p.original.source) { if (Save-Img $p.original.source $j.slug) { $done = $true; Write-Host "  OK via Fandom [$t]" } }
    } catch { Write-Host "  fandom fail [$t]: $($_.Exception.Message)" }
    Start-Sleep -Seconds 3
  }
  if (-not $done) {
    $api = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2&generator=search&gsrnamespace=6&gsrlimit=10&prop=imageinfo&iiprop=url%7Csize&iiurlwidth=1200&gsrsearch=' + [uri]::EscapeDataString($j.commons)
    try {
      $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $uaWeb } -TimeoutSec 30
      $tokens = ($j.commons.ToLowerInvariant() -split ' ')
      $best = $null; $bw = 0
      foreach ($p in $r.query.pages) {
        $ti = $p.title.ToLowerInvariant()
        if ($ti -notmatch '\.(jpe?g|png)$') { continue }
        $hit = $true; foreach ($tk in $tokens) { if (-not $ti.Contains($tk)) { $hit = $false } }
        if (-not $hit) { continue }
        $ii = $p.imageinfo | Select-Object -First 1
        if ($ii -and $ii.width -gt $bw) { $bw = $ii.width; $best = $ii }
      }
      if ($best) {
        $u = if ($best.thumburl) { $best.thumburl } else { $best.url }
        if (Save-Img $u $j.slug) { $done = $true; Write-Host "  OK via Commons (${bw}px)" }
      } else { Write-Host "  commons: rien" }
    } catch { Write-Host "  commons fail: $($_.Exception.Message)" }
  }
  if (-not $done) { Write-Host "  MISS definitif" }
}

# ---------- SONGS : artiste WWE exige, sinon ambiance ----------
function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=12&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $uaWeb; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
$lines = Get-Content -Encoding UTF8 $psvF
# pool ambiance existant (rows marquees [ambiance])
$amb = @()
foreach ($l in $lines) { $p = $l.Split('|'); if ($p.Length -ge 4 -and $p[1] -match '\[ambiance\]' -and $p[3]) { $amb += ,$p } }
$songJobs = @(
  @{slug='shayna-baszler'; terms=@('Queen of Spades def rebel','WWE Queen of Spades Shayna','Shayna Baszler WWE theme'); need='queen of spades|shayna'},
  @{slug='braun-strowman'; terms=@('I Am Stronger Braun Strowman','Braun Strowman WWE theme','I Am Stronger def rebel CFO'); need='i am stronger|strowman'}
)
foreach ($j in $songJobs) {
  $best = $null
  foreach ($term in $j.terms) {
    foreach ($t in (Search-Itunes $term)) {
      if (-not $t.previewUrl) { continue }
      $track = ('' + $t.trackName).ToLowerInvariant()
      $artist = ('' + $t.artistName).ToLowerInvariant()
      if ($track -notmatch $j.need) { continue }
      if ($artist -notmatch 'wwe|jim johnston|cfo\$|def rebel') { continue }   # version officielle uniquement
      $best = $t; break
    }
    Start-Sleep -Milliseconds 2600
    if ($best) { break }
  }
  if ($best) {
    $newLine = "$($j.slug)|$($best.trackName)|$($best.artistName)|$($best.previewUrl)"
    Write-Host "SONG OK  $($j.slug) -> $($best.trackName) [$($best.artistName)]"
  } elseif ($amb.Count) {
    $p = $amb[(Get-Random -Maximum $amb.Count)]
    $newLine = "$($j.slug)|$($p[1])|$($p[2])|$($p[3])"
    Write-Host "SONG AMBIANCE $($j.slug) -> $($p[1])"
  } else { $newLine = $null; Write-Host "SONG MISS $($j.slug)" }
  if ($newLine) { $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq $j.slug) { $newLine } else { $_ } } }
}
$lines | Set-Content -Path $psvF -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-data.ps1')
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
