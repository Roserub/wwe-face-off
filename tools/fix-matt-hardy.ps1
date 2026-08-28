# Matt Hardy : "Live for the Moment" (Monster Magnet) - chercher aussi sous compilation WWE.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$psvF = Join-Path $root 'tools\themes-found.psv'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/3.3'
function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=20&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
$best = $null
foreach ($term in @('WWE Live for the Moment Matt Hardy','Live for the Moment WWE Anthology','Monster Magnet Live for the Moment WWE','WWE Matt Hardy entrance theme')) {
  foreach ($t in (Search-Itunes $term)) {
    if (-not $t.previewUrl) { continue }
    $track = ('' + $t.trackName).ToLowerInvariant()
    $artist = ('' + $t.artistName).ToLowerInvariant()
    if ("$track $artist" -match 'karaoke|tribute|8-bit|ansoland|it lives|geek music|florian haack') { continue }
    if ($track -match 'live for the moment' -or ($track -match 'matt hardy' -and $artist -match 'wwe|jim johnston|cfo|monster magnet')) { $best = $t; break }
  }
  Start-Sleep -Milliseconds 2600
  if ($best) { break }
}
if ($best) {
  $lines = Get-Content -Encoding UTF8 $psvF | ForEach-Object {
    if ($_.Split('|')[0] -eq 'matt-hardy') { "matt-hardy|$($best.trackName)|$($best.artistName)|$($best.previewUrl)" } else { $_ }
  }
  $lines | Set-Content -Path $psvF -Encoding UTF8
  Write-Host "OK matt-hardy -> $($best.trackName) [$($best.artistName)]"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
} else { Write-Host "matt-hardy : rien de mieux, on garde l ambiance" }
