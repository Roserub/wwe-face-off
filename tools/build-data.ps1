# Genere roster.js (CSV embarque pour file://) et reecrit roster.csv avec la colonne img,
# a partir des fichiers reellement presents dans images\.
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$csvF   = Join-Path $root 'roster.csv'
$imgDir = Join-Path $root 'images'

$rows = Get-Content -Raw -Encoding UTF8 $csvF | ConvertFrom-Csv

function Get-Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
  }
  ($sb.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')
}

Add-Type -AssemblyName System.Drawing

# --- cadrage : object-position calcule d'apres le format de l'image, + overrides manuels ---
$ovr = @{}
$ovrF = Join-Path $PSScriptRoot 'focus-overrides.psv'
if (Test-Path $ovrF) {
  foreach ($l in (Get-Content -Encoding UTF8 $ovrF)) {
    if ($l -match '^\s*#' -or $l -notmatch '\|') { continue }
    $p = $l.Split('|'); if ($p[0].Trim() -eq 'slug') { continue }
    if ($p.Length -ge 2 -and $p[1].Trim()) { $ovr[$p[0].Trim()] = $p[1].Trim() }
  }
}
function Get-Focus([string]$path, [string]$slug) {
  if ($ovr.ContainsKey($slug)) { return $ovr[$slug] }
  $w = 0; $h = 0
  try { $im = [System.Drawing.Image]::FromFile($path); $w = $im.Width; $h = $im.Height; $im.Dispose() } catch { }
  if ($w -le 0 -or $h -le 0) { return 'center 12%' }        # webp : GDI+ ne lit pas, valeur sure
  $ratio = $w / $h
  if ($ratio -ge 1.15) { return 'center 50%' }               # paysage (renders WWE 16:9) : tranche centrale
  if ($ratio -le 0.62) { return 'center 8%' }                # tres vertical : la tete est tout en haut
  return 'center 14%'                                        # portrait classique
}

$missing = @()
$dupes = @()
$lines = @('name,gender,nickname,era,wiki,img,focus')
foreach ($r in $rows) {
  $slug = Get-Slug $r.name
  # plusieurs extensions pour un meme slug : on prend le fichier le plus recent (remplacement manuel)
  $all = @(Get-ChildItem $imgDir -Filter "$slug.*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  $f = if ($all.Count) { $all[0] } else { $null }
  if ($all.Count -gt 1) { $dupes += ("{0} -> garde {1}, ignore {2}" -f $slug, $f.Name, (($all | Select-Object -Skip 1 | ForEach-Object { $_.Name }) -join ', ')) }
  $img = ''; $focus = 'center 12%'
  if ($f) { $img = $f.Name; $focus = Get-Focus $f.FullName $slug } else { $missing += "$($r.name) ($($r.wiki))" }
  $lines += ('{0},{1},{2},{3},{4},{5},{6}' -f $r.name, $r.gender, $r.nickname, $r.era, $r.wiki, $img, $focus)
}

$csvText = ($lines -join "`n") + "`n"
[IO.File]::WriteAllText($csvF, $csvText, (New-Object Text.UTF8Encoding($false)))

$js = $csvText -replace '\\','\\\\' -replace '`','\`' -replace '\$\{','\${'
$jsOut = "// Genere par tools\build-data.ps1 - ne pas editer a la main (editer roster.csv puis relancer)`nwindow.ROSTER_CSV = ``$js``;`n"
[IO.File]::WriteAllText((Join-Path $root 'roster.js'), $jsOut, (New-Object Text.UTF8Encoding($false)))

Write-Host ("roster.js genere : {0} entrees, {1} avec image, {2} sans image" -f $rows.Count, ($rows.Count - $missing.Count), $missing.Count)
if ($missing.Count) { Write-Host "SANS IMAGE:"; $missing | ForEach-Object { Write-Host "  - $_" } }
if ($dupes.Count) { Write-Host "DOUBLONS (fichiers a nettoyer a la main) :"; $dupes | ForEach-Object { Write-Host "  ! $_" } }
