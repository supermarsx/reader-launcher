Tests for reader-launcher

validate-config.ps1 — basic check for `launcher.ini` keys and types.

Run in PowerShell (from repo root):

```powershell
pwsh -ExecutionPolicy Bypass -File tests\validate-config.ps1
```

This script is intentionally simple — it helps catch basic misconfigurations before packaging the launcher.
