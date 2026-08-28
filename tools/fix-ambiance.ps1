# Remplace les fallbacks "ambiance" (themes d'autres catcheurs = confus) par des themes
# d'emission WWE neutres (Raw/SmackDown), puis regenere themes.js avec nettoyage d'encodage.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/2.1'
$psvF = Join-Path $root 'tools\themes-found.psv'
$ambSlugs = (Get-Content (Join-Path $root 'tools\ambiance-slugs.txt') -Raw).Trim() -split ','

# pool de themes d'emission (neutres) : terme de recherche + tokens de validation
$showThemes = @(
  @{term='Rise Up Drowning Pool';            trackTok='rise up';            artTok='drowning pool'},
  @{term='Across the Nation Union Underground'; trackTok='across the nation'; artTok='union underground'},
  @{term='Burn It to the Ground Nickelback'; trackTok='burn it to the ground'; artTok='nickelback'},
  @{term='To Be Loved Papa Roach';           trackTok='to be loved';        artTok='papa roach'},
  @{term='Special Op Jim Johnston';          trackTok='special op';         artTok='jim johnston'}
)
function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=10&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
$pool = @()
foreach ($s in $showThemes) {
  foreach ($t in (Search-Itunes $s.term)) {
    if ($t.previewUrl -and ('' + $t.trackName).ToLowerInvariant().Contains($s.trackTok) -and ('' + $t.artistName).ToLowerInvariant().Contains($s.artTok)) {
      $pool += $t; Write-Host "POOL + $($t.trackName) [$($t.artistName)]"; break
    }
  }
  Start-Sleep -Milliseconds 2600
}
if ($pool.Count -eq 0) { Write-Host 'AUCUN theme d emission trouve - abandon'; exit 1 }

# reecrit le psv : les slugs ambiance recoivent un theme d'emission en round-robin
$lines = Get-Content -Encoding UTF8 $psvF
$out = @(); $j = 0
foreach ($l in $lines) {
  $slug = $l.Split('|')[0]
  if ($ambSlugs -contains $slug) {
    $t = $pool[$j % $pool.Count]; $j++
    $out += "$slug|$($t.trackName) [ambiance]|$($t.artistName)|$($t.previewUrl)"
  } else { $out += $l }
}
$out | Set-Content -Path $psvF -Encoding UTF8

# regenere themes.js depuis le psv, avec reparation des accents mojibake (UTF-8 lu en latin-1)
$fixPairs = @(
  @(0x00C3,0x00A9,0x00E9), @(0x00C3,0x00A8,0x00E8), @(0x00C3,0x00B6,0x00F6), @(0x00C3,0x00A1,0x00E1),
  @(0x00C3,0x00AD,0x00ED), @(0x00C3,0x00B3,0x00F3), @(0x00C3,0x00BA,0x00FA), @(0x00C3,0x00B1,0x00F1),
  @(0x00C3,0x00BC,0x00FC), @(0x00C3,0x00A4,0x00E4), @(0x00C3,0x00A7,0x00E7)
)
function Fix-Moji([string]$s) {
  $s = $s.Replace(([string][char]0x00E2 + [char]0x20AC + [char]0x201D), [string][char]0x2014)
  $s = $s.Replace(([string][char]0x00C2 + [char]0x00B7), [string][char]0x00B7)
  foreach ($p in $fixPairs) { $s = $s.Replace(([string][char]$p[0] + [char]$p[1]), [string][char]$p[2]) }
  return $s
}
$found = [ordered]@{}
foreach ($l in (Get-Content -Encoding UTF8 $psvF)) {
  $p = $l.Split('|')
  if ($p.Length -ge 4 -and $p[1] -ne 'MISS' -and $p[3]) {
    $found[$p[0]] = @{ u = $p[3]; t = (Fix-Moji ($p[1] + ' ' + [char]0x2014 + ' ' + $p[2])) }
  }
}
$json = $found | ConvertTo-Json -Compress -Depth 4
$js = "// Genere par tools\fix-ambiance.ps1 - extraits 30s officiels iTunes (previewUrl)`nwindow.THEMES = $json;`n"
[IO.File]::WriteAllText((Join-Path $root 'themes.js'), $js, (New-Object Text.UTF8Encoding($false)))
Write-Host '----'
Write-Host ("THEMES: {0} entrees -> themes.js ({1} ambiance emission)" -f $found.Count, $j)
