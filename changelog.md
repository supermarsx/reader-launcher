# Changelog

All notable changes to this project will be documented in this file.

## Unreleased
- Improve `reader_launcher.au3` config parsing and validation
  - Support both `sleeprand` and legacy `sleeprandom` keys
  - Normalize numeric values and trim surrounding quotes for `execpath`
  - Validate `execpath` and print warnings if missing
  - Better parameter trimming and debug messages
- Update `launcher.ini` to remove stray surrounding quotes
- Add `tests/validate-config.ps1` to help validate `launcher.ini` values on Windows
- Expand `readme.md` with usage, configuration and testing doc
- Add logging capability (file, append/overwrite, levels) with `logenabled`, `logfile`, `logappend`, `loglevel`
- Add execution styles (`execstyle`) — ShellExecute, Run, RunWait, Cmd
- Add autodiscovery feature (disabled by default) and `autodiscover_sources`, `autodiscover_persist`
- Add scripts for lint/format/test/build under `scripts/`
- Move: source file moved to `src/` and assets moved to `assets/` (updated paths and scripts accordingly)
- Add: tests for config cases (`tests/validate-config-cases.ps1`) and mark autodiscovery-test optional
- Add: GitHub Actions CI (`.github/workflows/ci.yml`) — lint, tests, build on Windows
- Replace: split CI into separate workflows (lint, format, test, build) and a follow-up autorelease workflow
- Add: Build produces UPX and non-UPX binaries, zip package and release attachments
- Add: Unit test harness (tests/unit/run-unit-tests.ps1) and CI-run unit tests in build workflow
- Add: Build produces checksums.txt (SHA256/SHA512) for artifacts and release attaches checksums
-- Add: Release workflow performs checksum verification and attaches verification summaries to releases
