# Moisson par COMPOSITEUR plutot que par catcheur : on enumere les catalogues def rebel / CFO$ /
# Jim Johnston / WWE sur iTunes ET Deezer, puis on indexe tous les titres trouves.
# Sortie : tools\composer-index.psv  (source|titre|artiste|preview)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-harvest/1.0'

function Get-Json([string]$url) {
  try {
    $req = [Net.HttpWebRequest]::Create($url); $req.UserAgent = $ua; $req.Timeout = 40000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $j = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($j | ConvertFrom-Json)
  } catch { Write-Host "    http fail: $($_.Exception.Message)"; return $null }
}

$out = @{}   # preview url -> ligne
function Add-Track([string]$src, [string]$title, [string]$artist, [string]$prev) {
  if (-not $prev -or -not $title) { return }
  if ($out.ContainsKey($prev)) { return }
  $t = ($title -replace '\|', '/'); $a = ($artist -replace '\|', '/')
  $out[$prev] = "$src|$t|$a|$prev"
}

# ---------- iTunes : recherche par terme artiste ----------
$itQueries = @(
  @{ q='def rebel';     attr='artistTerm' }, @{ q='CFO$';         attr='artistTerm' },
  @{ q='Jim Johnston';  attr='artistTerm' }, @{ q='WWE';          attr='artistTerm' },
  @{ q='WWE the music'; attr='' },           @{ q='WWE NXT theme'; attr='' },
  @{ q='Dale Oliver';   attr='artistTerm' }, @{ q='Mikey Rukus';  attr='artistTerm' },
  @{ q='All Elite Wrestling'; attr='artistTerm' }, @{ q='Downstait'; attr='artistTerm' }
)
foreach ($q in $itQueries) {
  $before = $out.Count
  foreach ($country in @('US','GB')) {
    $url = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($q.q) + "&media=music&entity=song&limit=200&country=$country"
    if ($q.attr) { $url += '&attribute=' + $q.attr }
    $r = Get-Json $url
    if ($r -and $r.results) { foreach ($t in $r.results) { Add-Track 'itunes' $t.trackName $t.artistName $t.previewUrl } }
    Start-Sleep -Milliseconds 2600
  }
  Write-Host ("iTunes [{0}] : +{1} (total {2})" -f $q.q, ($out.Count - $before), $out.Count)
}

# ---------- Deezer : recherche avancee artist:"..." avec pagination ----------
foreach ($art in @('def rebel','CFO$','Jim Johnston','WWE','Dale Oliver','Mikey Rukus')) {
  $before = $out.Count
  for ($idx = 0; $idx -lt 300; $idx += 100) {
    $url = 'https://api.deezer.com/search?q=' + [uri]::EscapeDataString('artist:"' + $art + '"') + "&limit=100&index=$idx"
    $r = Get-Json $url
    if (-not $r -or -not $r.data -or $r.data.Count -eq 0) { break }
    foreach ($t in $r.data) { Add-Track 'deezer' $t.title $t.artist.name $t.preview }
    Start-Sleep -Milliseconds 900
    if ($r.data.Count -lt 100) { break }
  }
  Write-Host ("Deezer [{0}] : +{1} (total {2})" -f $art, ($out.Count - $before), $out.Count)
}
# Deezer : albums WWE / NXT par mots-cles
foreach ($kw in @('WWE the music','WWE NXT','WWE anthology','TNA Impact wrestling music')) {
  $before = $out.Count
  for ($idx = 0; $idx -lt 200; $idx += 100) {
    $url = 'https://api.deezer.com/search?q=' + [uri]::EscapeDataString($kw) + "&limit=100&index=$idx"
    $r = Get-Json $url
    if (-not $r -or -not $r.data -or $r.data.Count -eq 0) { break }
    foreach ($t in $r.data) { Add-Track 'deezer' $t.title $t.artist.name $t.preview }
    Start-Sleep -Milliseconds 900
    if ($r.data.Count -lt 100) { break }
  }
  Write-Host ("Deezer [{0}] : +{1} (total {2})" -f $kw, ($out.Count - $before), $out.Count)
}

$out.Values | Set-Content -Path (Join-Path $root 'tools\composer-index.psv') -Encoding UTF8
Write-Host '===='
Write-Host ("INDEX : {0} morceaux avec extrait -> tools\composer-index.psv" -f $out.Count)
