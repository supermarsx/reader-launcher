<#
    validate-config-cases.ps1

    Purpose:
        Run a set of predefined INI permutations to verify the validator's
        behavior. Each case creates a temporary INI and invokes
        `validate-config.ps1` with the temporary file.

    Notes:
        - This script keeps tests local and will not overwrite the repository's
            `launcher.ini` file.
        - Exit code 0 indicates all cases behaved as expected; non-zero indicates
            at least one case deviated from expected behavior.

#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$base = @"
[general]
sleep=500
sleeprand=0
sleepmin=950
sleepmax=1950
debug=0
debugnosleep=0
debugnoexec=0
execpath=C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe
logenabled=0
execstyle=ShellExecute
autodiscover=0
"@

$tmpDir = Join-Path $here "tmp"
If (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir | Out-Null }

function RunCase($name, $content, $shouldPass) {
    $file = Join-Path $tmpDir "$name.ini"
    $content | Out-File -FilePath $file -Encoding ASCII
    Write-Host "Running case: $name -> $file"
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$here\validate-config.ps1" -IniPath $file
    $rc = $LASTEXITCODE
    if ($shouldPass -and $rc -ne 0) {
        Write-Error "Case '$name' expected success but failed (rc=$rc)"
        return $false
    }
    elseif (-not $shouldPass -and $rc -eq 0) {
        Write-Error "Case '$name' expected failure but passed"
        return $false
    }
    else {
        Write-Host "Case '$name' behaved as expected." -ForegroundColor Green
        return $true
    }
}

$allOk = $true

$allOk = $allOk -and (RunCase 'valid-default' $base $true)

# invalid number
$broken = $base -replace 'sleep=500', 'sleep=notanumber'
$allOk = $allOk -and (RunCase 'invalid-number' $broken $false)

# inverted sleep range
$badrange = $base -replace 'sleepmin=950', 'sleepmin=2000'
$allOk = $allOk -and (RunCase 'inverted-range' $badrange $false)

# missing execpath
$noexec = $base -replace "execpath=.*", ""
$allOk = $allOk -and (RunCase 'missing-execpath' $noexec $false)

# logging enabled but no logfile specified
$nologfile = $base -replace 'logenabled=0', 'logenabled=1'
$allOk = $allOk -and (RunCase 'logenabled-no-logfile' $nologfile $false)

# invalid execstyle
$badstyle = $base -replace 'execstyle=ShellExecute', 'execstyle=NoSuchMode'
$allOk = $allOk -and (RunCase 'invalid-execstyle' $badstyle $false)

if (-not $allOk) { Write-Error "Some config cases failed"; Exit 1 }
Write-Host "All config cases behaved as expected." -ForegroundColor Green
Exit 0
