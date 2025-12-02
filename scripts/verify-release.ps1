<#
  verify-release.ps1

  Purpose:
    Verify a downloaded release artifact against the release `checksums.txt`
    and optionally query VirusTotal for a quick detection summary (when a
    `VIRUSTOTAL_API_KEY` is provided via environment or --vtkey).

  Usage:
    pwsh -ExecutionPolicy Bypass -File scripts\verify-release.ps1 -ArtifactPath path\to\reader_launcher.exe -Checksums dist\checksums.txt

  Notes:
    - The script will compute SHA256 and SHA512 for the given artifact and
      compare results to checksums.txt.
    - If a VirusTotal API key is available, the script will query VT for the
      file report (no upload) and print a short detection summary.
#>

param(
    [Parameter(Mandatory=$true)] [string]$ArtifactPath,
    [string]$ChecksumsPath = "dist\checksums.txt",
    [string]$VtKey = $env:VIRUSTOTAL_API_KEY
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

if ($VtKey) {
    Write-Host "Querying VirusTotal for hash summary..."
    try {
        $url = "https://www.virustotal.com/api/v3/files/$sha256"
        $resp = Invoke-RestMethod -Method Get -Uri $url -Headers @{"x-apikey"=$VtKey} -ErrorAction Stop
        $stats = $resp.data.attributes.last_analysis_stats
        $malicious = $stats.malicious
        $suspicious = $stats.suspicious
        $undetected = $stats.undetected
        Write-Host "VirusTotal analysis: malicious=$malicious suspicious=$suspicious undetected=$undetected"
        Write-Host "Detailed GUI: https://www.virustotal.com/gui/file/$sha256/detection"
    } catch {
        Write-Warning "VirusTotal query failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "No VirusTotal API key provided — you can manually check:" -ForegroundColor Yellow
    Write-Host "  https://www.virustotal.com/gui/file/$sha256/detection"
}

exit 0
