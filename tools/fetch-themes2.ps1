# Themes v2 : recherches ciblees (vrais titres de themes) pour les 86 manquants,
# puis fallback "ambiance" pour que PERSONNE ne reste sans musique. Regenere themes.js.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = Split-Path -Parent $PSScriptRoot
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/2.0'
$psvF = Join-Path $root 'tools\themes-found.psv'

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

# resultats existants
$found = @{}
foreach ($l in Get-Content -Encoding UTF8 $psvF) {
  $p = $l.Split('|')
  if ($p.Length -ge 4 -and $p[1] -ne 'MISS' -and $p[3]) { $found[$p[0]] = @{ u = $p[3]; t = ($p[1] + ' — ' + $p[2]) } }
}
$targets = @()
foreach ($r in $rows) { $slug = Get-Slug $r.name; if (-not $found.ContainsKey($slug)) { $targets += $slug } }
Write-Host ("CIBLES: {0}" -f $targets.Count)

# recherches ciblees (vrais titres de themes connus)
$manual = @{
  'mvp'             = @("I'm Comin' Silkk the Shocker","MVP WWE theme")
  'samoa-joe'       = @('Destroyer CFO$','Samoa Joe WWE theme')
  'neville'         = @('Break Orbit WWE','Neville WWE theme')
  'braun-strowman'  = @('I Am Stronger WWE','Braun Strowman theme')
  'matt-riddle'     = @('Hey Bro WWE','Matt Riddle theme')
  'keith-lee'       = @('Limitless WWE Keith','Keith Lee theme')
  'karrion-kross'   = @('Doomsday Karrion Kross','Karrion Kross theme')
  'tommaso-ciampa'  = @('No One Will Survive WWE','Ciampa theme')
  'montez-ford'     = @('Bring the Swag WWE','Street Profits theme')
  'angelo-dawkins'  = @('Bring the Swag WWE','Street Profits theme')
  'ilja-dragunov'   = @('Unbesiegbar WWE','Ilja Dragunov theme')
  'maria-kanellis'  = @('With Legs Like That Zebrahead')
  'eve-torres'      = @('She Looks Good WWE','Eve Torres theme')
  'ronda-rousey'    = @('Bad Reputation Joan Jett')
  'shayna-baszler'  = @('Queen of Spades WWE','Shayna Baszler theme')
  'kairi-sane'      = @('Absolute Victory WWE','Kairi Sane theme')
  'dakota-kai'      = @('Team Kick WWE','Dakota Kai theme')
  'toni-storm'      = @('Light It Up WWE','Toni Storm theme')
  'zelina-vega'     = @('Ilusion WWE','Zelina Vega theme')
  'nikki-cross'     = @('Loony WWE','Nikki Cross theme')
  'carmella'        = @('Fabulous WWE Carmella','Carmella theme')
  'sonya-deville'   = @('On the Hunt WWE','Sonya Deville theme')
  'luke-harper'     = @('Live in Fear Mark Crozer','Luke Harper theme')
  'heath-slater'    = @('One Man Band WWE','Heath Slater theme')
  'big-cass'        = @('SAWFT Is a Sin','Enzo Cass WWE theme')
  'enzo-amore'      = @('SAWFT Is a Sin','Enzo Amore theme')
  'luke-gallows'    = @('Omen in the Sky WWE','Gallows Anderson theme')
  'santos-escobar'  = @('Legado del Fantasma theme','Santos Escobar theme')
  'roderick-strong' = @('Undisputed Era WWE theme','Roderick Strong theme')
  'shotzi'          = @('Til the Wheels Fall Off WWE','Shotzi theme')
  'ruby-riott'      = @('Riott Squad WWE theme','Ruby Riott theme')
  'sarah-logan'     = @('Riott Squad WWE theme','Sarah Logan theme')
  'erik'            = @('Viking Raiders WWE theme','War Raiders theme')
  'ivar'            = @('Viking Raiders WWE theme','War Raiders theme')
  'tyler-breeze'    = @('MMMGorgeous','Tyler Breeze theme')
  'hideo-itami'     = @('Hideo Itami theme','KENTA WWE theme')
  'buddy-murphy'    = @('Opposite Ends of the World WWE','Buddy Murphy theme')
  'awesome-kong'    = @('Kharma WWE theme','Awesome Kong theme')
  'peyton-royce'    = @('IIconics WWE theme','Peyton Royce theme')
  'billie-kay'      = @('IIconics WWE theme','Billie Kay theme')
  'kalisto'         = @('Lucha Lucha WWE','Kalisto theme')
  'wes-lee'         = @('MSK WWE theme','Wes Lee theme')
  'dijak'           = @('Feast Your Eyes WWE','Dijak theme')
  'bo-dallas'       = @('Bo Dallas WWE theme')
  'jillian-hall'    = @('Jillian Hall theme','Sliced Bread WWE')
  'ashley-massaro'  = @('Light a Fire WWE','Ashley Massaro theme')
  'dana-brooke'     = @('Dana Brooke theme')
  'curt-hawkins'    = @('Curt Hawkins theme','Face the Facts WWE')
  'erick-rowan'     = @('Erick Rowan theme','Sheepherder WWE')
  'drew-gulak'      = @('Drew Gulak theme')
  'lince-dorado'    = @('Lucha House Party theme','Lince Dorado theme')
  'gran-metalik'    = @('Lucha House Party theme','Gran Metalik theme')
  'cedric-alexander'= @('Won''t Let Go WWE','Cedric Alexander theme')
  'mojo-rawley'     = @('Hyped Up WWE','Mojo Rawley theme')
  'aiden-english'   = @('Aiden English theme','Vaudevillains WWE theme')
  'adam-rose'       = @('Break Away WWE Adam Rose','Adam Rose theme')
  'eric-young'      = @('Eric Young theme')
  'kyle-o-reilly'   = @('Undisputed Era WWE theme','Kyle O''Reilly theme')
  'serena-deeb'     = @('Serena Deeb theme')
  'brooke-adams'    = @('Brooke Adams theme')
  'kristal-marshall'= @('Kristal Marshall theme')
  'gigi-dolin'      = @('Toxic Attraction WWE theme','Gigi Dolin theme')
  'cora-jade'       = @('Cora Jade WWE theme')
  'katana-chance'   = @('Katana Chance Kayden Carter theme')
  'kayden-carter'   = @('Katana Chance Kayden Carter theme')
  'alba-fyre'       = @('Alba Fyre WWE theme')
  'tegan-nox'       = @('Tegan Nox WWE theme')
  'xia-li'          = @('Xia Li WWE theme')
  'shad-gaspard'    = @('Cryme Tyme WWE theme')
  'david-hart-smith'= @('Hart Dynasty WWE theme','New Foundation WWE')
  'yoshi-tatsu'     = @('Yoshi Tatsu theme')
  'stevie-richards' = @('Stevie Richards theme')
  'sabu'            = @('Sabu ECW theme','Huka Blues')
  'the-sandman'     = @('Enter Sandman Motorhead','Sandman ECW theme')
  'kevin-thorn'     = @('Kevin Thorn theme')
  'funaki'          = @('Funaki WWE theme')
  'paul-london'     = @('Paul London Kendrick theme')
  'brian-kendrick'  = @('Man with a Plan WWE','Brian Kendrick theme')
  'jamie-noble'     = @('Jamie Noble theme')
  'chuck-palumbo'   = @('Chuck Palumbo theme')
  'mike-knox'       = @('Mike Knox theme')
  'kenny-dykstra'   = @('Kenny Dykstra theme')
  'lance-cade'      = @('Cade Murdoch WWE theme')
  'trevor-murdoch'  = @('Cade Murdoch WWE theme')
  'charlie-haas'    = @('World''s Greatest Tag Team theme','Charlie Haas theme')
  'rene-dupree'     = @('La Resistance WWE theme','Rene Dupree theme')
}

function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=10&country=US'
  try { return (Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30).results } catch { return @() }
}
function Score-Result($t, [string[]]$tokens) {
  $track = ('' + $t.trackName).ToLowerInvariant()
  $artist = ('' + $t.artistName).ToLowerInvariant()
  $coll = ('' + $t.collectionName).ToLowerInvariant()
  $hay = "$track $artist $coll"
  if ($track -match 'karaoke|8-bit|8 bit|lullaby|parody|ringtone|tribute to') { return -9 }
  $s = 0
  foreach ($tk in $tokens) { if ($hay.Contains($tk)) { $s += 3; break } }
  if ($hay.Contains('wwe')) { $s += 2 }
  if ($track -match 'theme|entrance') { $s += 1 }
  if ($artist -match 'def rebel|cfo\$|jim johnston|it lives|ansoland|geek music|breaking point') { $s += 1 }
  return $s
}

$i = 0
foreach ($slug in $targets) {
  $i++
  $name = $nameBySlug[$slug]
  $tokens = ($name.ToLowerInvariant() -split '[^a-z0-9]+') | Where-Object { $_.Length -gt 2 }
  $terms = @()
  if ($manual.ContainsKey($slug)) { $terms += $manual[$slug] }
  $terms += @("$name WWE theme", "$name entrance theme")
  $best = $null; $bestScore = 1   # accepte a partir de 2
  foreach ($term in $terms) {
    $isManual = $manual.ContainsKey($slug) -and ($manual[$slug] -contains $term)
    foreach ($t in (Search-Itunes $term)) {
      if (-not $t.previewUrl) { continue }
      $s = Score-Result $t $tokens
      if ($isManual -and $s -ge 0) { $s += 2 }   # terme cible = confiance
      if ($s -gt $bestScore) { $bestScore = $s; $best = $t }
    }
    Start-Sleep -Milliseconds 2600
    if ($best -and $bestScore -ge 5) { break }
  }
  if ($best) {
    $found[$slug] = @{ u = $best.previewUrl; t = ($best.trackName + ' — ' + $best.artistName) }
    Write-Host "[$i/$($targets.Count)] OK   $name -> $($best.trackName) [$($best.artistName)] (score $bestScore)"
  } else {
    Write-Host "[$i/$($targets.Count)] MISS $name"
  }
}

# fallback ambiance : personne sans musique
$pool = @()
foreach ($pt in @('wrestling entrance theme epic','WWE the music Jim Johnston')) {
  foreach ($t in (Search-Itunes $pt)) {
    if ($t.previewUrl -and ('' + $t.trackName) -notmatch 'karaoke|lullaby|8-bit') { $pool += $t }
  }
  Start-Sleep -Milliseconds 2600
}
$still = @(); foreach ($r in $rows) { $slug = Get-Slug $r.name; if (-not $found.ContainsKey($slug)) { $still += $slug } }
if ($pool.Count -gt 0) {
  $j = 0
  foreach ($slug in $still) {
    $t = $pool[$j % $pool.Count]; $j++
    $found[$slug] = @{ u = $t.previewUrl; t = ($t.trackName + ' · ambiance') }
    Write-Host "AMBIANCE $slug -> $($t.trackName)"
  }
}

# reecrit psv + themes.js
$lines = @()
foreach ($r in $rows) {
  $slug = Get-Slug $r.name
  if ($found.ContainsKey($slug)) {
    $parts = $found[$slug].t -split ' — ', 2
    $tn = $parts[0]; $ar = if ($parts.Length -gt 1) { $parts[1] } else { '' }
    $lines += "$slug|$tn|$ar|$($found[$slug].u)"
  } else { $lines += "$slug|MISS||" }
}
$lines | Set-Content -Path $psvF -Encoding UTF8
$json = $found | ConvertTo-Json -Compress -Depth 4
$js = "// Genere par tools\fetch-themes2.ps1 - extraits 30s officiels iTunes (previewUrl)`nwindow.THEMES = $json;`n"
[IO.File]::WriteAllText((Join-Path $root 'themes.js'), $js, (New-Object Text.UTF8Encoding($false)))
Write-Host '----'
Write-Host ("THEMES: {0}/{1} -> themes.js" -f $found.Count, $rows.Count)
