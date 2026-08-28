# Cherche une meilleure photo de Kristal Marshall dans le HTML Fandom (images d'article, pas la vignette API)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$imgDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'images')
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$best = $null; $bestKb = 0
foreach ($page in @('https://prowrestling.fandom.com/wiki/Kristal_Marshall','https://prowrestling.fandom.com/wiki/Special:Search?query=Kristal+Marshall')) {
  try {
    $resp = Invoke-WebRequest -Uri $page -Headers @{ 'User-Agent' = $ua } -TimeoutSec 40 -UseBasicParsing
    $urls = [regex]::Matches($resp.Content, 'https://static\.wikia\.nocookie\.net/[^"'' ]+?\.(?:jpg|jpeg|png|webp)') | ForEach-Object { $_.Value } | Sort-Object -Unique
    foreach ($u in $urls) {
      if ($u -notmatch 'kristal|Kristal') { continue }
      $clean = ($u -split '/revision')[0]
      $tmp = Join-Path $env:TEMP 'kr-test'
      try {
        Invoke-WebRequest -Uri $clean -OutFile $tmp -Headers @{ 'User-Agent' = $ua } -TimeoutSec 40 -UseBasicParsing
        $kb = [math]::Round((Get-Item $tmp).Length / 1KB)
        Write-Host "  candidat $kb KB : $($clean.Substring(0,[Math]::Min(95,$clean.Length)))"
        if ($kb -gt $bestKb) { $bestKb = $kb; $best = $clean }
      } catch { }
      Start-Sleep -Milliseconds 600
    }
  } catch { Write-Host "page fail: $($_.Exception.Message)" }
}
if ($best -and $bestKb -ge 45) {
  $ext = 'jpg'; if ($best -match '\.(jpe?g|png|webp)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $out = Join-Path $env:TEMP "kristal-final.$ext"
  Invoke-WebRequest -Uri $best -OutFile $out -Headers @{ 'User-Agent' = $ua } -TimeoutSec 60 -UseBasicParsing
  Get-ChildItem $imgDir -Filter 'kristal-marshall.*' -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $out (Join-Path $imgDir "kristal-marshall.$ext")
  Write-Host "OK kristal-marshall <- Fandom HTML ($bestKb KB)"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\build-data.ps1'
} else { Write-Host "Rien de mieux trouve (meilleur = $bestKb KB) - on garde la version actuelle" }
