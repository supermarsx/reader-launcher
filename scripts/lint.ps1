$ErrorActionPreference = 'Stop'

<#
  lint.ps1

  Purpose:
    Run a lightweight lint check for the AutoIt source file using `au3check` if it
    is installed and available on the PATH. This script is intentionally forgiving
    for local developer environments: if `au3check` is not present the script
    prints a helpful warning and exits with code 0 so CI is not blocked.

  Usage:
    pwsh -ExecutionPolicy Bypass -File scripts\lint.ps1

  Notes:
    - CI runners should have au3check available to enable a real lint check.
    - The script returns `au3check`'s exit code when run.
#>
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = Join-Path $here "..\src\reader_launcher.au3" | Resolve-Path -ErrorAction Stop

Write-Host "Running lint for $file"

## prefer a command on PATH, but if not present try the common AutoIt install path
$au3check = Get-Command au3check -ErrorAction SilentlyContinue
If (-not $au3check) {
    $possiblePaths = @(
        "C:\\Program Files (x86)\\AutoIt3\\Au3Check.exe",
        "C:\\Program Files\\AutoIt3\\Au3Check.exe"
    )
    foreach ($p in $possiblePaths) { if (Test-Path $p) { $au3check = $p; break } }
}

If (-not $au3check) {
    Write-Warning "au3check not found. Skipping AutoIt lint. To enable linting install AutoIt or add au3check to PATH."
    Write-Host "Helpful options:"
    Write-Host "  - Install AutoIt on Windows: https://www.autoitscript.com/"
    Write-Host "  - Install via Chocolatey: choco install autoit -y (enables au3check on PATH)"
    Write-Host "  - If au3check.exe is present but not on PATH, add it to PATH or place it in scripts/tools/ and update this script."
    Exit 0
}

try {
    if ($au3check -is [string]) { & $au3check $file } else { & $au3check.Path $file }
    Exit $LASTEXITCODE
}
catch {
    Write-Error "Failed to execute au3check: $($_.Exception.Message)"
    Exit 1
}
Exit $LASTEXITCODE
