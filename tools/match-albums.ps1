# Croise les catcheurs sans theme avec l'index d'albums (tools\album-index.psv).
# Regle stricte : nom complet en mot entier dans le titre, ou alias explicite.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$psvF = Join-Path $root 'tools\themes-found.psv'
$idxF = Join-Path $root 'tools\album-index.psv'
if (-not (Test-Path $idxF)) { Write-Host 'index absent'; exit 1 }

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

# alias : expressions completes uniquement (jamais un mot court/commun)
$aliases = @{
  'mvp'='i m comin|montel vontavious'; 'heath-slater'='one man band|heath slater'
  'luke-harper'='luke harper|broken bones'; 'bo-dallas'='bo dallas|bolieve'
  'neville'='break orbit|adrian neville'; 'braun-strowman'='braun strowman|i am stronger'
  'elias'='walk with elias|drift away'; 'andrade'='cien almas|andrade'
  'matt-riddle'='matt riddle|hey bro'; 'ilja-dragunov'='ilja dragunov|unbesiegbar'
  'ric-flair'='ric flair|nature boy'; 'goldberg'='goldberg|invasion'
  'paul-london'='paul london'; 'brian-kendrick'='brian kendrick|man with a plan'
  'jamie-noble'='jamie noble'; 'chuck-palumbo'='chuck palumbo'; 'mike-knox'='mike knox'
  'kenny-dykstra'='kenny dykstra|spirit squad'; 'lance-cade'='lance cade|cade and murdoch'
  'trevor-murdoch'='trevor murdoch|cade and murdoch'; 'charlie-haas'='charlie haas|world s greatest'
  'rene-dupree'='rene dupree|la resistance'; 'funaki'='funaki'; 'kevin-thorn'='kevin thorn'
  'stevie-richards'='stevie richards'; 'sabu'='sabu'; 'luke-gallows'='luke gallows|omen in the sky'
  'karl-anderson'='karl anderson|omen in the sky'; 'curt-hawkins'='curt hawkins|face the facts'
  'yoshi-tatsu'='yoshi tatsu'; 'tyler-breeze'='tyler breeze|mmmgorgeous'
  'aiden-english'='aiden english|vaudevillains'; 'rhyno'='rhyno|man beast'
  'mojo-rawley'='mojo rawley|hype bros'; 'tucker'='heavy machinery'
  'hideo-itami'='hideo itami'; 'roderick-strong'='roderick strong|undisputed era'
  'ec3'='ec3|ethan carter'; 'eric-young'='eric young'; 'big-cass'='big cass|sawft'
  'enzo-amore'='enzo amore|sawft'; 'erick-rowan'='erick rowan'
  'buddy-murphy'='buddy murphy|opposite ends'; 'cedric-alexander'='cedric alexander'
  'mustafa-ali'='mustafa ali'; 'drew-gulak'='drew gulak'
  'santos-escobar'='santos escobar|legado del fantasma'; 'wes-lee'='wes lee|msk'
  'awesome-kong'='awesome kong|kharma'; 'carmella'='carmella|fabulous'
  'ruby-riott'='ruby riott|riott squad'; 'sonya-deville'='sonya deville'
  'mandy-rose'='mandy rose'; 'lacey-evans'='lacey evans'; 'shayna-baszler'='shayna baszler|queen of spades'
  'kairi-sane'='kairi sane'; 'dakota-kai'='dakota kai'; 'toni-storm'='toni storm'
  'zelina-vega'='zelina vega'; 'nikki-cross'='nikki cross'; 'dana-brooke'='dana brooke'
  'peyton-royce'='peyton royce|iiconic'; 'billie-kay'='billie kay|iiconic'
  'kristal-marshall'='kristal'; 'brooke-adams'='brooke adams|tessmacher'
  'cameron'='funkadactyls'; 'sarah-logan'='sarah logan|riott squad'
  'xia-li'='xia li'; 'shotzi'='shotzi'; 'tegan-nox'='tegan nox'; 'gigi-dolin'='gigi dolin|toxic attraction'
  'cora-jade'='cora jade'; 'katana-chance'='katana chance'; 'kayden-carter'='kayden carter'
  'alba-fyre'='alba fyre'; 'kalisto'='kalisto|lucha dragons'; 'gran-metalik'='gran metalik'
  'matt-hardy'='matt hardy|live for the moment'
}

$idx = @()
foreach ($l in (Get-Content -Encoding UTF8 $idxF)) {
  $p = $l.Split('|')
  if ($p.Length -lt 5) { continue }
  $idx += [pscustomobject]@{ src=$p[0]; title=$p[1]; artist=$p[2]; album=$p[3]; url=$p[4]; nt=(Norm $p[1]); na=(Norm $p[2]) }
}
Write-Host "index albums : $($idx.Count) pistes"

$lines = Get-Content -Encoding UTF8 $psvF
$targets = @()
foreach ($l in $lines) { $p = $l.Split('|'); if ($p.Length -lt 4 -or $p[1] -eq 'MISS' -or -not $p[3]) { $targets += $p[0] } }
Write-Host "sans theme : $($targets.Count)"

$coverRx = 'karaoke|tribute|8 bit|made famous|originally performed|as made popular|instrumental version'
$found = 0; $rep = @()
foreach ($slug in $targets) {
  $name = $nameBySlug[$slug]; if (-not $name) { continue }
  $nn = Norm $name
  $aliasRx = $aliases[$slug]
  $best = $null; $bestScore = 0
  foreach ($t in $idx) {
    if ($t.nt -match $coverRx) { continue }
    $score = 0
    if ($t.nt -match ('\b' + [regex]::Escape($nn) + '\b')) { $score = 10 }
    elseif ($aliasRx -and $t.nt -match ('\b(' + $aliasRx + ')\b')) { $score = 8 }
    if ($score -eq 0) { continue }
    if ($t.na -match 'def rebel|cfo|jim johnston|^wwe|all elite|dale oliver|mikey rukus') { $score += 3 }
    if ($t.nt -match 'theme|entrance|^wwe') { $score += 1 }
    if ($score -gt $bestScore) { $bestScore = $score; $best = $t }
  }
  if ($best -and $bestScore -ge 9) {
    $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq $slug) { "$slug|$($best.title)|$($best.artist)|$($best.url)" } else { $_ } }
    $found++
    $rep += "TROUVE  $slug -> $($best.title) [$($best.artist)] / $($best.album)"
    Write-Host "TROUVE  $slug -> $($best.title) [$($best.artist)]"
  } else { $rep += "RIEN    $slug" }
}
$lines | Set-Content -Path $psvF -Encoding UTF8
$rep | Set-Content -Path (Join-Path $root 'tools\match-albums-report.txt') -Encoding UTF8
Write-Host '===='
Write-Host ("NOUVEAUX THEMES : {0} / {1}" -f $found, $targets.Count)
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
