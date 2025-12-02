<#
  build.ps1
  Build (compile) the AutoIt script to an exe using Aut2Exe if available.
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "..\src\reader_launcher.au3" | Resolve-Path -ErrorAction Stop
$outDir = Join-Path $here "..\dist"
If (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$out = Join-Path $outDir "reader_launcher.exe"
$out_upx = Join-Path $outDir "reader_launcher-upx.exe"
$zipName = Join-Path $outDir "reader_launcher_package.zip"

$aut2exe = Get-Command Aut2Exe -ErrorAction SilentlyContinue
If (-not $aut2exe) {
    $possible = "C:\\Program Files (x86)\\AutoIt3\\Aut2Exe\\Aut2Exe.exe"
    If (Test-Path $possible) { $aut2exe = $possible }
}

If (-not $aut2exe) {
    Write-Warning "Aut2Exe (AutoIt compiler) not found. Can't build. Install AutoIt or use AutoIt3Wrapper in SciTE."
    Exit 2
}

Write-Host "Compiling $src -> $out"
try {
    if ($aut2exe -is [string]) {
        & $aut2exe /in $src /out $out
    }
    else {
        & $aut2exe.Path /in $src /out $out
    }
    # Some versions of Aut2Exe may return non-zero codes even when an EXE is produced.
    # Treat a successful compilation as the produced output file existing on disk.
    if (-not (Test-Path $out)) { Write-Error "Aut2Exe did not produce $out; compilation failed"; Exit 1 }
}
catch {
    Write-Error "Aut2Exe invocation failed: $($_.Exception.Message)"
    Exit 1
}

Write-Host "Creating UPX-compressed copy $out_upx (if upx available)"
Copy-Item -Path $out -Destination $out_upx -Force
$upx = Get-Command upx -ErrorAction SilentlyContinue
if (-not $upx) {
    $possibleUpx = "C:\Program Files\upx\upx.exe"
    if (Test-Path $possibleUpx) { $upx = $possibleUpx }
}
if ($upx) {
    try {
        if ($upx -is [string]) {
            & $upx $out_upx -9
        }
        else {
            & $upx.Path $out_upx -9
        }
        if ($LASTEXITCODE -ne 0) { Write-Warning "UPX compression returned non-zero exit code" }
    }
    catch {
        Write-Warning "UPX invocation failed: $($_.Exception.Message)"
    }
}
else {
    Write-Host "UPX not found on PATH; UPX-compressed binary will be identical to the non-UPX copy." -ForegroundColor Yellow
}

Write-Host "Creating distribution package (zip) containing reader_launcher.exe and example config"
if (-not (Test-Path (Join-Path $here "..\launcher.example.ini"))) {
    Write-Warning "launcher.example.ini not found; zip package will not include example config"
}
else {
    $tmpFiles = @()
    $tmpFiles += $out
    $tmpFiles += (Join-Path $here "..\launcher.example.ini")
    if (Test-Path $zipName) { Remove-Item $zipName -Force }
    Compress-Archive -Path $tmpFiles -DestinationPath $zipName -Force
}

Write-Host "Build output placed in: $outDir"
Write-Host "Generating checksums (SHA256, SHA512) for built artifacts"
$checksums = Join-Path $outDir "checksums.txt"
If (Test-Path $checksums) { Remove-Item $checksums -Force }
Get-ChildItem -Path $outDir -File | ForEach-Object {
    $sha256 = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
    $sha512 = (Get-FileHash -Path $_.FullName -Algorithm SHA512).Hash
    "$($_.Name) SHA256:$sha256 SHA512:$sha512" | Out-File -FilePath $checksums -Append -Encoding ASCII
}
Write-Host "Checksums written to: $checksums"
Exit 0
