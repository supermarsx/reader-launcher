<#
  build.ps1
  Build (compile) the AutoIt script to an exe using Aut2Exe if available.
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "..\src\reader_launcher.au3" | Resolve-Path -ErrorAction Stop
$outDir = Join-Path $here "..\dist"
If (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$out = Join-Path $outDir "reader_launcher.exe"

$aut2exe = Get-Command Aut2Exe -ErrorAction SilentlyContinue
If (-not $aut2exe) {
    $possible = "C:\\Program Files (x86)\\AutoIt3\\Aut2Exe\\Aut2Exe.exe"
    If (Test-Path $possible) { $aut2exe = $possible }
}

If (-not $aut2exe) {
    Write-Warning "Aut2Exe (AutoIt compiler) not found. Can't build. Install AutoIt or use AutoIt3Wrapper in SciTE."
    Exit 2
}

Write-Host "Compiling $src -> $out"
& $aut2exe.Path /in $src /out $out
Exit $LASTEXITCODE
