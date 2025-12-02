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

Write-Host "Core unit tests passed — continuing with extended coverage checks" -ForegroundColor Green

## ----------------------
## EXTENDED UNIT TESTS
## These tests increase coverage for runtime behavior that is convenient to test
## when AutoIt is available on the machine (CI or developer machine with AutoIt).
##
## Test 5 -> logfile append / overwrite behavior
## Test 6 -> sleeprand and legacy sleeprandom acceptance (logged)
## Test 7 -> quoted execpath trimmed correctly and default preset detected
## ----------------------

# Test 5 - logfile append vs overwrite behaviour
$tmpLog5 = Join-Path $here "..\tmp\unit-test-append.log"
If (Test-Path $tmpLog5) { Remove-Item $tmpLog5 -Force }

Write-Host "Running unit test: logfile append/overwrite behaviour"
$args5a = @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4','/logfile=' + $tmpLog5,'/logappend=1')
& $autoit.Path $script.Path $args5a
Start-Sleep -Milliseconds 250
& $autoit.Path $script.Path $args5a
Start-Sleep -Milliseconds 250
if (-not (Test-Path $tmpLog5)) { Write-Error "Unit test failed: append log not created"; Exit 12 }
$lines = (Get-Content $tmpLog5 -ErrorAction SilentlyContinue | Where-Object { $_ -ne "" })
if ($lines.Count -lt 2) { Write-Error "Unit test failed: expected appended log entries, found $($lines.Count)"; Exit 13 }

# Now run with overwrite (logappend=0) and verify only a single fresh entry exists
& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4','/logfile=' + $tmpLog5,'/logappend=0')
Start-Sleep -Milliseconds 250
$final = (Get-Content $tmpLog5 -ErrorAction SilentlyContinue | Where-Object { $_ -ne "" })
if ($final.Count -ne 1) { Write-Error "Unit test failed: expected overwrite to produce single log entry, found $($final.Count)"; Exit 14 }

# Test 6 - sleeprand and legacy key sleeprandom should be accepted and logged
Write-Host "Running unit test: sleeprand/sleeprandom logging"
$tmpLog6 = Join-Path $here "..\tmp\unit-test-sleeprand.log"
If (Test-Path $tmpLog6) { Remove-Item $tmpLog6 -Force }

# Use sleeprand=1 to check debug log contains Randomize sleep: 1
$iniSrand = @"
[general]
sleepmin=200
sleepmax=400
sleeprand=1
logenabled=1
loglevel=4
"@
$iniFile = Join-Path $here "..\..\launcher.ini"
$backupIni2 = ""
if (Test-Path $iniFile) { $backupIni2 = Join-Path $here "..\tmp\launcher.ini.srand.bak"; Copy-Item $iniFile $backupIni2 -Force }
$iniSrand | Out-File -FilePath $iniFile -Encoding ASCII

& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4','/logfile=' + $tmpLog6)
Start-Sleep -Milliseconds 250
if (-not (Test-Path $tmpLog6)) { Write-Error "Unit test failed: sleeprand log not created"; Exit 15 }
$c6 = Get-Content $tmpLog6 -ErrorAction SilentlyContinue
if ($c6 -notmatch 'Randomize sleep: 1') { Write-Error "Unit test failed: Randomize sleep message not found (sleeprand)"; Exit 16 }

# Now repeat using legacy sleeprandom key
If (Test-Path $tmpLog6) { Remove-Item $tmpLog6 -Force }
$iniSrand2 = @"
[general]
sleepmin=123
sleepmax=321
sleeprandom=1
logenabled=1
loglevel=4
"@
$iniSrand2 | Out-File -FilePath $iniFile -Encoding ASCII
& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4','/logfile=' + $tmpLog6)
Start-Sleep -Milliseconds 250
$c62 = Get-Content $tmpLog6 -ErrorAction SilentlyContinue
if ($c62 -notmatch 'Randomize sleep: 1') { Write-Error "Unit test failed: Randomize sleep message not found (sleeprandom)"; Exit 17 }

# restore original launcher.ini if it existed
If (Test-Path $backupIni2) { Move-Item $backupIni2 $iniFile -Force } Else { Remove-Item $iniFile -ErrorAction SilentlyContinue }

# Test 7 - quoted execpath should be trimmed and default preset should still be selected
Write-Host "Running unit test: quoted execpath trimming / default preset detection"
$tmpLog7 = Join-Path $here "..\tmp\unit-test-quoted-execpath.log"
If (Test-Path $tmpLog7) { Remove-Item $tmpLog7 -Force }

$iniQuoted = @"
[general]
execpath="""C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"""
logenabled=1
loglevel=4
"@
$iniQuoted | Out-File -FilePath $iniFile -Encoding ASCII
& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4','/logfile=' + $tmpLog7,'C:\file.pdf')
Start-Sleep -Milliseconds 250
if (-not (Test-Path $tmpLog7)) { Write-Error "Unit test failed: quoted execpath log not created"; Exit 18 }
$c7 = Get-Content $tmpLog7 -ErrorAction SilentlyContinue
if ($c7 -notmatch 'Auto-selected preset: suppress') { Write-Error "Unit test failed: expected auto-selected preset 'suppress' for quoted execpath"; Exit 19 }

# cleanup temp ini if present
If (Test-Path $backupIni) { Move-Item $backupIni $projectRootIni -Force }

Write-Host "All extended unit tests passed" -ForegroundColor Green
Exit 0
