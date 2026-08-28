# Retry patient des 3 dernieres images (cooldown 5 min, essais en/fr espaces), puis build-data.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'WWEFaceOffBot/2.0 (local one-shot fan project) PowerShell/5.1'
$imgDir = 'c:\Users\Corentin\Documents\lol\wwe\images'
Write-Host 'Cooldown 300s...'
Start-Sleep -Seconds 300

$fixes = @(
  @{slug='john-morrison'; tries=@(@('en','John Morrison (wrestler)'), @('fr','John Morrison (catcheur)'))},
  @{slug='kalisto';       tries=@(@('en','Kalisto (wrestler)'),       @('fr','Kalisto (catcheur)'))},
  @{slug='ruby-riott';    tries=@(@('en','Ruby Riott'),               @('fr','Ruby Riott'))}
)
foreach ($f in $fixes) {
  if (Get-ChildItem $imgDir -Filter "$($f.slug).*" -ErrorAction SilentlyContinue) { Write-Host "skip $($f.slug) (deja la)"; continue }
  $got = $false
  foreach ($try in $f.tries) {
    if ($got) { break }
    $lang = $try[0]; $t = $try[1]
    $api = "https://$lang.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=thumbnail%7Coriginal&pithumbsize=1400&titles=" + [uri]::EscapeDataString($t)
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
        Write-Host "OK   $($f.slug) via $lang [$t]"
        $got = $true
      } else { Write-Host "vide $($f.slug) via $lang [$t] -> $($p.title)" }
    } catch { Write-Host "FAIL $($f.slug) via $lang [$t]: $($_.Exception.Message)" }
    Start-Sleep -Seconds 10
  }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File 'c:\Users\Corentin\Documents\lol\wwe\tools\build-data.ps1'
