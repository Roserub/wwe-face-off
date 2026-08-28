# Audit complet des themes : URL vivante, artiste officiel, correspondance nom, doublons.
# Sortie : tools\audit-themes.txt (+ resume console)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$rows = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'roster.csv') | ConvertFrom-Csv
$psv  = Get-Content -Encoding UTF8 (Join-Path $root 'tools\themes-found.psv')

function Get-Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
  }
  ($sb.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')
}
$nameBySlug = @{}
foreach ($r in $rows) { $nameBySlug[(Get-Slug $r.name)] = $r.name }

$official = 'def rebel|cfo\$|jim johnston|^wwe$|wwe |dale oliver'
$coverRx  = 'it lives|ansoland|geek music|florian haack|karaoke|tribute|8-bit|8 bit|cover|instrumental|the l train|vox freaks'
$stop = @('the','and','jr','sr')

$dead = @(); $review = @(); $amb = @(); $okCount = 0
$urlSeen = @{}; $dupes = @()

$i = 0
foreach ($l in $psv) {
  $i++
  $p = $l.Split('|')
  $slug = $p[0]
  if ($p.Length -lt 4 -or $p[1] -eq 'MISS' -or -not $p[3]) { $dead += "$slug|AUCUN THEME"; continue }
  $track = $p[1]; $artist = $p[2]; $url = $p[3]
  $name = $nameBySlug[$slug]
  if (-not $name) { continue }

  # doublon d'URL (hors ambiance)
  if ($track -notmatch '\[ambiance\]') {
    if ($urlSeen.ContainsKey($url)) { $dupes += "$slug + $($urlSeen[$url]) -> $track" } else { $urlSeen[$url] = $slug }
  }

  # URL vivante ?
  $alive = $false
  try {
    $req = [Net.HttpWebRequest]::Create($url); $req.Method = 'HEAD'; $req.Timeout = 12000
    $req.UserAgent = 'Mozilla/5.0'
    $resp = $req.GetResponse(); $alive = ($resp.StatusCode -eq 'OK'); $resp.Close()
  } catch { $alive = $false }
  if (-not $alive) { $dead += "$slug|$track|$artist|URL MORTE" ; continue }

  if ($track -match '\[ambiance\]') { $amb += "$slug -> $track"; continue }

  $hay = ("$track $artist").ToLowerInvariant()
  $tokens = ($name.ToLowerInvariant() -split '[^a-z0-9]+') | Where-Object { $_.Length -gt 2 -and $stop -notcontains $_ }
  $nameHit = $false
  foreach ($tk in $tokens) { if ($hay.Contains($tk)) { $nameHit = $true } }
  $isOfficial = ($artist.ToLowerInvariant() -match $official)
  $isCover = ($hay -match $coverRx)

  if ($nameHit -and $isOfficial -and -not $isCover) { $okCount++ }
  else {
    $flags = @()
    if (-not $nameHit)  { $flags += 'NOM?' }
    if (-not $isOfficial) { $flags += 'ARTISTE?' }
    if ($isCover)       { $flags += 'COVER' }
    $review += ("{0,-22} | {1,-46} | {2,-28} | {3}" -f $slug, $track, $artist, ($flags -join ','))
  }
  if ($i % 40 -eq 0) { Write-Host "  ...$i/$($psv.Count)" }
}

$out = @()
$out += "=== AUDIT THEMES ($($psv.Count) entrees) ==="
$out += "OK (nom + artiste officiel) : $okCount"
$out += "AMBIANCE (fallback assume)  : $($amb.Count)"
$out += "A REVOIR                    : $($review.Count)"
$out += "MORTS / ABSENTS             : $($dead.Count)"
$out += "DOUBLONS D'URL              : $($dupes.Count)"
$out += ''
$out += '--- MORTS / ABSENTS ---'; $out += $dead
$out += ''
$out += '--- DOUBLONS ---'; $out += $dupes
$out += ''
$out += '--- A REVOIR ---'; $out += $review
$out += ''
$out += '--- AMBIANCE ---'; $out += $amb
$out | Set-Content -Path (Join-Path $root 'tools\audit-themes.txt') -Encoding UTF8
$out | Select-Object -First 6 | ForEach-Object { Write-Host $_ }
Write-Host "-> tools\audit-themes.txt"
