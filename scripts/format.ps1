<#
  format.ps1
  Try to format AutoIt code. There's no widely-used AutoIt formatter included, so this script
  is a safe no-op that will notify if a plausible formatter is installed.
#>
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = Join-Path $here "..\reader_launcher.au3" | Resolve-Path -ErrorAction Stop

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
