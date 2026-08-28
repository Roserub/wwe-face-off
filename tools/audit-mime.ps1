# Verifie le type MIME reel de chaque extrait : Apple sert parfois du audio/x-m4p
# (AAC protege) que les navigateurs refusent de lire, alors que l'URL repond 200.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$lines = Get-Content -Encoding UTF8 (Join-Path $root 'tools\themes-found.psv')
$types = @{}; $bad = @()
$i = 0
foreach ($l in $lines) {
  $p = $l.Split('|')
  if ($p.Length -lt 4 -or $p[1] -eq 'MISS' -or -not $p[3]) { continue }
  $i++
  $ct = '?'
  try {
    $req = [Net.HttpWebRequest]::Create($p[3]); $req.Method = 'HEAD'; $req.UserAgent = 'Mozilla/5.0'; $req.Timeout = 15000
    $r = $req.GetResponse(); $ct = '' + $r.ContentType; $r.Close()
  } catch { $ct = 'ERREUR' }
  if (-not $types.ContainsKey($ct)) { $types[$ct] = 0 }
  $types[$ct]++
  # types illisibles par les navigateurs : m4p (protege) ou erreur
  if ($ct -match 'm4p' -or $ct -eq 'ERREUR' -or $ct -eq '?') { $bad += "$($p[0])|$($p[1])|$($p[2])|$ct" }
  if ($i % 40 -eq 0) { Write-Host "  ...$i" }
}
Write-Host ''
Write-Host '--- TYPES RENCONTRES ---'
$types.Keys | Sort-Object | ForEach-Object { "{0,-24} {1}" -f $_, $types[$_] }
Write-Host ''
Write-Host ("ILLISIBLES : {0}" -f $bad.Count)
$bad | ForEach-Object { Write-Host "  $_" }
$bad | Set-Content -Path (Join-Path $root 'tools\mime-bad.psv') -Encoding UTF8
