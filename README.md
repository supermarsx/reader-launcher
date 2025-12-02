# reader-launcher

A tiny, focused Adobe Reader launcher written in AutoIt. The launcher reads a small config file and starts the configured Acrobat/Reader executable with an optional randomized sleep delay and passthrough arguments.

Project layout: source code now lives in `src/` and application assets (icons/images) live in `assets/`.

If there is no `launcher.ini` present, the launcher will use built-in defaults and automatically enable autodiscovery to try and find a suitable PDF viewer. Create `launcher.ini` by copying `launcher.example.ini` and editing values for your machine when you want persistent configuration.

This project is intentionally small — it helps automate launching Reader in circumstances where you want a short delay and optional debug options.

## Features

- Configurable delay before launching (fixed or randomized range)
- Configurable executable path (Acrobat Reader, SumatraPDF, etc.)
- Debugging switches to skip sleep and/or skip executing the app
- Logging to file with levels (error/warn/info/debug)
- Multiple execution styles (ShellExecute — default, Run, RunWait, Cmd)
- Autodiscovery for target executable (registry and Program Files lookup) with optional persistence back to configuration

## Usage

1. Configure `launcher.ini` in the same directory as the executable/script. A fully-documented example `launcher.example.ini` is included in the repository — copy it to `launcher.ini` and edit values for your machine.
2. Run `reader_launcher.au3` (or the compiled `reader_launcher.exe`) and pass file(s) or other parameters as usual; parameters are forwarded to the target executable.

Example:

```powershell
reader_launcher.exe "C:\path\to\some.pdf"
```

You can use extra command-line options to override config settings for the current run. Examples:

```powershell
reader_launcher.exe /autodiscover=1 /autodiscover_persist=1 /logenabled=1 /logfile="C:\temp\launcher.log" /execstyle=Run "C:\path\to\doc.pdf"

reader_launcher.exe /debug=1 /debugnosleep=1 "C:\file.pdf"
```

## Configuration (launcher.ini)

The value file `launcher.ini` contains the [general] section with the following keys (all optional — sensible defaults are used when omitted):

- `sleep` — Fixed sleep time in milliseconds before launching. Default: `1000`.
- `sleeprand` — When `1` (true), a random sleep between `sleepmin` and `sleepmax` will be used instead of `sleep`. Default: `0`.
- `sleepmin` — Minimum random sleep (ms). Default: `950`.
- `sleepmax` — Maximum random sleep (ms). Default: `1950`.
- `debug` — When `1`, debug message boxes are shown during the run. Default: `0`.
- `debugnosleep` — When `1`, the script will skip sleeping (useful for testing). Default: `0`.
- `debugnoexec` — When `1`, the script will skip actually starting the executable (useful for dry-runs). Default: `0`.
- `execpath` — The full path of the executable to launch. If missing, the launcher will try to use `C:\` and will warn or refuse to launch if the path doesn't exist.
- `execstyle` — How the target should be launched; supported values: `ShellExecute` (default), `Run`, `RunWait`, `Cmd`.
- `logenabled` — When `1`, writes runtime logs to `logfile`. Default: `0`.
- `logfile` — Path to the log file (if enabled). Default: `./logs/reader-launcher.log`.
- `logappend` — When `1` append to existing logfile; when `0` overwrite. Default: `1`.
- `loglevel` — 0=none,1=error,2=warn,3=info,4=debug. Default: `3`.
- `autodiscover` — Enable automatic discovery of a candidate executable through registry and common folders. Default: `0`.
- `autodiscover_sources` — Comma-separated discovery sources (e.g. `registry,programfiles`). Default: `registry,programfiles`.
- `autodiscover_persist` — When `1`, persist discovered path back into `launcher.ini`. Default: `0`.

Sample `launcher.ini`:

```ini
[general]
sleep=500
sleeprand=0
sleepmin=950
sleepmax=1950
debug=0
debugnosleep=0
debugnoexec=0
execpath=C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe
```

Note: The launcher accepts both `sleeprand` and historic key `sleeprandom` in case older versions of the file are present — both are supported.

### ⚠️ Note about compiled AutoIt binaries and anti-virus false positives

AutoIt binaries (and other small compiled utilities) can sometimes be flagged as false positives by anti-malware scanners because of the way AutoIt compiles scripts. This project is small and safe — if you create a compiled executable and your AV flags it, consider uploading the binary to a trusted scanner (VirusTotal) and/or adding an exception in your environment. When publishing releases we include both UPX-compressed and non-UPX binaries to make it easier to compare and reduce false positives (some scanners are more triggered by UPX-packed exes).

## Scripts (lint / format / test / build)

The `scripts/` folder contains helper scripts for common development tasks (PowerShell). They are small, self-checking helpers that run on Windows / PowerShell:

- `scripts/lint.ps1` — run au3check (if installed) against `reader_launcher.au3`.
- `scripts/format.ps1` — runs an AutoIt formatter (if present) or prints guidance.
- `scripts/test.ps1` — runs tests under `tests/` (`validate-config.ps1`, `autodiscovery-test.ps1`).
- `scripts/build.ps1` — attempt to compile `reader_launcher.au3` into `dist\reader_launcher.exe` using Aut2Exe if installed.

Example quick checks (PowerShell):

```powershell
pwsh -ExecutionPolicy Bypass -File scripts\lint.ps1
pwsh -ExecutionPolicy Bypass -File scripts\test.ps1
pwsh -ExecutionPolicy Bypass -File scripts\build.ps1
```

## Development / Building

- The AutoIt script is `reader_launcher.au3`. You can compile it using AutoIt3Wrapper (usually available from SciTE or the AutoIt tools).
- Make sure `launcher.ini` is present beside the compiled exe when testing.

### CI & contribution

This repository includes a simple GitHub Actions workflow that runs on
Windows runners and performs the following steps:

- lint the source (when au3check is available)
- run formatter if present (au3fix)
- run the PowerShell tests (config validator and config-cases)
- install AutoIt via Chocolatey and attempt a build (Aut2Exe)

The workflow lives at `.github/workflows/ci.yml`.

## Diagnostic / Tests

A small PowerShell validator is included in `tests/validate-config.ps1` to check the presence of configuration keys and validate the `execpath` value. See `tests/README.md` for how to run it.

## License

This repository is distributed under the terms described in `license.md`.
