#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
<#
    build.ps1

    Purpose:
        Compile the AutoIt source to a distributable EXE and create additional
        artifacts useful for releases (UPX-compressed variant when available and
        a zip package that includes the example config). The script also generates
        checksums.txt (SHA256 + SHA512) to allow artifact verification.

    Behavior & notes:
        - The script looks for Aut2Exe on PATH and also checks the common
            AutoIt install location. ``Aut2Exe`` may be returned as a CommandInfo
            object (Get-Command) or as a plain path string; this script handles
            both cases robustly.
        - UPX compression is optional; if present the script creates an additional
            UPX-compressed copy of the compiled EXE. If UPX is not found the script
            copies the regular EXE to the UPX filename (so downstream releases still
            have a matching name).
        - The script produces a zip containing the non-UPX EXE and the
            `launcher.example.ini` so users downloading the release have a ready-to-run
            package.

    Usage (local):
        pwsh -ExecutionPolicy Bypass -File scripts\build.ps1

    Exit codes:
        0 = successful build & checksum generation
        1 = fatal invocation error (Aut2Exe/UPX invocation failure or missing output)
        2 = Aut2Exe not present
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "..\src\reader_launcher.au3" | Resolve-Path -ErrorAction Stop
$outDir = Join-Path $here "..\dist"
If (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$out = Join-Path $outDir "reader_launcher.exe"
$out_upx = Join-Path $outDir "reader_launcher-upx.exe"
$zipName = Join-Path $outDir "reader_launcher_package.zip"
# Also produce a UPX package that contains the compressed executable when present
$zipNameUpx = Join-Path $outDir "reader_launcher_upx_package.zip"

## locate Aut2Exe (attempt PATH first, then common install locations)
$aut2exe = Get-Command Aut2Exe -ErrorAction SilentlyContinue
if (-not $aut2exe) {
    $candidates = @(
        "C:\\Program Files (x86)\\AutoIt3\\Aut2Exe\\Aut2Exe.exe",
        "C:\\Program Files\\AutoIt3\\Aut2Exe\\Aut2Exe.exe",
        "C:\\Program Files (x86)\\AutoIt3\\Aut2Exe.exe",
        "C:\\Program Files\\AutoIt3\\Aut2Exe.exe",
        "C:\\ProgramData\\chocolatey\\lib\\autoit\\tools\\Aut2Exe.exe",
        "C:\\ProgramData\\chocolatey\\bin\\Aut2Exe.exe"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { $aut2exe = $p; break } }
}

if (-not $aut2exe) {
    Write-Warning "Aut2Exe (AutoIt compiler) not found. Can't build. Install AutoIt or use AutoIt3Wrapper in SciTE."
    Exit 2
}

Write-Host "Compiling $src -> $out"
## Read project version for informational purposes (keeps logs clear)
$verFile = Join-Path $here "..\VERSION"
if (Test-Path $verFile) { $projVer = (Get-Content -Path $verFile -Raw).Trim(); Write-Host "Project VERSION: $projVer" }
try {
    # detect an icon file in assets (pick the first .ico) and include it when invoking Aut2Exe
    $assetsDir = Join-Path $here "..\assets"
    $icon = $null
    if (Test-Path $assetsDir) {
        $ico = Get-ChildItem -Path $assetsDir -Filter *.ico -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ico) { $icon = $ico.FullName; Write-Host "Found icon to embed: $icon" -ForegroundColor Cyan }
    }
    # Prefer AutoIt3Wrapper (when present) so wrapper directives like UseConsole are honored.
    $wrapper = Get-Command AutoIt3Wrapper -ErrorAction SilentlyContinue
    if (-not $wrapper) {
        $wrapperCandidates = @( 
            "C:\\Program Files (x86)\\AutoIt3\\AutoIt3Wrapper\\AutoIt3Wrapper.exe",
            "C:\\Program Files\\AutoIt3\\AutoIt3Wrapper\\AutoIt3Wrapper.exe",
            "C:\\Program Files (x86)\\AutoIt3\\AutoIt3Wrapper.exe",
            "C:\\Program Files\\AutoIt3\\AutoIt3Wrapper.exe"
        )
        foreach ($p in $wrapperCandidates) { if (Test-Path $p) { $wrapper = $p; break } }
    }

    # Run Aut2Exe once and capture output in a temp log for diagnostics.
    $tempLog = [IO.Path]::GetTempFileName() + '.aut2exe.log'
    Write-Host "Aut2Exe command: $aut2exe" -ForegroundColor Cyan
    Write-Host "Capturing Aut2Exe output in: $tempLog"
    # If AutoIt3Wrapper is present prefer it so wrapper directives (e.g., UseConsole) are respected.
    if ($wrapper) {
        Write-Host "Using AutoIt3Wrapper for compilation: $wrapper" -ForegroundColor Cyan
        if ($icon) {
            if ($wrapper -is [string]) { & "$wrapper" /in "$src" /out "$out" /icon "$icon" *>&1 | Tee-Object -FilePath $tempLog }
            else { & "$($wrapper.Path)" /in "$src" /out "$out" /icon "$icon" *>&1 | Tee-Object -FilePath $tempLog }
        }
        else {
            if ($wrapper -is [string]) { & "$wrapper" /in "$src" /out "$out" *>&1 | Tee-Object -FilePath $tempLog }
            else { & "$($wrapper.Path)" /in "$src" /out "$out" *>&1 | Tee-Object -FilePath $tempLog }
        }
    }
    else {
        # fallback to direct Aut2Exe invocation
        if ($icon) {
            if ($aut2exe -is [string]) { & "$aut2exe" /in "$src" /out "$out" /icon "$icon" *>&1 | Tee-Object -FilePath $tempLog }
            else { & "$($aut2exe.Path)" /in "$src" /out "$out" /icon "$icon" *>&1 | Tee-Object -FilePath $tempLog }
        }
        else {
            if ($aut2exe -is [string]) { & "$aut2exe" /in "$src" /out "$out" *>&1 | Tee-Object -FilePath $tempLog }
            else { & "$($aut2exe.Path)" /in "$src" /out "$out" *>&1 | Tee-Object -FilePath $tempLog }
        }
    }

    # Some Aut2Exe versions return non-zero even when an EXE is produced.
    if (-not (Test-Path $out)) {
        Write-Error "Aut2Exe did not produce $out; compilation failed. Dumping Aut2Exe log below for diagnostics:"
        if (Test-Path $tempLog) { Get-Content $tempLog | ForEach-Object { Write-Host "    $_" } }
        Exit 1
    }

    # remove temp log on success
    if (Test-Path $tempLog) { Remove-Item $tempLog -Force -ErrorAction SilentlyContinue }
}
catch {
    Write-Error "Aut2Exe invocation failed: $($_.Exception.Message)"
    if ($tempLog -and (Test-Path $tempLog)) { Write-Host "Aut2Exe log:"; Get-Content $tempLog | ForEach-Object { Write-Host "  $_" } }
    Exit 1
}

# -----------------------------------------------------------------------------
# UPX handling: create a compressed variant if UPX is available. If UPX isn't
# found or fails, create an exact copy using the -upx filename so release
# artifacts remain predictable.
# -----------------------------------------------------------------------------
$upx = Get-Command upx -ErrorAction SilentlyContinue
if (-not $upx) {
    $upxCandidates = @(
        "C:\Program Files\upx\upx.exe",
        "C:\ProgramData\chocolatey\lib\upx\tools\upx.exe",
        "C:\Program Files (x86)\upx\upx.exe"
    )
    foreach ($p in $upxCandidates) { if (Test-Path $p) { $upx = $p; break } }
}

if ($upx) {
    Write-Host "UPX found; creating compressed copy at: $out_upx"
    # create a copy to compress so we keep the original intact
    Copy-Item -Path $out -Destination $out_upx -Force
    try {
        if ($upx -is [string]) { & "$upx" "$out_upx" *>&1 | Tee-Object -FilePath ([IO.Path]::GetTempFileName() + '.upx.log') }
        else { & "$($upx.Path)" "$out_upx" *>&1 | Tee-Object -FilePath ([IO.Path]::GetTempFileName() + '.upx.log') }
    }
    catch {
        Write-Warning "UPX invocation failed: $($_.Exception.Message) -- falling back to copying the primary EXE"
        # On failure ensure we have a non-compressed artifact at the -upx filename
        Copy-Item -Path $out -Destination $out_upx -Force
    }
}
else {
    Write-Host "UPX not found; creating an identical copy for $out_upx"
    Copy-Item -Path $out -Destination $out_upx -Force
}

# -----------------------------------------------------------------------------
# Create a zip package containing the non-UPX EXE and an example config if present
# -----------------------------------------------------------------------------
$tmpFiles = @()
$tmpFiles += $out
if ($icon) { $tmpFiles += $icon }
$exampleIni = Join-Path $here "..\launcher.example.ini"
if (Test-Path $exampleIni) { $tmpFiles += $exampleIni } else { Write-Warning "launcher.example.ini not found; zip package will not include example config" }

if (Test-Path $zipName) { Remove-Item $zipName -Force }
Compress-Archive -Path $tmpFiles -DestinationPath $zipName -Force

# Ensure example config is also present as a top-level artifact for releases
if (Test-Path $exampleIni) {
    $exampleTarget = Join-Path $outDir "launcher.example.ini"
    Copy-Item -Path $exampleIni -Destination $exampleTarget -Force
}

# Build a second zip that contains the UPX variant (or the copied -upx file)
$tmpFilesUpx = @()
$tmpFilesUpx += $out_upx
if ($icon) { $tmpFilesUpx += $icon }
if (Test-Path $exampleIni) { $tmpFilesUpx += $exampleIni }
if (Test-Path $zipNameUpx) { Remove-Item $zipNameUpx -Force }
Compress-Archive -Path $tmpFilesUpx -DestinationPath $zipNameUpx -Force

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

# -----------------------------------------------------------------------------
# Post-compile: attempt to embed metadata and ensure console capability (rcedit)
# If rcedit is available on runner, use it to set ProductVersion/FileVersion
# and FileDescription/ProductName based on source wrapper directives or VERSION.
# This is optional but helps when Aut2Exe does not embed wrapper resources.
# -----------------------------------------------------------------------------
Write-Host "Attempting post-compile metadata fix using rcedit (if available)"
$rcedit = Get-Command rcedit -ErrorAction SilentlyContinue
if (-not $rcedit) {
    $rceditCandidates = @("C:\\Program Files\\rcedit\\rcedit.exe","C:\\Program Files (x86)\\rcedit\\rcedit.exe","C:\\ProgramData\\chocolatey\\bin\\rcedit.exe")
    foreach ($p in $rceditCandidates) { if (Test-Path $p) { $rcedit = $p; break } }
}
if ($rcedit) {
    Write-Host "Found rcedit: $rcedit" -ForegroundColor Cyan
    # Read version/product strings from source wrapper or VERSION file
    $sourceText = Get-Content -Path $src -Raw -ErrorAction SilentlyContinue
    $wrappedFileVer = '' ; $wrappedProdVer = '' ; $prodName = '' ; $fileDesc = ''
    if ($sourceText) {
        $m = [regex]::Match($sourceText, "AutoIt3Wrapper_Res_Fileversion=(?<fv>.*)")
        if ($m.Success) { $wrappedFileVer = $m.Groups['fv'].Value.Trim() }
        $m = [regex]::Match($sourceText, "AutoIt3Wrapper_Res_ProductVersion=(?<pv>.*)")
        if ($m.Success) { $wrappedProdVer = $m.Groups['pv'].Value.Trim() }
        $m = [regex]::Match($sourceText, "AutoIt3Wrapper_Res_ProductName=(?<pn>.*)")
        if ($m.Success) { $prodName = $m.Groups['pn'].Value.Trim() }
        $m = [regex]::Match($sourceText, "AutoIt3Wrapper_Res_FileDescription=(?<fd>.*)")
        if ($m.Success) { $fileDesc = $m.Groups['fd'].Value.Trim() }
    }
    if (-not $wrappedProdVer -and Test-Path $verFile) { $wrappedProdVer = (Get-Content -Path $verFile -Raw).Trim() }
    if (-not $wrappedFileVer -and $wrappedProdVer) { $wrappedFileVer = $wrappedProdVer + ".0" }

    # apply metadata to non-upx and upx exes
    $applyTo = @($out, $out_upx)
    foreach ($f in $applyTo) {
        if (Test-Path $f) {
            $args = @()
            if ($wrappedFileVer) { $args += "--set-file-version"; $args += $wrappedFileVer }
            if ($wrappedProdVer) { $args += "--set-product-version"; $args += $wrappedProdVer }
            if ($prodName) { $args += "--set-version-string"; $args += "ProductName"; $args += $prodName }
            if ($fileDesc) { $args += "--set-version-string"; $args += "FileDescription"; $args += $fileDesc }
            if ($args.Count -gt 0) {
                Write-Host "Applying metadata to: $f with args: $($args -join ' ')"
                & "$rcedit" $f $args *>&1 | Tee-Object -FilePath ([IO.Path]::GetTempFileName() + '.rcedit.log')
            } else { Write-Host "No metadata fields found to apply for $f" }
        }
    }
} else { Write-Host "rcedit not found; skipping post-compile metadata step (optional)." }
Exit 0
