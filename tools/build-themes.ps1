# Regenere themes.js depuis tools\themes-found.psv (avec reparation mojibake).
$ErrorActionPreference = 'Stop'
$root = 'c:\Users\Corentin\Documents\lol\wwe'
$psvF = Join-Path $root 'tools\themes-found.psv'
$fixPairs = @(
  @(0x00C3,0x00A9,0x00E9), @(0x00C3,0x00A8,0x00E8), @(0x00C3,0x00B6,0x00F6), @(0x00C3,0x00A1,0x00E1),
  @(0x00C3,0x00AD,0x00ED), @(0x00C3,0x00B3,0x00F3), @(0x00C3,0x00BA,0x00FA), @(0x00C3,0x00B1,0x00F1),
  @(0x00C3,0x00BC,0x00FC), @(0x00C3,0x00A4,0x00E4), @(0x00C3,0x00A7,0x00E7)
)
function Fix-Moji([string]$s) {
  $s = $s.Replace(([string][char]0x00E2 + [char]0x20AC + [char]0x201D), [string][char]0x2014)
  $s = $s.Replace(([string][char]0x00C2 + [char]0x00B7), [string][char]0x00B7)
  foreach ($p in $fixPairs) { $s = $s.Replace(([string][char]$p[0] + [char]$p[1]), [string][char]$p[2]) }
  return $s
}
$found = [ordered]@{}
foreach ($l in (Get-Content -Encoding UTF8 $psvF)) {
  $p = $l.Split('|')
  if ($p.Length -ge 4 -and $p[1] -ne 'MISS' -and $p[3]) {
    $found[$p[0]] = @{ u = $p[3]; t = (Fix-Moji ($p[1] + ' ' + [char]0x2014 + ' ' + $p[2])) }
  }
}
$json = $found | ConvertTo-Json -Compress -Depth 4
$js = "// Genere par tools\build-themes.ps1 - extraits 30s officiels iTunes (previewUrl)`nwindow.THEMES = $json;`n"
[IO.File]::WriteAllText((Join-Path $root 'themes.js'), $js, (New-Object Text.UTF8Encoding($false)))
Write-Host ("themes.js regenere : {0} entrees" -f $found.Count)
