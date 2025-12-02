# reader-launcher

A tiny, focused Adobe Reader launcher written in AutoIt. The launcher reads a small config file and starts the configured Acrobat/Reader executable with an optional randomized sleep delay and passthrough arguments.

This project is intentionally small — it helps automate launching Reader in circumstances where you want a short delay and optional debug options.

## Features

- Configurable delay before launching (fixed or randomized range)
- Configurable executable path (Acrobat Reader, SumatraPDF, etc.)
- Debugging switches to skip sleep and/or skip executing the app

## Usage

1. Configure `launcher.ini` in the same directory as the executable/script.
2. Run `reader_launcher.au3` (or the compiled `reader_launcher.exe`) and pass file(s) or other parameters as usual; parameters are forwarded to the target executable.

Example:

```
reader_launcher.exe "C:\path\to\some.pdf"
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

## Development / Building

- The AutoIt script is `reader_launcher.au3`. You can compile it using AutoIt3Wrapper (usually available from SciTE or the AutoIt tools).
- Make sure `launcher.ini` is present beside the compiled exe when testing.

## Diagnostic / Tests

A small PowerShell validator is included in `tests/validate-config.ps1` to check the presence of configuration keys and validate the `execpath` value. See `tests/README.md` for how to run it.

## License

This repository is distributed under the terms described in `license.md`.
