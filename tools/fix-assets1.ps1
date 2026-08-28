# Remplacements cibles demandes (i = image via WWE.com/Fandom, s = song version populaire via iTunes)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$imgDir = Join-Path $root 'images'
$psvF = Join-Path $root 'tools\themes-found.psv'
$uaWeb = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

# ------------------ IMAGES ------------------
$imgJobs = @(
  @{slug='jillian-hall';     wwe=@('jillian-hall','jillian');        fandom=@('Jillian Hall')},
  @{slug='kristal-marshall'; wwe=@('kristal','kristal-marshall');    fandom=@('Kristal Marshall')},
  @{slug='michin';           wwe=@('michin','mia-yim');              fandom=@('Mia Yim')},
  @{slug='ashley-massaro';   wwe=@('ashley-massaro','ashley');       fandom=@('Ashley Massaro')},
  @{slug='melina';           wwe=@('melina');                        fandom=@('Melina Perez')},
  @{slug='gail-kim';         wwe=@('gail-kim');                      fandom=@('Gail Kim')},
  @{slug='chad-gable';       wwe=@('chad-gable');                    fandom=@('Chad Gable')}
)
function Save-Img([string]$url, [string]$slug) {
  if (-not $url) { return $false }
  $ext = 'jpg'
  if ($url -match '\.(jpe?g|png|webp)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $tmp = Join-Path $env:TEMP "fx-$slug.$ext"
  try { Invoke-WebRequest -Uri $url -OutFile $tmp -Headers @{ 'User-Agent' = $uaWeb; 'Referer' = 'https://www.wwe.com/' } -TimeoutSec 60 -UseBasicParsing } catch { return $false }
  if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -lt 40KB) { return $false }
  $head = [IO.File]::ReadAllBytes($tmp)[0..11]
  $isWebp = ($head[0] -eq 0x52 -and $head[8] -eq 0x57)   # RIFF....WEBP
  if ($isWebp -and $ext -ne 'webp') { $new = Join-Path $env:TEMP "fx-$slug.webp"; Move-Item -Force $tmp $new; $tmp = $new; $ext = 'webp' }
  Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Remove-Item -Force
  Move-Item -Force $tmp (Join-Path $imgDir "$slug.$ext")
  return $true
}
foreach ($j in $imgJobs) {
  $done = $false
  foreach ($ws in $j.wwe) {
    if ($done) { break }
    try {
      $resp = Invoke-WebRequest -Uri "https://www.wwe.com/superstars/$ws" -Headers @{ 'User-Agent' = $uaWeb } -TimeoutSec 40 -UseBasicParsing
      if ($resp.Content -match '<meta property="og:image" content="([^"]+)"') {
        $og = $Matches[1]
        $orig = $og -replace '/f/styles/[^/]+/public/', '/f/'
        if ($orig -ne $og -and (Save-Img $orig $j.slug)) { $done = $true; Write-Host "IMG OK  $($j.slug) <- WWE.com original ($ws)" }
        elseif (Save-Img $og $j.slug) { $done = $true; Write-Host "IMG OK  $($j.slug) <- WWE.com og ($ws)" }
      }
    } catch { }
    Start-Sleep -Milliseconds 1500
  }
  if (-not $done) {
    foreach ($t in $j.fandom) {
      if ($done) { break }
      $api = 'https://prowrestling.fandom.com/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=original&titles=' + [uri]::EscapeDataString($t)
      try {
        $r = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $uaWeb } -TimeoutSec 30
        $p = $r.query.pages | Select-Object -First 1
        if ($p.original -and $p.original.source -and (Save-Img $p.original.source $j.slug)) { $done = $true; Write-Host "IMG OK  $($j.slug) <- Fandom [$t]" }
      } catch { }
      Start-Sleep -Seconds 3
    }
  }
  if (-not $done) { Write-Host "IMG MISS $($j.slug)" }
}

# ------------------ SONGS (version populaire, covers exclues) ------------------
$coverRx = 'it lives|ansoland|geek music|tribute|karaoke|cover band|8-bit|8 bit|theme song factory|wrestling theme'
$songJobs = @(
  @{slug='shawn-michaels';    terms=@('Sexy Boy Shawn Michaels WWE','Sexy Boy Shawn Michaels');       need='sexy boy'},
  @{slug='shayna-baszler';    terms=@('Queen of Spades CFO$','Shayna Baszler Queen of Spades');       need='queen of spades'},
  @{slug='nikki-bella';       terms=@("You Can Look But You Can't Touch WWE",'You Can Look Kim Sozzi'); need='you can look'},
  @{slug='shinsuke-nakamura'; terms=@('The Rising Sun CFO$','Shinsuke Nakamura Rising Sun WWE');      need='rising sun'},
  @{slug='braun-strowman';    terms=@('I Am Stronger WWE','I Am Stronger CFO$');                      need='i am stronger'},
  @{slug='jey-uso';           terms=@('Main Event Ish def rebel','Main Event Ish WWE');               need='main event ish'},
  @{slug='chad-gable';        terms=@('Shoot It WWE American Alpha','Alpha Academy WWE theme','Set It Off Chad Gable'); need='shoot it|alpha academy|set it off'}
)
function Search-Itunes([string]$term) {
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term) + '&media=music&entity=song&limit=12&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $uaWeb; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    return ($json | ConvertFrom-Json).results
  } catch { return @() }
}
$lines = Get-Content -Encoding UTF8 $psvF
foreach ($j in $songJobs) {
  $best = $null; $bestScore = -1
  foreach ($term in $j.terms) {
    foreach ($t in (Search-Itunes $term)) {
      if (-not $t.previewUrl) { continue }
      $track = ('' + $t.trackName).ToLowerInvariant()
      $artist = ('' + $t.artistName).ToLowerInvariant()
      if ($track -notmatch $j.need) { continue }
      if ("$track $artist" -match $coverRx) { continue }
      $s = 1
      if ($artist -match 'wwe|jim johnston|cfo\$|def rebel|jim johnston') { $s += 4 }
      if ($artist -match ($j.slug -replace '-',' ')) { $s += 3 }
      if ($track -match 'wwe') { $s += 2 }
      if ($s -gt $bestScore) { $bestScore = $s; $best = $t }
    }
    Start-Sleep -Milliseconds 2600
    if ($best -and $bestScore -ge 5) { break }
  }
  if ($best) {
    $newLine = "$($j.slug)|$($best.trackName)|$($best.artistName)|$($best.previewUrl)"
    $lines = $lines | ForEach-Object { if ($_.Split('|')[0] -eq $j.slug) { $newLine } else { $_ } }
    Write-Host "SONG OK  $($j.slug) -> $($best.trackName) [$($best.artistName)]"
  } else { Write-Host "SONG MISS $($j.slug) (aucune version non-cover trouvee)" }
}
$lines | Set-Content -Path $psvF -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-data.ps1')
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
