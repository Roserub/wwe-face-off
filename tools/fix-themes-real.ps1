# Passe de correction : remplace les covers/faux positifs par les VRAIES versions
# (artiste officiel WWE ou groupe licencie reel) d'apres une table tools\*.psv.
# Si introuvable : garde une cover du BON morceau, sinon bascule en [ambiance].
param([string]$Table = 'real-themes.psv')
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$psvF = Join-Path $root 'tools\themes-found.psv'
$tblF = Join-Path $root ('tools\' + $Table)
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/3.0'
$coverRx = 'it lives|ansoland|geek music|florian haack|karaoke|tribute|8-bit|8 bit|white knight|suplex sound|styzmask|meat sauce|vox freaks|the l train'

function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=15&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
function Norm([string]$s) { return (($s -replace "[^A-Za-z0-9 ]", ' ') -replace '\s+', ' ').Trim().ToLowerInvariant() }

$lines = Get-Content -Encoding UTF8 $psvF
$byslug = @{}
for ($i = 0; $i -lt $lines.Count; $i++) { $byslug[$lines[$i].Split('|')[0]] = $i }
# pool ambiance existant
$ambPool = @()
foreach ($l in $lines) { $p = $l.Split('|'); if ($p.Length -ge 4 -and $p[1] -match '\[ambiance\]' -and $p[3]) { $ambPool += ,$p } }

$tbl = Get-Content -Encoding UTF8 $tblF | Select-Object -Skip 1 | Where-Object { $_.Trim() }
$fixed = 0; $kept = 0; $amb = 0; $report = @()
$n = 0
foreach ($row in $tbl) {
  $n++
  $parts = $row.Split('|')
  if ($parts.Count -lt 4) { continue }
  $slug   = $parts[0]
  $titre  = $parts[1]
  $terms  = $parts[$parts.Count - 1]
  $artRx  = ($parts[2..($parts.Count - 2)]) -join '|'
  if (-not $byslug.ContainsKey($slug)) { continue }

  $curr = $lines[$byslug[$slug]].Split('|')
  $nameToks = ($slug -split '-') | Where-Object { $_.Length -gt 2 }
  $titleToks = (Norm $titre) -split ' ' | Where-Object { $_.Length -gt 2 }

  $best = $null; $bestRank = 0
  foreach ($term in ($terms -split ';')) {
    foreach ($t in (Search-Itunes $term)) {
      if (-not $t.previewUrl) { continue }
      $track = Norm $t.trackName; $artist = Norm $t.artistName
      $rawArtist = ('' + $t.artistName).ToLowerInvariant()
      $hay = "$track $artist"
      if ($hay -match $coverRx) { continue }
      # Norm() enleve les symboles : tester aussi l'artiste brut (sinon 'cfo$' ne matche jamais)
      if ($artist -notmatch $artRx -and $rawArtist -notmatch $artRx) { continue }
      $tHit = $false
      foreach ($tk in $titleToks) { if ($track.Contains($tk)) { $tHit = $true } }
      $nHit = $false
      foreach ($tk in $nameToks) { if ($hay.Contains($tk)) { $nHit = $true } }
      if (-not ($tHit -or $nHit)) { continue }
      $rank = 1
      if ($rawArtist -match 'def rebel|cfo|jim johnston|^wwe') { $rank += 3 }
      if ($tHit) { $rank += 2 }
      if ($nHit) { $rank += 2 }
      if ($track -match '^wwe') { $rank += 1 }
      if ($rank -gt $bestRank) { $bestRank = $rank; $best = $t }
    }
    Start-Sleep -Milliseconds 2600
    if ($best -and $bestRank -ge 7) { break }
  }

  if ($best) {
    $lines[$byslug[$slug]] = "$slug|$($best.trackName)|$($best.artistName)|$($best.previewUrl)"
    $fixed++
    $report += "FIX   $slug -> $($best.trackName) [$($best.artistName)]"
  } else {
    # cover du BON morceau ? on garde. sinon ambiance.
    $currTrack = Norm $curr[1]
    $rightSong = $false
    foreach ($tk in $titleToks) { if ($currTrack.Contains($tk)) { $rightSong = $true } }
    if ($rightSong -and $curr[1] -notmatch '\[ambiance\]') {
      $kept++
      $report += "GARDE $slug (cover du bon morceau) : $($curr[1])"
    } elseif ($curr[1] -match '\[ambiance\]') {
      $report += "AMB=  $slug (deja ambiance)"
    } elseif ($ambPool.Count) {
      $p = $ambPool[$n % $ambPool.Count]
      $lines[$byslug[$slug]] = "$slug|$($p[1])|$($p[2])|$($p[3])"
      $amb++
      $report += "AMB   $slug (faux positif remplace) : etait '$($curr[1])'"
    }
  }
  if ($n % 15 -eq 0) { Write-Host "  ...$n/$($tbl.Count)" }
}

$lines | Set-Content -Path $psvF -Encoding UTF8
$report | Set-Content -Path (Join-Path $root ('tools\fix-report-' + [IO.Path]::GetFileNameWithoutExtension($Table) + '.txt')) -Encoding UTF8
Write-Host "===="
Write-Host ("CORRIGES (vraie version): {0}  |  COVERS DU BON MORCEAU GARDEES: {1}  |  BASCULES EN AMBIANCE: {2}" -f $fixed, $kept, $amb)
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
