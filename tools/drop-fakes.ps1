# Retire les faux positifs : fan-tracks / dubs qui ne sont pas le vrai theme du catcheur.
# (silence = seul le theme de l'adversaire jouera, conformement a la regle demandee)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$psvF = Join-Path $root 'tools\themes-found.psv'
$drop = @('ric-flair','goldberg','cameron')   # Brian Knapp / Optimus Chad dub / Luca Young : pas les vrais themes
$lines = Get-Content -Encoding UTF8 $psvF | ForEach-Object {
  $slug = $_.Split('|')[0]
  if ($drop -contains $slug) { "$slug|MISS||" } else { $_ }
}
$lines | Set-Content -Path $psvF -Encoding UTF8
Write-Host ("retires : {0}" -f ($drop -join ', '))
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-themes.ps1')
