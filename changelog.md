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
