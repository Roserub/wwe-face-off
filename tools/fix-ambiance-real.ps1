# Derniere chasse aux vrais themes pour les entrees [ambiance] : elargit a TNA/Impact (Dale Oliver),
# AEW (Mikey Rukus), ROH, indie. Regle stricte : le nom du catcheur DOIT figurer dans le titre.
# Ce qui reste introuvable -> MISS (aucun theme) : en jeu, seul le theme de l'adversaire jouera.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$psvF = Join-Path $root 'tools\themes-found.psv'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/4.0'
$coverRx = 'it lives|ansoland|geek music|florian haack|karaoke|tribute|8-bit|8 bit|white knight|suplex sound|meat sauce|vox freaks'
$wrestlingArt = 'wwe|tna|impact wrestling|all elite|aew|ring of honor|new japan|dale oliver|mikey rukus|def rebel|cfo|jim johnston|serg salinas|downstait'

$rows = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'roster.csv') | ConvertFrom-Csv
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

# cas nommes par l'utilisateur / titres connus (trackRx = ce que le titre DOIT contenir)
$specials = @{
  'peyton-royce'  = @{ trackRx = 'iiconic'; terms = @('IIconics WWE theme','WWE IIconic Peyton Royce Billie Kay') }
  'billie-kay'    = @{ trackRx = 'iiconic'; terms = @('IIconics WWE theme','WWE IIconic Peyton Royce Billie Kay') }
  'ec3'           = @{ trackRx = 'ec3|carter'; terms = @('EC3 theme Impact Wrestling','EC3 entrance theme','Ethan Carter III TNA theme') }
  'ruby-riott'    = @{ trackRx = 'riott|ruby'; terms = @('Riott Squad WWE theme','Ruby Riott entrance theme','Ruby Soho AEW theme') }
  'brooke-adams'  = @{ trackRx = 'tease|brooke'; terms = @('I Tease You Touch Dale Oliver','TNA Brooke Tessmacher theme','I Tease You Touch TNA') }
  'awesome-kong'  = @{ trackRx = 'kong|kharma'; terms = @('Awesome Kong TNA theme Dale Oliver','Kharma WWE theme','Awesome Kong entrance theme') }
  'hideo-itami'   = @{ trackRx = 'itami|kenta'; terms = @('Hideo Itami NXT theme','KENTA NJPW theme','Kenta entrance theme') }
  'eric-young'    = @{ trackRx = 'eric young|showtime'; terms = @('Eric Young TNA theme Dale Oliver','Showtime Eric Young TNA') }
  'sabu'          = @{ trackRx = 'sabu|huka'; terms = @('Sabu ECW theme','Huka Blues Sabu','Sabu entrance theme') }
  'stevie-richards'= @{ trackRx = 'stevie|richards'; terms = @('Stevie Richards ECW theme','Stevie Richards entrance theme') }
  'matt-riddle'   = @{ trackRx = 'riddle|bro'; terms = @('Matt Riddle WWE theme','Riddle entrance theme WWE') }
  'toni-storm'    = @{ trackRx = 'storm|timeless'; terms = @('Toni Storm AEW theme Mikey Rukus','Toni Storm NXT theme','Timeless Toni Storm theme') }
  'shayna-baszler'= @{ trackRx = 'baszler|spades'; terms = @('Shayna Baszler NXT theme','Queen of Spades Shayna Baszler WWE') }
  'braun-strowman'= @{ trackRx = 'strowman|stronger'; terms = @('Braun Strowman WWE theme','I Am Stronger Braun Strowman WWE') }
  'kairi-sane'    = @{ trackRx = 'kairi|pirate'; terms = @('Kairi Sane WWE theme','Kairi Sane NXT entrance theme') }
  'samoa-joe'     = @{ trackRx = 'samoa joe|joe'; terms = @('Samoa Joe TNA theme Dale Oliver','Samoa Joe AEW theme Mikey Rukus','Samoa Joe entrance theme') }
  'matt-hardy'    = @{ trackRx = 'hardy|deletion|obsolete'; terms = @('Matt Hardy TNA theme Dale Oliver','Broken Matt Hardy theme','Obsolete Matt Hardy') }
  'ilja-dragunov' = @{ trackRx = 'dragunov|unbesiegbar'; terms = @('Ilja Dragunov NXT theme','Unbesiegbar NXT UK theme') }
  'luke-harper'   = @{ trackRx = 'harper|brodie'; terms = @('Luke Harper WWE theme','Brodie Lee AEW theme Mikey Rukus') }
  'big-cass'      = @{ trackRx = 'cass|sawft'; terms = @('Enzo Amore Big Cass WWE theme','SAWFT Is a Sin WWE') }
  'enzo-amore'    = @{ trackRx = 'enzo|sawft'; terms = @('Enzo Amore Big Cass WWE theme','SAWFT Is a Sin WWE') }
}

function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=15&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}

$lines = Get-Content -Encoding UTF8 $psvF
$targets = @()
foreach ($l in $lines) { $p = $l.Split('|'); if ($p.Length -ge 2 -and $p[1] -match '\[ambiance\]') { $targets += $p[0] } }
Write-Host ("CIBLES (ambiance) : {0}" -f $targets.Count)

$found = 0; $dropped = 0; $rep = @()
$n = 0
foreach ($slug in $targets) {
  $n++
  $name = $nameBySlug[$slug]
  if (-not $name) { continue }
  $sp = $specials[$slug]
  $trackRx = if ($sp) { $sp.trackRx } else {
    (($name.ToLowerInvariant() -split '[^a-z0-9]+') | Where-Object { $_.Length -gt 3 -and $_ -ne 'the' }) -join '|'
  }
  if (-not $trackRx) { $trackRx = $name.ToLowerInvariant() }
  $terms = if ($sp) { $sp.terms } else {
    @("$name WWE theme", "$name entrance theme", "$name TNA theme", "$name AEW theme")
  }
  $best = $null
  foreach ($term in $terms) {
    foreach ($t in (Search-Itunes $term)) {
      if (-not $t.previewUrl) { continue }
      $track = ('' + $t.trackName).ToLowerInvariant()
      $artist = ('' + $t.artistName).ToLowerInvariant()
      if ("$track $artist" -match $coverRx) { continue }
      if ($track -notmatch $trackRx) { continue }              # nom/titre obligatoire dans le TITRE
      if ($artist -notmatch $wrestlingArt -and $track -notmatch 'theme|entrance') { continue }
      $best = $t; break
    }
    Start-Sleep -Milliseconds 2600
    if ($best) { break }
  }
  if ($best) {
    $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq $slug) { "$slug|$($best.trackName)|$($best.artistName)|$($best.previewUrl)" } else { $_ } }
    $found++
    $rep += "TROUVE $slug -> $($best.trackName) [$($best.artistName)]"
    Write-Host "[$n/$($targets.Count)] TROUVE $slug -> $($best.trackName) [$($best.artistName)]"
  } else {
    $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq $slug) { "$slug|MISS||" } else { $_ } }
    $dropped++
    $rep += "SANS THEME $slug"
  }
}
$lines | Set-Content -Path $psvF -Encoding UTF8
$rep | Set-Content -Path (Join-Path $root 'tools\fix-ambiance-report.txt') -Encoding UTF8
Write-Host '===='
Write-Host ("VRAIS THEMES TROUVES: {0}  |  SANS THEME (silence): {1}" -f $found, $dropped)
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
