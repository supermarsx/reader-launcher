<#
  lint.ps1
  Lint script for AutoIt code using au3check if available.
  Exits with au3check's code if found, otherwise reports it's not installed.
#>
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = Join-Path $here "..\reader_launcher.au3" | Resolve-Path -ErrorAction Stop

Write-Host "Running lint for $file"

$au3check = Get-Command au3check -ErrorAction SilentlyContinue
If (-not $au3check) {
    Write-Warning "au3check not found in PATH. Skipping AutoIt lint. Install AutoIt v3 or add au3check to PATH to enable this check."
    Exit 0
}

& $au3check.Path $file
Exit $LASTEXITCODE
