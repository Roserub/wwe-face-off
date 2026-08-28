# Resout un extrait 30s du theme d'entree de chaque superstar via l'API iTunes Search
# (previews officiels Apple, pas de cle requise). Genere wwe\themes.js + tools\themes-found.psv
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root = Split-Path -Parent $PSScriptRoot
$rows = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'roster.csv') | ConvertFrom-Csv
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-themes/1.0'

function Get-Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
  }
  ($sb.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')
}

# cache : reutilise les resultats OK du run precedent (themes-found.psv)
$prevRaw = @{}; $prevObj = @{}
$prevF = Join-Path $PSScriptRoot 'themes-found.psv'
if (Test-Path $prevF) {
  foreach ($l in Get-Content -Encoding UTF8 $prevF) {
    $p = $l.Split('|')
    if ($p.Length -ge 4 -and $p[1] -ne 'MISS' -and $p[3]) {
      $prevRaw[$p[0]] = $l
      $prevObj[$p[0]] = @{ u = $p[3]; t = ($p[1] + ' — ' + $p[2]) }
    }
  }
}

$found = @{}
$lines = @()
$i = 0
foreach ($r in $rows) {
  $i++
  $slug = Get-Slug $r.name
  if ($prevObj.ContainsKey($slug)) {
    $found[$slug] = $prevObj[$slug]
    $lines += $prevRaw[$slug]
    continue
  }
  $nl = $r.name.ToLowerInvariant()
  $term = [uri]::EscapeDataString('WWE ' + $r.name)
  $api = "https://itunes.apple.com/search?term=$term&media=music&entity=song&limit=12&country=US"
  $best = $null; $bestScore = -1
  try {
    $resp = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
    foreach ($t in $resp.results) {
      if (-not $t.previewUrl) { continue }
      $track = ('' + $t.trackName).ToLowerInvariant()
      $artist = ('' + $t.artistName).ToLowerInvariant()
      $coll = ('' + $t.collectionName).ToLowerInvariant()
      $hay = "$track $artist $coll"
      if (-not $hay.Contains($nl)) { continue }
      $wweSignal = $hay.Contains('wwe') -or $artist.Contains($nl) -or $artist.Contains('jim johnston') -or $artist.Contains('cfo$') -or $artist.Contains('def rebel')
      if (-not $wweSignal) { continue }
      $score = 0
      if ($track.Contains($nl)) { $score += 3 }
      if ($artist.Contains($nl)) { $score += 2 }
      if ($coll.Contains('wwe')) { $score += 2 }
      if ($track.Contains('wwe')) { $score += 1 }
      if ($track -match 'theme|entrance') { $score += 1 }
      if ($track -match 'karaoke|tribute|cover|ringtone|parody') { $score -= 4 }
      if ($score -gt $bestScore) { $bestScore = $score; $best = $t }
    }
  } catch {
    Write-Host "[$i/$($rows.Count)] API FAIL $($r.name): $($_.Exception.Message)"
  }
  if ($best -and $bestScore -ge 1) {
    $found[$slug] = @{ u = $best.previewUrl; t = ($best.trackName + ' — ' + $best.artistName) }
    $lines += "$slug|$($best.trackName)|$($best.artistName)|$($best.previewUrl)"
    Write-Host "[$i/$($rows.Count)] OK   $($r.name) -> $($best.trackName) [$($best.artistName)] (score $bestScore)"
  } else {
    $lines += "$slug|MISS||"
    Write-Host "[$i/$($rows.Count)] MISS $($r.name)"
  }
  Start-Sleep -Milliseconds 2600
}

$lines | Set-Content -Path (Join-Path $PSScriptRoot 'themes-found.psv') -Encoding UTF8
$json = $found | ConvertTo-Json -Compress -Depth 4
$js = "// Genere par tools\fetch-themes.ps1 - extraits 30s officiels iTunes (previewUrl)`nwindow.THEMES = $json;`n"
[IO.File]::WriteAllText((Join-Path $root 'themes.js'), $js, (New-Object Text.UTF8Encoding($false)))
Write-Host '----'
Write-Host ("THEMES: {0}/{1} trouves -> themes.js" -f $found.Count, $rows.Count)
