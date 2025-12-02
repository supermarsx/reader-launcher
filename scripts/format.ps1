$ErrorActionPreference = 'Stop'

<#
  format.ps1

  Purpose:
    Try to format AutoIt code using a known formatting utility (`au3fix`) when
    available. Because there is no single standard cross-platform AutoIt
    formatter, this helper is intentionally conservative:

    - If `au3fix` is in PATH it will be invoked to format the source file
    - Otherwise the script is a no-op and prints guidance on how to enable
      formatting locally.

  Usage:
    pwsh -ExecutionPolicy Bypass -File scripts\format.ps1

  Notes:
    - Formatting is optional and non-fatal for developers — CI can include
      additional style checks if desired.
#>
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = Join-Path $here "..\src\reader_launcher.au3" | Resolve-Path -ErrorAction Stop

Write-Host "Formatting $file" -ForegroundColor Cyan

$formatter = Get-Command au3fix -ErrorAction SilentlyContinue
If ($formatter) {
    Write-Host "Found au3fix, running formatting..."
    & $formatter.Path $file
    Exit $LASTEXITCODE
} Else {
    Write-Warning "No AutoIt formatter (au3fix) found in PATH. This script is a no-op. Consider installing au3fix or use manual formatting."
    Exit 0
}
