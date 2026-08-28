# Correctif : les alias matchaient en sous-chaine (cade dans "Academy", omen dans "Moment",
# cass dans "Cassidy", chance dans "No Chance In Hell"). On repasse en frontieres de mots
# et on annule les faux positifs de la passe precedente.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$psvF = Join-Path $root 'tools\themes-found.psv'
$idxF = Join-Path $root 'tools\composer-index.psv'

$bad = @('kenny-dykstra','lance-cade','luke-gallows','karl-anderson','big-cass','mustafa-ali',
         'cameron','katana-chance','kayden-carter','enzo-amore')
$lines = Get-Content -Encoding UTF8 $psvF | ForEach-Object {
  if ($bad -contains $_.Split('|')[0]) { "$($_.Split('|')[0])|MISS||" } else { $_ }
}

$rows = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'roster.csv') | ConvertFrom-Csv
function Get-Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD); $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) { if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) } }
  ($sb.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')
}
function Norm([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD); $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) { if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) } }
  (($sb.ToString() -replace "[^A-Za-z0-9 ]", ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
}
$nameBySlug = @{}
foreach ($r in $rows) { $nameBySlug[(Get-Slug $r.name)] = $r.name }

# alias en EXPRESSIONS COMPLETES uniquement (jamais un mot isole trop court/commun)
$aliases = @{
  'awesome-kong'    = 'kharma'
  'hideo-itami'     = 'hideo itami|kenta'
  'big-cass'        = 'sawft|enzo amore|big cass'
  'enzo-amore'      = 'sawft|enzo amore'
  'luke-gallows'    = 'omen in the sky|gallows'
  'karl-anderson'   = 'omen in the sky|karl anderson'
  'ruby-riott'      = 'riott squad|ruby riott'
  'sarah-logan'     = 'riott squad|sarah logan'
  'peyton-royce'    = 'iiconic'
  'billie-kay'      = 'iiconic'
  'tucker'          = 'heavy machinery'
  'wes-lee'         = 'wes lee'
  'katana-chance'   = 'katana chance|chance carter'
  'kayden-carter'   = 'kayden carter|chance carter'
  'gigi-dolin'      = 'toxic attraction|gigi dolin'
  'cameron'         = 'funkadactyl'
  'brooke-adams'    = 'tessmacher|i tease you touch'
  'ec3'             = 'ethan carter'
  'santos-escobar'  = 'legado del fantasma|santos escobar'
  'roderick-strong' = 'undisputed|roderick strong'
  'elias'           = 'walk with elias'
  'andrade'         = 'andrade|cien almas'
  'neville'         = 'break orbit|adrian neville'
  'shotzi'          = 'shotzi'
  'rene-dupree'     = 'la resistance|rene dupree'
  'charlie-haas'    = 'world s greatest'
  'kristal-marshall'= 'kristal marshall'
  'mustafa-ali'     = 'mustafa ali'
  'lance-cade'      = 'cade murdoch|lance cade'
  'trevor-murdoch'  = 'cade murdoch|trevor murdoch'
  'kenny-dykstra'   = 'kenny dykstra|spirit squad'
}
$idx = @()
foreach ($l in (Get-Content -Encoding UTF8 $idxF)) {
  $p = $l.Split('|'); if ($p.Length -lt 4) { continue }
  $idx += [pscustomobject]@{ src=$p[0]; title=$p[1]; artist=$p[2]; url=$p[3]; nt=(Norm $p[1]); na=(Norm $p[2]) }
}
$targets = @()
foreach ($l in $lines) { $p = $l.Split('|'); if ($p.Length -lt 4 -or $p[1] -eq 'MISS' -or -not $p[3]) { $targets += $p[0] } }
Write-Host "index $($idx.Count) morceaux | sans theme : $($targets.Count)"

$coverRx = 'karaoke|tribute|8 bit|made famous|originally performed|as made popular'
$found = 0; $rep = @()
foreach ($slug in $targets) {
  $name = $nameBySlug[$slug]; if (-not $name) { continue }
  $nn = Norm $name
  $aliasRx = $aliases[$slug]
  $best = $null; $bestScore = 0
  foreach ($t in $idx) {
    if ($t.nt -match $coverRx) { continue }
    $score = 0
    if ($t.nt -match ('\b' + [regex]::Escape($nn) + '\b')) { $score = 10 }        # nom complet, mot entier
    elseif ($aliasRx -and $t.nt -match ('\b(' + $aliasRx + ')\b')) { $score = 7 } # alias, mot entier
    if ($score -eq 0) { continue }
    if ($t.na -match 'def rebel|cfo|jim johnston|^wwe|all elite|dale oliver|mikey rukus|downstait|ring of honor') { $score += 3 }
    if ($t.nt -match '^wwe|theme|entrance') { $score += 1 }
    if ($score -gt $bestScore) { $bestScore = $score; $best = $t }
  }
  if ($best -and $bestScore -ge 9) {
    $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq $slug) { "$slug|$($best.title)|$($best.artist)|$($best.url)" } else { $_ } }
    $found++
    $rep += "TROUVE  $slug -> $($best.title) [$($best.artist)] (score $bestScore)"
    Write-Host "TROUVE  $slug -> $($best.title) [$($best.artist)]"
  } else { $rep += "RIEN    $slug" }
}
$lines | Set-Content -Path $psvF -Encoding UTF8
$rep | Set-Content -Path (Join-Path $root 'tools\match-missing-report.txt') -Encoding UTF8
Write-Host '===='
Write-Host ("NOUVEAUX THEMES : {0} / {1}" -f $found, $targets.Count)
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
