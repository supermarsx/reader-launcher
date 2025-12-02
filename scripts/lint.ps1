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

$au3check = Get-Command au3check -ErrorAction SilentlyContinue
If (-not $au3check) {
    Write-Warning "au3check not found in PATH. Skipping AutoIt lint. Install AutoIt v3 or add au3check to PATH to enable this check."
    Exit 0
}

& $au3check.Path $file
Exit $LASTEXITCODE
