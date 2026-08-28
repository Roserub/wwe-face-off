# Diagnostic : affiche BRUT ce qu'iTunes renvoie pour des termes donnes (aucun filtre).
# Usage : probe-itunes.ps1 -Terms "Live for the Moment;Matt Hardy WWE"
param([string]$Terms = '')
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-probe/1.0'
foreach ($term in ($Terms -split ';' | Where-Object { $_.Trim() })) {
  Write-Host ""
  Write-Host "=== $term ==="
  $api = 'https://itunes.apple.com/search?term=' + [uri]::EscapeDataString($term.Trim()) + '&media=music&entity=song&limit=20&country=US'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    $res = ($json | ConvertFrom-Json).results
    if (-not $res -or $res.Count -eq 0) { Write-Host "  (aucun resultat)" }
    foreach ($t in $res) {
      $pv = if ($t.previewUrl) { 'preview OK' } else { 'PAS DE PREVIEW' }
      Write-Host ("  {0,-52} | {1,-30} | {2}" -f ('' + $t.trackName), ('' + $t.artistName), $pv)
    }
  } catch { Write-Host "  FAIL: $($_.Exception.Message)" }
  Start-Sleep -Milliseconds 2600
}
