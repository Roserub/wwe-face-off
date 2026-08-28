# Matt Hardy : "Live for the Moment" (Monster Magnet) absent du store US -> tester les autres pays.
# Repli : "The Deletion Anthem (Matt Hardy)" = son autre vrai theme (ere Broken/Woken).
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$psvF = Join-Path $root 'tools\themes-found.psv'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/3.4'
function Search-Itunes([string]$term, [string]$country) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + "&media=music&entity=song&limit=20&country=$country"
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
$best = $null; $where = ''
foreach ($c in @('GB','DE','CA','FR','AU','JP','NL','SE')) {
  foreach ($term in @('Monster Magnet Live for the Moment','WWE Anthology Live for the Moment')) {
    foreach ($t in (Search-Itunes $term $c)) {
      if (-not $t.previewUrl) { continue }
      $track = ('' + $t.trackName).ToLowerInvariant()
      $artist = ('' + $t.artistName).ToLowerInvariant()
      if ($track -match 'live for the moment' -and $artist -match 'monster magnet|wwe') { $best = $t; $where = $c; break }
    }
    Start-Sleep -Milliseconds 2200
    if ($best) { break }
  }
  if ($best) { break }
  Write-Host "  store $c : rien"
}
if (-not $best) {
  # repli : son autre theme reel (Deletion Anthem), plutot qu'une ambiance anonyme
  foreach ($t in (Search-Itunes 'Deletion Anthem Matt Hardy' 'US')) {
    if ($t.previewUrl -and ('' + $t.trackName) -match 'Deletion Anthem') { $best = $t; $where = 'US (Deletion Anthem)'; break }
  }
}
if ($best) {
  $lines = Get-Content -Encoding UTF8 $psvF | ForEach-Object {
    if ($_.Split('|')[0] -eq 'matt-hardy') { "matt-hardy|$($best.trackName)|$($best.artistName)|$($best.previewUrl)" } else { $_ }
  }
  $lines | Set-Content -Path $psvF -Encoding UTF8
  Write-Host "OK matt-hardy [$where] -> $($best.trackName) [$($best.artistName)]"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
} else { Write-Host "matt-hardy : introuvable partout, ambiance conservee" }
