#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
<#
    repro-build.ps1

    Create a reproducible build record and run the standard build pipeline in a deterministic way.
    This helper is intended for maintainers who want a small wrapper to reproduce releases locally
    and to produce a compact manifest describing inputs and outputs.

    Usage:
        pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/repro-build.ps1 [-OutDir <dist>]

#>
param(
    [string]$OutDir = "dist",
    [switch]$SkipUpx
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $here\.. | Out-Null

# record exact inputs
$commit = (git rev-parse --verify HEAD) 2>$null
if ($LASTEXITCODE -ne 0) { $commit = "(no git info)" }
$ver = (Get-Content -Path VERSION -Raw).Trim()
Write-Host "Repro build at commit: $commit, VERSION: $ver"

# ensure a clean step-by-step build run
& pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1

# collect artifacts and checksums
$files = Get-ChildItem -Path $OutDir -File | Sort-Object Name
$manifest = [ordered]@{
    Commit = $commit
    Version = $ver
    Timestamp = (Get-Date).ToString("o")
    Artifacts = @()
}
foreach ($f in $files) {
    $sha256 = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
    $sha512 = (Get-FileHash -Path $f.FullName -Algorithm SHA512).Hash
    $manifest.Artifacts += [ordered]@{ Name = $f.Name; Path = $f.FullName; Size = $f.Length; SHA256 = $sha256; SHA512 = $sha512 }
}

$manifestFile = Join-Path $OutDir "repro_manifest.json"
$manifest | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestFile -Encoding UTF8
Write-Host "Repro manifest written to: $manifestFile"

Pop-Location | Out-Null
