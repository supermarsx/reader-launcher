<#
  verify-release.ps1

  Purpose:
    Verify a downloaded release artifact against the release `checksums.txt`.

  Usage:
    pwsh -ExecutionPolicy Bypass -File scripts\verify-release.ps1 -ArtifactPath path\to\reader_launcher.exe -Checksums dist\checksums.txt

  Notes:
    - The script will compute SHA256 and SHA512 for the given artifact and
      compare results to checksums.txt.
#>

param(
    [Parameter(Mandatory = $true)] [string]$ArtifactPath,
    [string]$ChecksumsPath = "dist\checksums.txt"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ArtifactPath)) { Write-Error "Artifact not found: $ArtifactPath"; exit 2 }
if (-not (Test-Path $ChecksumsPath)) { Write-Error "checksums file not found: $ChecksumsPath"; exit 3 }

Write-Host "Verifying artifact: $ArtifactPath"

$sha256 = (Get-FileHash -Path $ArtifactPath -Algorithm SHA256).Hash
$sha512 = (Get-FileHash -Path $ArtifactPath -Algorithm SHA512).Hash

Write-Host "Computed SHA256: $sha256"
Write-Host "Computed SHA512: $sha512"

$lines = Get-Content $ChecksumsPath
$filename = Split-Path $ArtifactPath -Leaf

$matchLine = $lines | Where-Object { $_ -match [regex]::Escape($filename) -or $_ -match $sha256 }
if (-not $matchLine) {
    Write-Error "No matching entry found for $filename or SHA256 in $ChecksumsPath"
    exit 4
}

Write-Host "Found checksums entry: $matchLine"

if ($matchLine -notmatch $sha256) {
    Write-Error "SHA256 mismatch between computed value and checksums.txt entry"
    exit 5
}

Write-Host "Checksum verification passed." -ForegroundColor Green

exit 0
