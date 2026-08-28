# Jimmy Wang Yang : pas de page WWE.com (alumni), Fandom/Wikipedia trop petits -> Commons.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing
$imgDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'images')
$ua = 'WWEFaceOffBot/2.0 (local one-shot fan project) PowerShell/5.1'
$cur = Get-ChildItem $imgDir -Filter 'jimmy-wang-yang.*' | Select-Object -First 1
$curPx = 0
if ($cur) { try { $im = [System.Drawing.Image]::FromFile($cur.FullName); $curPx = $im.Width * $im.Height; $im.Dispose() } catch {} }
Write-Host ("actuel : {0} ({1} px2)" -f $cur.Name, $curPx)

$best = $null; $bestPx = $curPx
foreach ($q in @('Jimmy Wang Yang','Jimmy Yang wrestler','James Yun')) {
  $api = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2&generator=search&gsrnamespace=6&gsrlimit=12&prop=imageinfo&iiprop=url%7Csize&iiurlwidth=1400&gsrsearch=' + [uri]::EscapeDataString($q)
  try {
    $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
    foreach ($p in $r.query.pages) {
      $ti = $p.title.ToLowerInvariant()
      if ($ti -notmatch '\.(jpe?g|png)$') { continue }
      if ($ti -notmatch 'yang|yun') { continue }
      $ii = $p.imageinfo | Select-Object -First 1
      if (-not $ii) { continue }
      $px = $ii.width * $ii.height
      Write-Host ("  candidat {0} : {1}x{2}" -f $p.title, $ii.width, $ii.height)
      if ($px -gt $bestPx) { $bestPx = $px; $best = $ii }
    }
  } catch { Write-Host "  [$q] FAIL: $($_.Exception.Message)" }
  Start-Sleep -Seconds 6
}
if ($best) {
  $u = if ($best.thumburl) { $best.thumburl } else { $best.url }
  $ext = 'jpg'; if ($u -match '\.(jpe?g|png)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $tmp = Join-Path $env:TEMP "jwy.$ext"
  Invoke-WebRequest -Uri $u -OutFile $tmp -Headers @{ 'User-Agent' = $ua } -TimeoutSec 60 -UseBasicParsing
  Get-ChildItem $imgDir -Filter 'jimmy-wang-yang.*' -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $tmp (Join-Path $imgDir "jimmy-wang-yang.$ext")
  Write-Host "OK jimmy-wang-yang remplace"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\build-data.ps1'
} else { Write-Host "rien de mieux sur Commons - photo actuelle conservee" }
