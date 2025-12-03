<#
    autodiscovery-test.ps1

    Purpose:
        Inspect the local machine for likely PDF reader installations using both
        App Paths registry keys and common Program Files locations. This test is
        optional in the project's test harness because developer machines and CI
        images may not include a PDF reader.

    Usage:
        pwsh -ExecutionPolicy Bypass -File tests\autodiscovery-test.ps1

    Exit codes:
        0 = at least one candidate discovered
        1 = no candidates found

#>

$found = @()

Try {
    $r1 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe' -ErrorAction SilentlyContinue
    If ($r1 -and $r1.'') { $found += $r1.'' }
} Catch { }

Try {
    $inst = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Adobe\Adobe Acrobat\DC\Installer' -ErrorAction SilentlyContinue
    If ($inst -and $inst.SCAPackageLevel) {
        $cand = "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
        If (Test-Path $cand) { $found += $cand }
    }
} Catch { }

Try {
    $inst2 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Adobe\Adobe Acrobat\DC\Installer' -ErrorAction SilentlyContinue
    If ($inst2 -and $inst2.SCAPackageLevel) {
        $cand = "$env:ProgramFiles(x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
        If (Test-Path $cand) { $found += $cand }
    }
} Catch { }

Try {
    $r2 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe' -ErrorAction SilentlyContinue
    If ($r2 -and $r2.'') { $found += $r2.'' }
} Catch { }

$candidates = @(
    "$env:ProgramFiles\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
    "$env:ProgramFiles\Adobe\Acrobat\Acrobat.exe",
    "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
    "$env:ProgramFiles\SumatraPDF\SumatraPDF.exe",
    "$env:ProgramFiles(x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
    "$env:ProgramFiles(x86)\Adobe\Acrobat\Acrobat.exe",
    "$env:ProgramFiles(x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
    "$env:ProgramFiles(x86)\SumatraPDF\SumatraPDF.exe"
)

foreach ($c in $candidates) {
    if (Test-Path $c) { $found += $c }
}

if ($found.Count -gt 0) {
    Write-Host "Autodiscovery candidates found:`n$($found -join "`n")" -ForegroundColor Green
    Exit 0
} else {
    Write-Warning "No autodiscovery candidates found on this machine."
    Exit 1
}
