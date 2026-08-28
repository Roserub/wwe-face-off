# Kalisto / Gran Metalik : leur vrai theme (Lucha Lucha, Lucha House Party) n'existe sur aucune
# API d'extraits. On remplace l'ambiance generique (theme de Raw) par une ambiance lucha coherente.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$psvF = Join-Path $root 'tools\themes-found.psv'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/3.5'
function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=15&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
$picks = @()
foreach ($term in @('Lucha Libre Instrumental PURE VIRTUAL','Lucha Libre Inf','Santa Vs the Luchadors Mariachi Death Squad')) {
  foreach ($t in (Search-Itunes $term)) {
    if ($t.previewUrl -and ('' + $t.trackName) -match 'Lucha') { $picks += $t; break }
  }
  Start-Sleep -Milliseconds 2600
  if ($picks.Count -ge 2) { break }
}
if ($picks.Count -eq 0) { Write-Host 'aucune piste lucha trouvee - on ne touche a rien'; exit 0 }
$lines = Get-Content -Encoding UTF8 $psvF
$i = 0
foreach ($slug in @('kalisto','gran-metalik')) {
  $t = $picks[$i % $picks.Count]; $i++
  $lines = $lines | ForEach-Object {
    if ($_.Split('|')[0] -eq $slug) { "$slug|$($t.trackName) [ambiance lucha]|$($t.artistName)|$($t.previewUrl)" } else { $_ }
  }
  Write-Host "OK $slug -> $($t.trackName) [$($t.artistName)]"
}
$lines | Set-Content -Path $psvF -Encoding UTF8
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
