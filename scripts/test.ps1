<#
  test.ps1
  Run the test scripts under tests/ and report failures.
#>
Write-Host "Running tests..." -ForegroundColor Cyan

$requiredTests = @("tests\validate-config.ps1", "tests\validate-config-cases.ps1")
$optionalTests = @("tests\autodiscovery-test.ps1")
$failed = @()

foreach ($t in $requiredTests) {
    Write-Host "-> $t"
    pwsh -NoProfile -ExecutionPolicy Bypass -File $t
    if ($LASTEXITCODE -ne 0) { $failed += $t }
}

foreach ($t in $optionalTests) {
    Write-Host "-> (optional) $t"
    pwsh -NoProfile -ExecutionPolicy Bypass -File $t
    if ($LASTEXITCODE -ne 0) { Write-Warning "$t failed — optional tests do not cause overall failure." }
}

if ($failed.Count -gt 0) {
    Write-Error "Some required tests failed: $($failed -join ', ')"
    Exit 1
}

Write-Host "Required tests passed." -ForegroundColor Green
Exit 0
