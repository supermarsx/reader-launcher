#!/usr/bin/env pwsh
<#
  bump-version.ps1

  Purpose: Simple helper to bump or set the project version and keep
  source metadata synchronized (src/reader_launcher.au3 and VERSION file).

  Usage:
    # set exact version
    pwsh scripts\bump-version.ps1 -Version 1.2.3

    # bump patch/minor/major
    pwsh scripts\bump-version.ps1 -Bump patch

  Notes:
    - Updates VERSION file and the APP_VERSION constant and AutoIt wrapper
      resource lines inside src/reader_launcher.au3.
    - Does not commit or tag by default; use from CI if you want to commit.
#>

param(
    [ValidateSet('patch', 'minor', 'major')][string]$BumpType = '',
    [string]$Version = ''
)

Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path -Path $root | Select-Object -ExpandProperty Path
$src = Join-Path $root '..\src\reader_launcher.au3' | Resolve-Path -ErrorAction Stop
$repoRoot = (Join-Path $root '..') | Resolve-Path -ErrorAction Stop
# Look for a version file case-insensitively (allow 'VERSION' or 'version')
$versionCandidate = Get-ChildItem -Path $repoRoot -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq 'VERSION' -or $_.Name -ieq 'version' } | Select-Object -First 1
if ($versionCandidate) { $versionPath = $versionCandidate.FullName } else {
    # If not found, create a lowercase 'version' file as the canonical single source of truth
    $versionPath = Join-Path $repoRoot 'version'
    if (-not (Test-Path $versionPath)) { Set-Content -Path $versionPath -Value '0.0.0' -NoNewline -Encoding ASCII }
}

function Parse-Version($v) {
    $parts = $v -split '\.' | ForEach-Object { [int]$_ }
    while ($parts.Count -lt 3) { $parts += 0 }
    return $parts
}

if ($Version -ne '') {
    # validate form
    if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { Write-Error "Invalid version format. Use MAJOR.MINOR.PATCH"; exit 1 }
    $new = $Version
}
elseif ($BumpType -ne '') {
    $current = (Get-Content $versionPath -Raw).Trim()
    if ($current -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { Write-Error "Existing VERSION invalid: $current"; exit 1 }
    $p = Parse-Version $current
    switch ($BumpType) {
        'patch' { $p[2] = $p[2] + 1 }
        'minor' { $p[1] = $p[1] + 1; $p[2] = 0 }
        'major' { $p[0] = $p[0] + 1; $p[1] = 0; $p[2] = 0 }
    }
    $new = "$($p[0]).$($p[1]).$($p[2])"
}
else {
    Write-Host "No version specified. Use -Version or -Bump <patch|minor|major>"; exit 2
}

Write-Host "Updating version to: $new"

# Update VERSION file
Set-Content -Path $versionPath -Value $new -NoNewline -Encoding ASCII

# Update src/reader_launcher.au3 constants and wrapper directives
$au3Path = (Resolve-Path $src).Path
$txt = Get-Content -Path $au3Path -Raw

# Update APP_VERSION constant
# Replace the line that defines APP_VERSION with the new version string
$txt = [regex]::Replace($txt, 'Global Const\s+\$APP_VERSION\s*=.*', "Global Const `$APP_VERSION = `"$new`"")

# Update wrapper resource version lines (FileVersion and ProductVersion) if present
$txt = [regex]::Replace($txt, '(#\s*AutoIt3Wrapper_Res_Fileversion=)\d+\.\d+\.\d+\.\d+', ('$1' + $new + '.0'))
$txt = [regex]::Replace($txt, '(#AutoIt3Wrapper_Res_ProductVersion=)\d+\.\d+\.\d+\.\d+', ('$1' + $new + '.0'))

Set-Content -Path $au3Path -Value $txt -Encoding ASCII

Write-Host "Updated $versionPath and $au3Path" -ForegroundColor Green
exit 0
