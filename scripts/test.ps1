<#
    test.ps1

    Purpose:
        Run the test suite under `tests/` and report failures in a developer-friendly
        way. The test runner separates tests that are required (fail the script)
        from optional tests (skip gracefully when dependencies are missing).

    Behaviour:
        - Required tests must pass and will cause the script to exit non-zero if they fail
        - Optional tests are executed but their failure does not affect the overall
            exit code. This is useful for tests that require environment-specific
            dependencies (e.g., AutoIt runtime or additional installed apps)

    Usage:
        pwsh -ExecutionPolicy Bypass -File scripts\test.ps1

#>
Write-Host "Running tests..." -ForegroundColor Cyan

$requiredTests = @("tests\validate-config.ps1", "tests\validate-config-cases.ps1")
$optionalTests = @("tests\autodiscovery-test.ps1", "tests\unit\run-unit-tests.ps1")
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
