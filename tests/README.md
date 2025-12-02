Tests for reader-launcher

validate-config.ps1 — basic check for `launcher.ini` keys and types.

autodiscovery-test.ps1 — try to find a candidate PDF viewer on the current machine using the registry or Program Files locations. It returns success when at least one candidate is found (useful on test machines where Reader is installed).

Run in PowerShell (from repo root):

```powershell
pwsh -ExecutionPolicy Bypass -File tests\validate-config.ps1
pwsh -ExecutionPolicy Bypass -File tests\autodiscovery-test.ps1
```

This script is intentionally simple — it helps catch basic misconfigurations before packaging the launcher.
