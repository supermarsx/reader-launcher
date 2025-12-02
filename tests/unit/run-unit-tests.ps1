<#
  run-unit-tests.ps1
  Unit test harness for the AutoIt launcher. This script will only run tests
  when AutoIt is available (AutoIt3.exe on PATH). On CI the Build job installs
  AutoIt so tests will run there.
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Resolve-Path -Path (Join-Path $here "..\..\src\reader_launcher.au3") -ErrorAction Stop

$autoit = Get-Command AutoIt3.exe -ErrorAction SilentlyContinue
if (-not $autoit) {
    Write-Warning "AutoIt3.exe not found — skipping unit tests. To execute unit tests install AutoIt."
    Exit 0
}

$tmpLog = Join-Path $here "..\tmp\unit-test.log"
If (-not (Test-Path (Split-Path $tmpLog))) { New-Item -ItemType Directory -Path (Split-Path $tmpLog) | Out-Null }
If (Test-Path $tmpLog) { Remove-Item $tmpLog -Force }

Write-Host "Running unit test: ensure launcher runs in debug/dry-run mode and writes log"

$args = "/debugnoexec=1 /debugnosleep=1 /logenabled=1 /logfile=`"$tmpLog`""

& $autoit.Path $script.Path $args

Start-Sleep -Seconds 1

if (-not (Test-Path $tmpLog)) {
    Write-Error "Unit test failed: log file was not created: $tmpLog"
    Exit 1
}

$content = Get-Content $tmpLog -ErrorAction SilentlyContinue
if ($content -match 'Log initialized') {
    Write-Host "Unit test passed: log contains expected content" -ForegroundColor Green
    Exit 0
} else {
    Write-Error "Unit test failed: log content didn't contain expected marker"
    Write-Host "Log contents:" -ForegroundColor Yellow
    Write-Host $content
    Exit 2
}
