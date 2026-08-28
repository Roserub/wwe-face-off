# Croise les catcheurs sans theme avec l'index des compositeurs (tools\composer-index.psv).
# Regle : le nom de ring (ou tous ses mots significatifs) doit figurer dans le TITRE du morceau.
$ErrorActionPreference = 'Continue'
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$psvF = Join-Path $root 'tools\themes-found.psv'
$idxF = Join-Path $root 'tools\composer-index.psv'

$rows = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'roster.csv') | ConvertFrom-Csv
function Get-Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
  }
  ($sb.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')
}
function Norm([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
  }
  (($sb.ToString() -replace "[^A-Za-z0-9 ]", ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
}
$nameBySlug = @{}
foreach ($r in $rows) { $nameBySlug[(Get-Slug $r.name)] = $r.name }

# noms de scene alternatifs / equipes
$aliases = @{
  'awesome-kong'='kharma'; 'hideo-itami'='kenta'; 'big-cass'='enzo|cass|sawft'; 'enzo-amore'='enzo|sawft'
  'luke-gallows'='gallows|omen'; 'karl-anderson'='anderson|omen'; 'ruby-riott'='riott'; 'sarah-logan'='riott'
  'peyton-royce'='iiconic'; 'billie-kay'='iiconic'; 'tucker'='heavy machinery|otis'; 'wes-lee'='msk'
  'katana-chance'='chance|carter'; 'kayden-carter'='chance|carter'; 'gigi-dolin'='toxic attraction|dolin'
  'cameron'='funkadactyl|cameron'; 'brooke-adams'='tessmacher|tease'; 'ec3'='ec3|carter'
  'santos-escobar'='escobar|legado'; 'roderick-strong'='undisputed|strong'; 'mustafa-ali'='ali'
  'elias'='elias|walk with'; 'andrade'='andrade|almas|idolo'; 'neville'='neville|adrian'
  'kristal-marshall'='kristal'; 'shotzi'='shotzi|blackheart'; 'toni-storm'='toni storm'
  'lance-cade'='cade'; 'trevor-murdoch'='murdoch'; 'kenny-dykstra'='dykstra|kenny'
  'rene-dupree'='dupree|resistance'; 'charlie-haas'='haas|world s greatest'
}
$idx = @()
foreach ($l in (Get-Content -Encoding UTF8 $idxF)) {
  $p = $l.Split('|')
  if ($p.Length -lt 4) { continue }
  $idx += [pscustomobject]@{ src=$p[0]; title=$p[1]; artist=$p[2]; url=$p[3]; nt=(Norm $p[1]); na=(Norm $p[2]) }
}
Write-Host "index : $($idx.Count) morceaux"

$lines = Get-Content -Encoding UTF8 $psvF
$targets = @()
foreach ($l in $lines) { $p = $l.Split('|'); if ($p.Length -lt 4 -or $p[1] -eq 'MISS' -or -not $p[3]) { $targets += $p[0] } }
Write-Host "sans theme : $($targets.Count)"

$coverRx = 'karaoke|tribute|8 bit|made famous|originally performed|instrumental version|as made popular'
$found = 0; $rep = @()
foreach ($slug in $targets) {
  $name = $nameBySlug[$slug]
  if (-not $name) { continue }
  $nn = Norm $name
  $toks = $nn -split ' ' | Where-Object { $_.Length -gt 2 -and $_ -ne 'the' }
  $aliasRx = $aliases[$slug]
  $best = $null; $bestScore = 0
  foreach ($t in $idx) {
    if ($t.nt -match $coverRx) { continue }
    $score = 0
    if ($t.nt.Contains($nn)) { $score = 10 }                       # nom complet dans le titre
    elseif ($toks.Count -gt 1) {
      $all = $true; foreach ($tk in $toks) { if (-not $t.nt.Contains($tk)) { $all = $false } }
      if ($all) { $score = 8 }
    }
    if ($score -eq 0 -and $aliasRx -and $t.nt -match $aliasRx) { $score = 6 }
    if ($score -eq 0) { continue }
    if ($t.na -match 'def rebel|cfo|jim johnston|^wwe|all elite|dale oliver|mikey rukus|downstait') { $score += 3 }
    if ($t.nt -match '^wwe|theme|entrance') { $score += 1 }
    if ($score -gt $bestScore) { $bestScore = $score; $best = $t }
  }
  if ($best -and $bestScore -ge 7) {
    $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq $slug) { "$slug|$($best.title)|$($best.artist)|$($best.url)" } else { $_ } }
    $found++
    $rep += "TROUVE  $slug -> $($best.title) [$($best.artist)] ($($best.src), score $bestScore)"
    Write-Host "TROUVE  $slug -> $($best.title) [$($best.artist)]"
  } else {
    $rep += "RIEN    $slug"
  }
}
$lines | Set-Content -Path $psvF -Encoding UTF8
$rep | Set-Content -Path (Join-Path $root 'tools\match-missing-report.txt') -Encoding UTF8
Write-Host '===='
Write-Host ("NOUVEAUX THEMES : {0} / {1}" -f $found, $targets.Count)
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
