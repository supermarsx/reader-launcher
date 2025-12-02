<#
  autodiscovery-test.ps1
  Check whether this machine has a discoverable PDF reader via registry or common folders.
  The script returns 0 if at least one candidate was found.
#>

$found = @()

Try {
    $r1 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe' -ErrorAction SilentlyContinue
    If ($r1 -and $r1.'') { $found += $r1.'' }
} Catch { }

Try {
    $r2 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe' -ErrorAction SilentlyContinue
    If ($r2 -and $r2.'') { $found += $r2.'' }
} Catch { }

$candidates = @(
    "$env:ProgramFiles\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
    "$env:ProgramFiles\Adobe\Acrobat\Acrobat.exe",
    "$env:ProgramFiles\SumatraPDF\SumatraPDF.exe",
    "$env:ProgramFiles(x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
    "$env:ProgramFiles(x86)\Adobe\Acrobat\Acrobat.exe",
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
