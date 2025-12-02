<#
  test.ps1
  Run the test scripts under tests/ and report failures.
#>
Write-Host "Running tests..." -ForegroundColor Cyan

$tests = @("tests\validate-config.ps1", "tests\autodiscovery-test.ps1")
$failed = @()

foreach ($t in $tests) {
    Write-Host "-> $t"
    pwsh -NoProfile -ExecutionPolicy Bypass -File $t
    if ($LASTEXITCODE -ne 0) { $failed += $t }
}

if ($failed.Count -gt 0) {
    Write-Error "Some tests failed: $($failed -join ', ')"
    Exit 1
}

Write-Host "All tests passed." -ForegroundColor Green
Exit 0
