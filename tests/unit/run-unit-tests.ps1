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
# Test 1 - basic logfile creation
$args = "/debugnoexec=1 /debugnosleep=1 /logenabled=1 /loglevel=4 /logfile=`"$tmpLog`""
& $autoit.Path $script.Path $args
Start-Sleep -Seconds 1
if (-not (Test-Path $tmpLog)) {
    Write-Error "Unit test failed: log file was not created: $tmpLog"
    Exit 1
}
$content = Get-Content $tmpLog -ErrorAction SilentlyContinue
if (-not ($content -match 'Log initialized')) {
    Write-Error "Unit test failed: log content didn't contain initial marker"
    Write-Host "Log contents:" -ForegroundColor Yellow
    Write-Host $content
    Exit 2
}

# Test 2 - extra_params are picked up and appear in the debug log
$tmpLog2 = Join-Path $here "..\tmp\unit-test-params.log"
If (Test-Path $tmpLog2) { Remove-Item $tmpLog2 -Force }
$args2 = "/debugnoexec=1 /debugnosleep=1 /logenabled=1 /loglevel=4 /logfile=`"$tmpLog2`" /extra_params=/s ""C:\test.pdf"""
& $autoit.Path $script.Path $args2
Start-Sleep -Seconds 1
if (-not (Test-Path $tmpLog2)) { Write-Error "Unit test failed: second log not created"; Exit 3 }
$c2 = Get-Content $tmpLog2 -ErrorAction SilentlyContinue
if ($c2 -notmatch 'Launcher parameters:') { Write-Error "Unit test failed: no Launcher parameters debug log found"; Exit 4 }
if ($c2 -notmatch '/s') { Write-Error "Unit test failed: extra_params '/s' not found in debug log"; Exit 5 }

# Test 3 - preset selection (newinstance -> /n should be present)
$tmpLog3 = Join-Path $here "..\tmp\unit-test-preset.log"
If (Test-Path $tmpLog3) { Remove-Item $tmpLog3 -Force }
$args3 = "/debugnoexec=1 /debugnosleep=1 /logenabled=1 /loglevel=4 /logfile=`"$tmpLog3`" /preset=newinstance ""C:\file.pdf"""
& $autoit.Path $script.Path $args3
Start-Sleep -Seconds 1
if (-not (Test-Path $tmpLog3)) { Write-Error "Unit test failed: preset log not created"; Exit 6 }
$c3 = Get-Content $tmpLog3 -ErrorAction SilentlyContinue
if ($c3 -notmatch 'Launcher parameters:') { Write-Error "Unit test failed: no Launcher parameters debug log in preset test"; Exit 7 }
if ($c3 -notmatch '/n') { Write-Error "Unit test failed: preset '/n' not found in debug log"; Exit 8 }

# Test 4 - default preset auto-selection based on execpath (Acrobat -> suppress /s)
$tmpLog4 = Join-Path $here "..\tmp\unit-test-default-preset.log"
If (Test-Path $tmpLog4) { Remove-Item $tmpLog4 -Force }

# create temporary launcher.ini (project root) and preserve existing if present
$projectRootIni = Join-Path $here "..\..\launcher.ini"
$backupIni = ""
if (Test-Path $projectRootIni) { $backupIni = Join-Path $here "..\tmp\launcher.ini.bak"; Copy-Item $projectRootIni $backupIni -Force }

$iniContent = @"
[general]
execpath=C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe
logenabled=1
loglevel=4
"@
$iniContent | Out-File -FilePath $projectRootIni -Encoding ASCII

$args4 = "/debugnoexec=1 /debugnosleep=1 /logenabled=1 /loglevel=4 /logfile=`"$tmpLog4`" ""C:\file.pdf"""
& $autoit.Path $script.Path $args4
Start-Sleep -Seconds 1
if (-not (Test-Path $tmpLog4)) { Write-Error "Unit test failed: default preset log not created"; Exit 9 }
$c4 = Get-Content $tmpLog4 -ErrorAction SilentlyContinue
if ($c4 -notmatch '/s') { Write-Error "Unit test failed: default preset '/s' not found in debug log"; Exit 10 }

# cleanup temp ini and restore backup
Remove-Item $projectRootIni -Force
if (Test-Path $backupIni) { Move-Item $backupIni $projectRootIni -Force }

Write-Host "All unit tests passed" -ForegroundColor Green
Exit 0

# Optional Test 5 - if dist exists (build ran in CI) check checksums file
if (Test-Path (Join-Path $here "..\..\dist\checksums.txt")) {
    Write-Host "Found checksums file in dist — verifying entries"
    $checks = Get-Content (Join-Path $here "..\..\dist\checksums.txt")
    if ($checks -notmatch 'reader_launcher.exe') { Write-Error "checksums.txt missing reader_launcher.exe"; Exit 11 }
    if ($checks -notmatch 'reader_launcher-upx.exe') { Write-Warning "checksums.txt may be missing upx variant — OK on systems without UPX" }
    Write-Host "Checksums file verified (basic check)."
}
