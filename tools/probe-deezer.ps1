# Diagnostic Deezer (API publique, extraits 30s, sans cle) : affiche les resultats bruts.
param([string]$Terms = '')
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WWEFaceOff-probe/1.0'
foreach ($term in ($Terms -split ';' | Where-Object { $_.Trim() })) {
  Write-Host ""
  Write-Host "=== $term ==="
  $api = 'https://api.deezer.com/search?q=' + [uri]::EscapeDataString($term.Trim()) + '&limit=12'
  try {
    $req = [Net.HttpWebRequest]::Create($api); $req.UserAgent = $ua; $req.Timeout = 30000
    $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $json = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    $res = ($json | ConvertFrom-Json).data
    if (-not $res -or $res.Count -eq 0) { Write-Host "  (aucun resultat)" }
    foreach ($t in $res) {
      $pv = if ($t.preview) { 'preview OK' } else { 'PAS DE PREVIEW' }
      Write-Host ("  {0,-50} | {1,-26} | {2,-26} | {3}" -f ('' + $t.title), ('' + $t.artist.name), ('' + $t.album.title), $pv)
    }
  } catch { Write-Host "  FAIL: $($_.Exception.Message)" }
  Start-Sleep -Milliseconds 900
}
