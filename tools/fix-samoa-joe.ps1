# Samoa Joe a herite du theme de Jacob Fatu ("Samoan Destroyer") : exiger "joe" dans le titre.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$psvF = Join-Path $root 'tools\themes-found.psv'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/3.1'
function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=15&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
$best = $null
foreach ($term in @('WWE Destroyer Samoa Joe CFO','WWE Samoa Joe entrance theme','Samoa Joe NXT theme WWE')) {
  foreach ($t in (Search-Itunes $term)) {
    if (-not $t.previewUrl) { continue }
    $track = ('' + $t.trackName).ToLowerInvariant()
    $artist = ('' + $t.artistName).ToLowerInvariant()
    if ($track -notmatch 'joe') { continue }                      # le nom DOIT etre dans le titre
    if ($artist -notmatch 'cfo|def rebel|jim johnston|^wwe') { continue }
    $best = $t; break
  }
  Start-Sleep -Milliseconds 2600
  if ($best) { break }
}
$lines = Get-Content -Encoding UTF8 $psvF
if ($best) {
  $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq 'samoa-joe') { "samoa-joe|$($best.trackName)|$($best.artistName)|$($best.previewUrl)" } else { $_ } }
  Write-Host "OK samoa-joe -> $($best.trackName) [$($best.artistName)]"
} else {
  # pas de version officielle : ambiance plutot que le theme d'un autre catcheur
  $amb = @(); foreach ($l in $lines) { $p = $l.Split('|'); if ($p.Length -ge 4 -and $p[1] -match '\[ambiance\]' -and $p[3]) { $amb += ,$p } }
  if ($amb.Count) {
    $p = $amb[0]
    $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq 'samoa-joe') { "samoa-joe|$($p[1])|$($p[2])|$($p[3])" } else { $_ } }
    Write-Host "AMBIANCE samoa-joe -> $($p[1])"
  }
}
$lines | Set-Content -Path $psvF -Encoding UTF8
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
