# Rattrapage cible des images manquantes avec titres alternatifs, puis build-data.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'WWEFaceOffBot/2.0 (local one-shot fan project) PowerShell/5.1'
$imgDir = 'c:\Users\Corentin\Documents\lol\wwe\images'

$fixes = @(
  @{slug='john-morrison';     titles=@('John Morrison (wrestler)')},
  @{slug='kalisto';           titles=@('Kalisto (wrestler)')},
  @{slug='brodus-clay';       titles=@('Tyrus (wrestler)','Brodus Clay')},
  @{slug='adam-rose';         titles=@('Ray Leppan','Adam Rose (wrestler)')},
  @{slug='humberto-carrillo'; titles=@('Humberto (wrestler)','Humberto Carrillo (wrestler)')},
  @{slug='dragon-lee';        titles=@('Dragon Lee (wrestler)','Dragon Lee (wrestler, born 1995)')},
  @{slug='lola-vice';         titles=@('Valerie Loureda','Lola Vice')},
  @{slug='ruby-riott';        titles=@('Ruby Soho')},
  @{slug='kelani-jordan';     titles=@('Kelani Jordan')},
  @{slug='tatum-paxley';      titles=@('Tatum Paxley')},
  @{slug='maxxine-dupri';     titles=@('Maxxine Dupri')},
  @{slug='sol-ruca';          titles=@('Sol Ruca')}
)
foreach ($f in $fixes) {
  if (Get-ChildItem $imgDir -Filter "$($f.slug).*" -ErrorAction SilentlyContinue) { Write-Host "skip $($f.slug)"; continue }
  $got = $false
  foreach ($t in $f.titles) {
    if ($got) { break }
    $api = 'https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=thumbnail%7Coriginal&pithumbsize=1400&titles=' + [uri]::EscapeDataString($t)
    try {
      $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
      $p = $r.query.pages | Select-Object -First 1
      $src = $null
      if ($p.thumbnail -and $p.thumbnail.source) { $src = $p.thumbnail.source }
      elseif ($p.original -and $p.original.source) { $src = $p.original.source }
      if ($src -and $src -notmatch '\.svg') {
        $ext = 'jpg'
        if ($src -match '\.(jpe?g|png|gif|webp)(?:$|\?)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
        Invoke-WebRequest -Uri $src -OutFile (Join-Path $imgDir "$($f.slug).$ext") -Headers @{ 'User-Agent' = $ua } -TimeoutSec 60 -UseBasicParsing
        Write-Host "OK   $($f.slug) via [$t]"
        $got = $true
      } else { Write-Host "vide $($f.slug) via [$t] -> $($p.title)" }
    } catch { Write-Host "FAIL $($f.slug) via [$t]: $($_.Exception.Message)" }
    Start-Sleep -Seconds 3
  }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File 'c:\Users\Corentin\Documents\lol\wwe\tools\build-data.ps1'
