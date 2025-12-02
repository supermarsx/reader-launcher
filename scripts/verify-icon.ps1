#!/usr/bin/env pwsh
Add-Type -AssemblyName System.Drawing
$errorActionPreference = 'Stop'
function Test-Icon { param($Path)
    if (-not (Test-Path $Path)) { Write-Error "$Path does not exist"; return 1 }
    try {
        $ico = [System.Drawing.Icon]::ExtractAssociatedIcon((Resolve-Path $Path).Path)
        if ($ico) { Write-Host "Icon present in: $Path (size=$($ico.Size))"; return 0 }
        else { Write-Error "No icon found in: $Path"; return 2 }
    } catch { Write-Error ("Error extracting icon from {0}: {1}" -f $Path, $_.Exception.Message); return 3 }
}

if ($args.Count -eq 0) { Write-Host 'Usage: verify-icon.ps1 <exe-path>'; exit 2 }
$rc = 0
foreach ($a in $args) { $r = Test-Icon -Path $a; if ($r -ne 0) { $rc = $r } }
exit $rc
