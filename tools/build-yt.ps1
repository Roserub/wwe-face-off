# Genere wwe\themes-yt.js depuis tools\themes-youtube.psv
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $PSScriptRoot 'themes-youtube.psv'
$map = [ordered]@{}
foreach ($l in (Get-Content -Encoding UTF8 $src)) {
  if ($l -match '^\s*#' -or $l -notmatch '\|') { continue }
  $p = $l.Split('|')
  if ($p[0].Trim() -eq 'slug') { continue }
  if ($p.Length -ge 3 -and $p[1].Trim()) {
    $map[$p[0].Trim()] = @{ yt = $p[1].Trim(); t = ($p[2].Trim() + ' - YouTube') }
  }
}
$json = if ($map.Count) { $map | ConvertTo-Json -Compress -Depth 4 } else { '{}' }
$js = "// Genere par tools\build-yt.ps1 - lecteur officiel YouTube (aucun telechargement)`nwindow.THEMES_YT = $json;`n"
[IO.File]::WriteAllText((Join-Path $root 'themes-yt.js'), $js, (New-Object Text.UTF8Encoding($false)))
Write-Host ("themes-yt.js : {0} entrees" -f $map.Count)
