# Moisson EXHAUSTIVE par album : la recherche plafonne (200 resultats), mais on peut
# enumerer integralement le contenu d'un album. On liste les albums WWE/NXT/def rebel/CFO$/
# Jim Johnston sur iTunes ET Deezer, puis on aspire leurs pistes.
# Sortie : tools\album-index.psv (source|titre|artiste|album|preview)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-albums/1.0'

function Get-Json([string]$url, [int]$tries = 3) {
  for ($t = 1; $t -le $tries; $t++) {
    try {
      $req = [Net.HttpWebRequest]::Create($url); $req.UserAgent = $ua; $req.Timeout = 40000
      $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
      $j = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
      return ($j | ConvertFrom-Json)
    } catch { Start-Sleep -Seconds (2 * $t) }
  }
  return $null
}
$out = @{}
function Add-Track([string]$src, $title, $artist, $album, $prev) {
  if (-not $prev -or -not $title) { return }
  if ($out.ContainsKey($prev)) { return }
  $out[$prev] = ($src + '|' + (('' + $title) -replace '\|','/') + '|' + (('' + $artist) -replace '\|','/') + '|' + (('' + $album) -replace '\|','/') + '|' + $prev)
}

# ---------- iTunes : albums -> tracklist complete ----------
$albumIds = @{}
$terms = @('WWE','WWE NXT','WWE the music','def rebel','CFO$','Jim Johnston','WWE anthology',
           'WWE originals','WWE forceable entry','NXT takeover','WWE themes')
foreach ($term in $terms) {
  foreach ($country in @('US','GB')) {
    $r = Get-Json ('https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + "&media=music&entity=album&limit=200&country=$country")
    if ($r -and $r.results) {
      foreach ($al in $r.results) {
        $nm = ('' + $al.collectionName + ' ' + $al.artistName).ToLowerInvariant()
        if ($nm -match 'wwe|nxt|def rebel|cfo|jim johnston|wrestling') { $albumIds[$al.collectionId] = $al.collectionName }
      }
    }
    Start-Sleep -Milliseconds 2600
  }
  Write-Host ("iTunes albums [{0}] : {1} albums retenus" -f $term, $albumIds.Count)
}
$n = 0
foreach ($id in $albumIds.Keys) {
  $n++
  $r = Get-Json ("https://itunes.apple.com/lookup?id=$id&entity=song&limit=200&country=US")
  if ($r -and $r.results) {
    foreach ($t in $r.results) {
      if ($t.wrapperType -eq 'track' -and $t.previewUrl) { Add-Track 'itunes' $t.trackName $t.artistName $t.collectionName $t.previewUrl }
    }
  }
  if ($n % 20 -eq 0) { Write-Host ("  ...{0}/{1} albums, {2} pistes" -f $n, $albumIds.Count, $out.Count) }
  Start-Sleep -Milliseconds 2600
}
Write-Host ("iTunes : {0} pistes apres {1} albums" -f $out.Count, $albumIds.Count)

# ---------- Deezer : artiste -> albums -> pistes ----------
foreach ($art in @('def rebel','CFO$','Jim Johnston','WWE','Dale Oliver','Mikey Rukus')) {
  $ar = Get-Json ('https://api.deezer.com/search/artist?q=' + [uri]::EscapeDataString($art) + '&limit=5')
  if (-not $ar -or -not $ar.data) { continue }
  foreach ($a in $ar.data) {
    $an = ('' + $a.name).ToLowerInvariant()
    if ($an -notmatch 'def rebel|cfo|jim johnston|^wwe$|dale oliver|mikey rukus') { continue }
    $before = $out.Count
    $al = Get-Json ("https://api.deezer.com/artist/$($a.id)/albums?limit=300")
    if ($al -and $al.data) {
      foreach ($alb in $al.data) {
        $tr = Get-Json ("https://api.deezer.com/album/$($alb.id)/tracks?limit=200")
        if ($tr -and $tr.data) {
          foreach ($t in $tr.data) { Add-Track 'deezer' $t.title $a.name $alb.title $t.preview }
        }
        Start-Sleep -Milliseconds 350
      }
    }
    Write-Host ("Deezer [{0}] : +{1} (total {2})" -f $a.name, ($out.Count - $before), $out.Count)
  }
  Start-Sleep -Milliseconds 700
}

$out.Values | Set-Content -Path (Join-Path $root 'tools\album-index.psv') -Encoding UTF8
Write-Host '===='
Write-Host ("INDEX ALBUMS : {0} pistes -> tools\album-index.psv" -f $out.Count)
