# v2 : requetes API par lots de 45 titres (5 appels au lieu de 190), retry sur 429.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root   = Split-Path -Parent $PSScriptRoot
$csv    = Join-Path $root 'roster.csv'
$imgDir = Join-Path $root 'images'
$logF   = Join-Path $PSScriptRoot 'imglog.csv'
$missF  = Join-Path $PSScriptRoot 'misses.txt'
if (-not (Test-Path $imgDir)) { New-Item -ItemType Directory -Force $imgDir | Out-Null }

$ua = 'WWEFaceOffBot/2.0 (https://en.wikipedia.org/wiki/User_talk:example; local one-shot fan project) PowerShell/5.1'
$rows = Get-Content -Raw -Encoding UTF8 $csv | ConvertFrom-Csv

function Get-Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
  }
  ($sb.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')
}

Write-Host "Pause initiale 60s (rate-limit precedent)..."
Start-Sleep -Seconds 60

# ---- Phase 1 : recuperer les URLs de vignettes par lots ----
$thumbByTitle = @{}   # titre final -> url
$norm = @{}; $redir = @{}
$batchSize = 45
for ($b = 0; $b -lt $rows.Count; $b += $batchSize) {
  $batch = $rows[$b..([Math]::Min($b+$batchSize-1, $rows.Count-1))]
  $titles = ($batch | ForEach-Object { [uri]::EscapeDataString($_.wiki) }) -join '%7C'
  $api = "https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&redirects=1&prop=pageimages&piprop=thumbnail&pithumbsize=1400&pilimit=max&titles=$titles"
  $ok = $false; $try = 0
  while (-not $ok -and $try -lt 4) {
    $try++
    try {
      $resp = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $ua } -TimeoutSec 40
      if ($resp.query.normalized) { foreach ($n in $resp.query.normalized) { $norm[$n.from] = $n.to } }
      if ($resp.query.redirects)  { foreach ($r in $resp.query.redirects)  { $redir[$r.from] = $r.to } }
      foreach ($p in $resp.query.pages) {
        if ($p.thumbnail -and $p.thumbnail.source) { $thumbByTitle[$p.title] = $p.thumbnail.source }
      }
      $ok = $true
      Write-Host ("Batch {0} OK ({1} pages avec image jusqu'ici)" -f ([int]($b/$batchSize)+1), $thumbByTitle.Count)
    } catch {
      Write-Host ("Batch {0} essai {1} FAIL: {2} -> pause 45s" -f ([int]($b/$batchSize)+1), $try, $_.Exception.Message)
      Start-Sleep -Seconds 45
    }
  }
  Start-Sleep -Seconds 5
}

# ---- Phase 2 : telecharger ----
$log = @(); $miss = @()
$i = 0
foreach ($r in $rows) {
  $i++
  $slug = Get-Slug $r.name
  $existing = Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($existing) { $log += [pscustomobject]@{ name=$r.name; slug=$slug; file=$existing.Name; status='cached' }; continue }

  $t = $r.wiki
  if ($norm.ContainsKey($t))  { $t = $norm[$t] }
  if ($redir.ContainsKey($t)) { $t = $redir[$t] }
  $src = $null
  if ($thumbByTitle.ContainsKey($t)) { $src = $thumbByTitle[$t] }

  if (-not $src -or $src -match '\.svg') {
    $miss += "$($r.name)|$($r.wiki)|no-image"
    $log += [pscustomobject]@{ name=$r.name; slug=$slug; file=''; status='miss' }
    Write-Host "[$i/$($rows.Count)] MISS   $($r.name) ($($r.wiki) -> $t)"
    continue
  }
  $ext = 'jpg'
  if ($src -match '\.(jpe?g|png|gif|webp)(?:$|\?)') { $ext = $Matches[1].ToLowerInvariant() -replace 'jpeg','jpg' }
  $out = Join-Path $imgDir "$slug.$ext"
  $done = $false; $try = 0
  while (-not $done -and $try -lt 3) {
    $try++
    try {
      Invoke-WebRequest -Uri $src -OutFile $out -Headers @{ 'User-Agent' = $ua } -TimeoutSec 60 -UseBasicParsing
      $kb = [math]::Round((Get-Item $out).Length / 1KB)
      $log += [pscustomobject]@{ name=$r.name; slug=$slug; file="$slug.$ext"; status="ok ($kb KB)" }
      Write-Host "[$i/$($rows.Count)] OK     $($r.name) -> $slug.$ext ($kb KB)"
      $done = $true
    } catch {
      if ($try -ge 3) {
        $miss += "$($r.name)|$($r.wiki)|download-fail"
        $log += [pscustomobject]@{ name=$r.name; slug=$slug; file=''; status='dl-fail' }
        Write-Host "[$i/$($rows.Count)] DLFAIL $($r.name): $($_.Exception.Message)"
      } else {
        Write-Host "[$i/$($rows.Count)] retry  $($r.name) ($($_.Exception.Message)) pause 20s"
        Start-Sleep -Seconds 20
      }
    }
  }
  Start-Sleep -Milliseconds 350
}

$log | Export-Csv -Path $logF -NoTypeInformation -Encoding UTF8
$miss | Set-Content -Path $missF -Encoding UTF8
$okN = ($log | Where-Object { $_.status -notmatch 'miss|dl-fail' }).Count
Write-Host "----"
Write-Host ("TOTAL: {0}  OK/cached: {1}  MISS: {2}" -f $rows.Count, $okN, $miss.Count)
