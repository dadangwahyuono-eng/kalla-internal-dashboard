# fix_kalla_filenames.ps1
# Jalankan di folder yang berisi semua file web (kalla_hybrid_final)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Running filename sanitizer and HTML link fixer..." -ForegroundColor Cyan

# 1) Build list of files to rename (replace spaces with underscores)
$files = Get-ChildItem -File | Where-Object { $_.Name -match '\s' -and ($_.Extension -match '\.html|\.htm|\.png|\.jpg|\.jpeg|\.js|\.css') }
if ($files.Count -gt 0) {
  foreach ($f in $files) {
    $newName = $f.Name -replace '\s+','_'
    Write-Host "Renaming '$($f.Name)' -> '$newName'"
    Rename-Item -LiteralPath $f.FullName -NewName $newName -Force
  }
} else {
  Write-Host "No filenames with spaces found."
}

# 2) Build mapping old->new for any remaining problematic chars (just in-case)
# Also normalize to ASCII basic: remove weird chars that can break URLs
$allFiles = Get-ChildItem -File
$map = @{}
foreach ($f in $allFiles) {
  $safe = $f.Name -replace '[\(\)\[\]\{\}\']',''    # remove parentheses/brackets/apostrophes
  $safe = $safe -replace '\s+','_'
  if ($safe -ne $f.Name) {
    $map[$f.Name] = $safe
    Rename-Item -LiteralPath $f.FullName -NewName $safe -Force
    Write-Host "Normalized '$($f.Name)' -> '$safe'"
  }
}

# 3) Update references inside all HTML files using the map (and also fix common master filename)
$htmlFiles = Get-ChildItem -Filter *.html -File
foreach ($hf in $htmlFiles) {
  $text = Get-Content -Raw -Path $hf.FullName -Encoding UTF8
  $orig = $text

  # replace occurrences for each mapping key
  foreach ($k in $map.Keys) {
    $v = $map[$k]
    # replace exact href/src occurrences (with or without ./)
    $text = $text -replace [regex]::Escape("href=""$k"""), "href=`"$v`""
    $text = $text -replace [regex]::Escape("src=""$k"""), "src=`"$v`""
    $text = $text -replace [regex]::Escape("href='$k'"), "href='$v'"
    $text = $text -replace [regex]::Escape("src='$k'"), "src='$v'"
    # also bare references
    $text = $text -replace [regex]::Escape($k), $v
  }

  # Ensure master filename referenced is the one we will enforce:
  $desiredMaster = "KALLA-DASHBOARD-MASTER-with-histori-supabase-ready.html"
  # if there's a variant like "...-fixed.html", normalize it:
  $text = $text -replace "KALLA-DASHBOARD-MASTER-with-histori[-_a-zA-Z0-9]*\.html", $desiredMaster

  if ($text -ne $orig) {
    $text | Out-File -FilePath $hf.FullName -Encoding UTF8
    Write-Host "Updated links in $($hf.Name)"
  }
}

# 4) Ensure master file exists. If a similarly named master exists, rename it to the desired name.
$desired = "KALLA-DASHBOARD-MASTER-with-histori-supabase-ready.html"
if (-not (Test-Path $desired)) {
  # try to find any file that starts with 'KALLA-DASHBOARD-MASTER'
  $candidate = Get-ChildItem -File | Where-Object { $_.Name -match '^KALLA-DASHBOARD-MASTER' } | Select-Object -First 1
  if ($candidate) {
    Write-Host "Renaming candidate master '$($candidate.Name)' -> '$desired'"
    Rename-Item -LiteralPath $candidate.FullName -NewName $desired -Force
  } else {
    Write-Host "WARNING: No master file found starting with 'KALLA-DASHBOARD-MASTER'." -ForegroundColor Yellow
  }
} else {
  Write-Host "Master file already present: $desired"
}

# 5) Ensure index.html redirect uses ./ prefix (exact)
$indexPath = Join-Path (Get-Location) "index.html"
if (Test-Path $indexPath) {
  $idx = Get-Content -Raw -Path $indexPath -Encoding UTF8
  $idx = $idx -replace '(?i)<meta\s+http-equiv=["'']refresh["'']\s+content=["''][^"']*["'']\s*/?>', '<meta http-equiv="refresh" content="0;url=./KALLA-DASHBOARD-MASTER-with-histori-supabase-ready.html"/>'
  $idx | Out-File -FilePath $indexPath -Encoding UTF8
  Write-Host "Ensured index.html redirect points to ./KALLA-DASHBOARD-MASTER-with-histori-supabase-ready.html"
} else {
  Write-Host "index.html not found, creating one..."
  $redir = @'
<!doctype html>
<html><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=./KALLA-DASHBOARD-MASTER-with-histori-supabase-ready.html"/></head>
<body>If you are not redirected <a href="./KALLA-DASHBOARD-MASTER-with-histori-supabase-ready.html">click here</a>.</body></html>
'@
  $redir | Out-File -FilePath $indexPath -Encoding UTF8
  Write-Host "Created index.html redirect."
}

# 6) Final listing
Write-Host "Final directory listing:" -ForegroundColor Green
Get-ChildItem -File | Select-Object Name,Length | Format-Table -AutoSize
Write-Host "Done. Now restart local server and test http://localhost:8000/" -ForegroundColor Cyan
