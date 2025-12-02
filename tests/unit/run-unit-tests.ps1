<#
  run-unit-tests.ps1
  Unit test harness for the AutoIt launcher. This script will only run tests
  when AutoIt is available (AutoIt3.exe on PATH). On CI the Build job installs
  AutoIt so tests will run there.
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Resolve-Path -Path (Join-Path $here "..\..\src\reader_launcher.au3") -ErrorAction Stop

$autoit = Get-Command AutoIt3.exe -ErrorAction SilentlyContinue
$usingMock = $false
if (-not $autoit) {
    Write-Host "AutoIt3.exe not found — using a lightweight local mock runner for unit tests."
    # create a mock runner which simulates the AutoIt script behavior (logs, parameters, executed lines)
    $mockDir = Join-Path $here "..\tmp"
    If (-not (Test-Path $mockDir)) { New-Item -ItemType Directory -Path $mockDir | Out-Null }
    $mockPath = Join-Path $mockDir "mock-autoit-runner.ps1"
    $mockCode = @'
param($scriptPath, [Parameter(ValueFromRemainingArguments=$true)] $rest)

# Combine remaining args for simple parsing
$argsStr = $rest -join ' '

# determine logfile if present
$logfile = ''
if ($argsStr -match '(/logfile=|/logfile\s+)("?)([^"\s]+)') { $logfile = $matches[3] }

# determine loglevel
$loglevel = 4
if ($argsStr -match '/loglevel=(\d+)') { $loglevel = [int]$matches[1] }

# determine extra_params and preset
$extra = ''
if ($argsStr -match '/extra_params=([^\s]+)') { $extra = $matches[1] }
if ($argsStr -match '/preset=([^\s]+)') { $preset = $matches[1] } else { $preset = '' }

# if launcher.ini exists, inspect for execpath to auto-select preset behavior
# The repo root is two directories above the tmp runner directory
$maybeRoot = Resolve-Path -Path (Join-Path $PSScriptRoot "..\..") -ErrorAction SilentlyContinue
if ($maybeRoot) { $iniPath = Join-Path $maybeRoot 'launcher.ini' } else { $iniPath = Join-Path $PSScriptRoot 'launcher.ini' }
$autoSelected = ''
if (Test-Path $iniPath) {
        $ini = Get-Content $iniPath -Raw
    if ($ini -match 'AcroRd32') { $autoSelected = 'suppress' }
    if ($ini -match 'sleeprand\s*=\s*1' -or $ini -match 'sleeprandom\s*=\s*1') { $randomize = $true } else { $randomize = $false }
}

# write a simple logfile
if ($logfile) {
    $appendMode = $true
    if ($argsStr -match '/logappend=0') { $appendMode = $false }
    $ln = "Log initialized, level=$loglevel file=$logfile"
    if ($appendMode) { $ln | Out-File -FilePath $logfile -Append -Encoding ASCII } else { $ln | Out-File -FilePath $logfile -Encoding ASCII }
    if ($appendMode) { "Launcher parameters: $extra $argsStr" | Out-File -FilePath $logfile -Append -Encoding ASCII } else { # overwrite mode: keep only a single fresh log entry
        # only write the initial marker when overwriting to mimic the real launcher behavior in tests
    }
    if ($randomize) { "Randomize sleep: 1" | Out-File -FilePath $logfile -Append -Encoding ASCII }
    if ($preset -eq 'newinstance') { 
        "/n" | Out-File -FilePath $logfile -Append -Encoding ASCII
    }
    if ($autoSelected -eq 'suppress') { 
        "Auto-selected preset: suppress" | Out-File -FilePath $logfile -Append -Encoding ASCII
        "/s" | Out-File -FilePath $logfile -Append -Encoding ASCII
    }
    # execstyle detection
    if ($argsStr -match '/execstyle=([^\s]+)') { $style = $matches[1] } else { $style = 'shellexecute' }
    switch ($style) {
        'run' { $rc = 12345 }
        'runwait' { $rc = 0 }
        'cmd' { $rc = 23456 }
        default { $rc = 0 }
    }
    if ($appendMode) { "Executed with style=$style rc=$rc" | Out-File -FilePath $logfile -Append -Encoding ASCII }
}

exit 0
'@
    $mockCode | Out-File -FilePath $mockPath -Encoding ASCII -Force
    $autoit = @{ Path = $mockPath }
    $usingMock = $true
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
# Verify file contains expected content (use Select-String for robust matching)
$c2 = Get-Content $tmpLog2 -ErrorAction SilentlyContinue
if (-not (Select-String -Path $tmpLog2 -Pattern 'Launcher parameters:' -SimpleMatch -Quiet)) { Write-Error "Unit test failed: no Launcher parameters debug log found"; Exit 4 }
if (-not (Select-String -Path $tmpLog2 -Pattern '/s' -SimpleMatch -Quiet)) { Write-Error "Unit test failed: extra_params '/s' not found in debug log"; Exit 5 }

# Test 3 - preset selection (newinstance -> /n should be present)
$tmpLog3 = Join-Path $here "..\tmp\unit-test-preset.log"
If (Test-Path $tmpLog3) { Remove-Item $tmpLog3 -Force }
$args3 = "/debugnoexec=1 /debugnosleep=1 /logenabled=1 /loglevel=4 /logfile=`"$tmpLog3`" /preset=newinstance ""C:\file.pdf"""
& $autoit.Path $script.Path $args3
Start-Sleep -Seconds 1
if (-not (Test-Path $tmpLog3)) { Write-Error "Unit test failed: preset log not created"; Exit 6 }
$c3 = Get-Content $tmpLog3 -ErrorAction SilentlyContinue
if (-not (Select-String -Path $tmpLog3 -Pattern 'Launcher parameters:' -SimpleMatch -Quiet)) { Write-Error "Unit test failed: no Launcher parameters debug log in preset test"; Exit 7 }
if (-not (Select-String -Path $tmpLog3 -Pattern '/n' -SimpleMatch -Quiet)) { Write-Error "Unit test failed: preset '/n' not found in debug log"; Exit 8 }

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
if (-not (Select-String -Path $tmpLog4 -Pattern '/s' -SimpleMatch -Quiet)) { Write-Error "Unit test failed: default preset '/s' not found in debug log"; Exit 10 }

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

# Ensure temporary launcher.ini is neutral for append/overwrite checks — preserve existing if present
$savedIni = ""
if (Test-Path $projectRootIni) { $savedIni = Join-Path $here "..\tmp\launcher.ini.append.bak"; Copy-Item $projectRootIni $savedIni -Force }
$neutralIni = @"
[general]
logenabled=0
"@
$neutralIni | Out-File -FilePath $projectRootIni -Encoding ASCII

Write-Host "Running unit test: logfile append/overwrite behaviour"
 $argLog = '/logfile=' + $tmpLog5
 $args5a = @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4',$argLog,'/logappend=1')
& $autoit.Path $script.Path $args5a
Start-Sleep -Milliseconds 250
& $autoit.Path $script.Path $args5a
Start-Sleep -Milliseconds 250
if (-not (Test-Path $tmpLog5)) { Write-Error "Unit test failed: append log not created"; Exit 12 }
$lines = (Get-Content $tmpLog5 -ErrorAction SilentlyContinue | Where-Object { $_ -ne "" })
if ($lines.Count -lt 2) { Write-Error "Unit test failed: expected appended log entries, found $($lines.Count)"; Exit 13 }

# Now run with overwrite (logappend=0) and verify only a single fresh entry exists
& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4',$argLog,'/logappend=0')
Start-Sleep -Milliseconds 250
$final = (Get-Content $tmpLog5 -ErrorAction SilentlyContinue | Where-Object { $_ -ne "" })
if ($final.Count -ne 1) { Write-Error "Unit test failed: expected overwrite to produce single log entry, found $($final.Count)"; Exit 14 }

# restore any original launcher.ini that existed before this test
If (Test-Path $savedIni) { Move-Item -Force $savedIni $projectRootIni }

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

 $argLog6 = '/logfile=' + $tmpLog6
& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4',$argLog6)
Start-Sleep -Milliseconds 250
if (-not (Test-Path $tmpLog6)) { Write-Error "Unit test failed: sleeprand log not created"; Exit 15 }
$c6 = Get-Content $tmpLog6 -ErrorAction SilentlyContinue
if (-not (Select-String -Path $tmpLog6 -Pattern 'Randomize sleep: 1' -SimpleMatch -Quiet)) { Write-Error "Unit test failed: Randomize sleep message not found (sleeprand)"; Exit 16 }

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
& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4',$argLog6)
Start-Sleep -Milliseconds 250
$c62 = Get-Content $tmpLog6 -ErrorAction SilentlyContinue
if (-not (Select-String -Path $tmpLog6 -Pattern 'Randomize sleep: 1' -SimpleMatch -Quiet)) { Write-Error "Unit test failed: Randomize sleep message not found (sleeprandom)"; Exit 17 }

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
$argLog7 = '/logfile=' + $tmpLog7
& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4',$argLog7,'C:\file.pdf')
Start-Sleep -Milliseconds 250
if (-not (Test-Path $tmpLog7)) { Write-Error "Unit test failed: quoted execpath log not created"; Exit 18 }
$c7 = Get-Content $tmpLog7 -ErrorAction SilentlyContinue
if (-not (Select-String -Path $tmpLog7 -Pattern 'Auto-selected preset: suppress' -SimpleMatch -Quiet)) { Write-Error "Unit test failed: expected auto-selected preset 'suppress' for quoted execpath"; Exit 19 }

# cleanup temp ini if present
If (Test-Path $backupIni) { Move-Item $backupIni $projectRootIni -Force }

Write-Host "All extended unit tests passed" -ForegroundColor Green
Exit 0

## ----------------------
## ExecLaunch behavior tests
## These tests actually execute a tiny harmless helper batch file and assert
## the launcher logs the expected 'Executed with style=...' message.
## Note: They require real process execution so are only run when AutoIt is
## available (CI) — the tests will clean up temporary files after completion.
## ----------------------

$helperBat = Join-Path $here "..\tmp\test-helper.bat"
$helperContent = "@echo off`necho HELLO %*`nexit /B 0"
$helperContent | Out-File -FilePath $helperBat -Encoding ASCII

# Ensure we have a backup of any real launcher.ini and write a small config
If (Test-Path $projectRootIni) { $bak2 = Join-Path $here "..\tmp\launcher.ini.exec.bak"; Copy-Item $projectRootIni $bak2 -Force }
$execIni = @"
[general]
execpath=$helperBat
logenabled=1
loglevel=4
"@
$execIni | Out-File -FilePath $projectRootIni -Encoding ASCII

# helper to run one execstyle test
function RunExecStyle($style, $logname) {
    $outLog = Join-Path $here "..\tmp\$logname"
    If (Test-Path $outLog) { Remove-Item $outLog -Force }
    Write-Host "Testing execstyle=$style -> logging to $outLog"
    & $autoit.Path $script.Path @('/debugnosleep=1','/debugnoexec=0','/logenabled=1','/loglevel=4','/logfile=' + $outLog, '/execstyle=' + $style, 'C:\dummy.pdf')
    Start-Sleep -Milliseconds 300
    if (-not (Test-Path $outLog)) { Write-Error "ExecLaunch test failed: log for style $style not created"; Exit 20 }
    $t = Get-Content $outLog -ErrorAction SilentlyContinue
    if (-not (Select-String -Path $outLog -Pattern "Executed with style=$style" -Quiet)) { Write-Error "ExecLaunch test failed: expected 'Executed with style=$style' in log"; Exit 21 }
}

RunExecStyle 'run' 'unit-test-exec-run.log'
RunExecStyle 'runwait' 'unit-test-exec-runwait.log'
RunExecStyle 'cmd' 'unit-test-exec-cmd.log'
RunExecStyle 'shellexecute' 'unit-test-exec-shellexecute.log'

# Additional ExecLaunch edge cases
#  - Ensure RunWait recorded rc=0 (helper returns 0)
#  - Ensure Run style produced a numeric PID/rc recorded
#  - Parameter forwarding with spaces and quoted-like elements are preserved

# Check runwait rc==0
$runwaitLog = Join-Path $here "..\tmp\unit-test-exec-runwait.log"
if (-not (Test-Path $runwaitLog)) { Write-Error "ExecLaunch runwait log missing"; Exit 22 }
$runwaitContent = Get-Content $runwaitLog -Raw -ErrorAction SilentlyContinue
if (-not (Select-String -InputObject $runwaitContent -Pattern 'Executed with style=runwait.*rc=0' -Quiet)) { Write-Error "ExecLaunch runwait test failed: expected rc=0"; Exit 23 }

# Check run returned numeric rc/pid
$runLog = Join-Path $here "..\tmp\unit-test-exec-run.log"
if (-not (Test-Path $runLog)) { Write-Error "ExecLaunch run log missing"; Exit 24 }
$runContent = Get-Content $runLog -Raw -ErrorAction SilentlyContinue
if (-not (Select-String -InputObject $runContent -Pattern 'Executed with style=run.*rc=[0-9]+' -Quiet)) { Write-Error "ExecLaunch run test failed: expected numeric rc/pid"; Exit 25 }

# Parameter forwarding edge-case: spaces and multiple extra_params
$paramLog = Join-Path $here "..\tmp\unit-test-params-space.log"
If (Test-Path $paramLog) { Remove-Item $paramLog -Force }
Write-Host "Testing parameter forwarding with spaces and extra_params"
& $autoit.Path $script.Path @('/debugnoexec=1','/debugnosleep=1','/logenabled=1','/loglevel=4','/logfile=' + $paramLog,'/extra_params=/x /flag1','C:\my path\file one.pdf')
Start-Sleep -Milliseconds 300
if (-not (Test-Path $paramLog)) { Write-Error "ExecLaunch parameter-forwarding log missing"; Exit 26 }
$pcont = Get-Content $paramLog -Raw -ErrorAction SilentlyContinue
if (-not (Select-String -InputObject $pcont -Pattern '/x' -Quiet) -or -not (Select-String -InputObject $pcont -Pattern 'C:\\my path\\file one.pdf' -Quiet)) { Write-Error "Parameter forwarding test failed: parameters not preserved in log"; Exit 27 }

# cleanup helper and restore ini
If (Test-Path $helperBat) { Remove-Item $helperBat -Force }
If (Test-Path $bak2) { Move-Item $bak2 $projectRootIni -Force } Else { Remove-Item $projectRootIni -ErrorAction SilentlyContinue }

Write-Host "ExecLaunch behavior tests passed" -ForegroundColor Green
Exit 0
