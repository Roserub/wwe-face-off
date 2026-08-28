# Passe finale : les 6 dernieres vraies erreurs + doublon The Miz.
# Regle stricte : le nom du catcheur (ou le titre exact) DOIT etre dans le morceau, sinon ambiance.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$psvF = Join-Path $root 'tools\themes-found.psv'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/3.2'
function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=15&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
# slug ; regex titre EXIGE ; regex artiste EXIGE ; termes
$jobs = @(
  @{slug='matt-hardy';    trackRx='live for the moment'; artRx='monster magnet';                 terms=@('Live for the Moment Monster Magnet')},
  @{slug='bray-wyatt';    trackRx='live in fear';        artRx='mark crozer|wwe|jim johnston|cfo'; terms=@('Live in Fear Mark Crozer','WWE Live in Fear Bray Wyatt')},
  @{slug='the-miz';       trackRx='i came to play|awesome';  artRx='downstait|wwe|jim johnston|cfo'; terms=@('I Came to Play Downstait','WWE I Came to Play The Miz')},
  @{slug='ilja-dragunov'; trackRx='dragunov|unbesiegbar'; artRx='def rebel|cfo|wwe|jim johnston'; terms=@('WWE Ilja Dragunov theme def rebel','WWE Unbesiegbar Ilja Dragunov')},
  @{slug='eric-young';    trackRx='eric young';          artRx='def rebel|cfo|wwe|jim johnston'; terms=@('WWE Eric Young theme','NXT Eric Young entrance theme')},
  @{slug='kairi-sane';    trackRx='kairi|pirate';        artRx='def rebel|cfo|wwe|jim johnston'; terms=@('WWE Kairi Sane theme CFO','WWE Pirate Princess Kairi Sane')},
  @{slug='luke-harper';   trackRx='harper|broken bones'; artRx='def rebel|cfo|wwe|jim johnston'; terms=@('WWE Luke Harper theme CFO','WWE Broken Bones Luke Harper')}
)
$lines = Get-Content -Encoding UTF8 $psvF
$amb = @(); foreach ($l in $lines) { $p = $l.Split('|'); if ($p.Length -ge 4 -and $p[1] -match '\[ambiance\]' -and $p[3]) { $amb += ,$p } }
$k = 0
foreach ($j in $jobs) {
  $best = $null
  foreach ($term in $j.terms) {
    foreach ($t in (Search-Itunes $term)) {
      if (-not $t.previewUrl) { continue }
      $track = ('' + $t.trackName).ToLowerInvariant()
      $artist = ('' + $t.artistName).ToLowerInvariant()
      if ($track -notmatch $j.trackRx) { continue }
      if ($artist -notmatch $j.artRx) { continue }
      if ("$track $artist" -match 'karaoke|tribute|8-bit|ansoland|it lives|geek music|florian haack') { continue }
      $best = $t; break
    }
    Start-Sleep -Milliseconds 2600
    if ($best) { break }
  }
  if ($best) {
    $new = "$($j.slug)|$($best.trackName)|$($best.artistName)|$($best.previewUrl)"
    Write-Host "OK       $($j.slug) -> $($best.trackName) [$($best.artistName)]"
  } elseif ($amb.Count) {
    $p = $amb[$k % $amb.Count]; $k++
    $new = "$($j.slug)|$($p[1])|$($p[2])|$($p[3])"
    Write-Host "AMBIANCE $($j.slug) -> $($p[1])"
  } else { $new = $null }
  if ($new) { $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq $j.slug) { $new } else { $_ } } }
}
$lines | Set-Content -Path $psvF -Encoding UTF8
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
