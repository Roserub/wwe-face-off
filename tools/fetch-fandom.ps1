# Recupere les photos Adam Rose + JTG depuis le wiki Fandom pro-wrestling, puis build-data.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$imgDir = 'c:\Users\Corentin\Documents\lol\wwe\images'
$jobs = @(
  @{slug='adam-rose'; titles=@('Adam Rose','Raymond Leppan')},
  @{slug='jtg';       titles=@('JTG')}
)
foreach ($j in $jobs) {
  $got = $false
  foreach ($t in $j.titles) {
    if ($got) { break }
    $api = 'https://prowrestling.fandom.com/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=original&titles=' + [uri]::EscapeDataString($t)
    try {
      $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
      $p = $r.query.pages | Select-Object -First 1
      if ($p.original -and $p.original.source) {
        $src = $p.original.source
        $ext = 'jpg'; if ($src -match '\.(jpe?g|png|webp)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
        $tmp = Join-Path $env:TEMP "fandom-$($j.slug).$ext"
        Invoke-WebRequest -Uri $src -OutFile $tmp -Headers @{ 'User-Agent' = $ua } -TimeoutSec 60 -UseBasicParsing
        $im = [System.Drawing.Image]::FromFile($tmp)
        $w = $im.Width; $h = $im.Height; $im.Dispose()
        if ($w -ge 300 -and $h -ge 350) {
          Get-ChildItem $imgDir -Filter "$($j.slug).*" -ErrorAction SilentlyContinue | Remove-Item -Force
          Move-Item -Force $tmp (Join-Path $imgDir "$($j.slug).$ext")
          Write-Host "OK   $($j.slug) <- Fandom [$t] ${w}x${h}"
          $got = $true
        } else { Write-Host "trop petit $($j.slug) [$t] ${w}x${h}" }
      } else { Write-Host "rien pour [$t]" }
    } catch { Write-Host "FAIL [$t]: $($_.Exception.Message)" }
    Start-Sleep -Seconds 3
  }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File 'c:\Users\Corentin\Documents\lol\wwe\tools\build-data.ps1'
