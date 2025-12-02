<#
  validate-config.ps1
  Simple validator for launcher.ini — checks that numeric values parse and that execpath looks reasonable.
#>

param(
    [string]$IniPath
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($IniPath) {
    $iniFile = Resolve-Path -Path $IniPath -ErrorAction SilentlyContinue
}
else {
    # Prefer a real runtime config (launcher.ini) when present; otherwise validate the example file we distribute.
    $iniReal = Join-Path $here "..\launcher.ini"
    if (Test-Path $iniReal) {
        $iniFile = Resolve-Path -Path $iniReal -ErrorAction SilentlyContinue
    }
    else {
        $iniFile = Join-Path $here "..\launcher.example.ini" | Resolve-Path -ErrorAction SilentlyContinue
    }
}

if (-not $iniFile) {
    Write-Error "launcher.ini not found in repository root."
    exit 2
}

$content = Get-Content $iniFile

# find [general] block
$start = $content | Select-String -Pattern '^\[general\]' | Select-Object -First 1
if (-not $start) {
    Write-Error "[general] section not found in $iniFile"
    exit 2
}

$idx = ($content | ForEach-Object { $_ }) -as [array]
$i0 = ($idx | Select-String -Pattern '^\[general\]').LineNumber - 1

# collect lines until next section or EOF (start from the following line after [general])
$values = @{}
for ($j = $i0 + 1; $j -lt $idx.Count; $j++) {
    $line = $idx[$j].Trim()
    if ($line -match '^\[') { break }
    if ($line -eq '' -or $line.StartsWith('#')) { continue }
    if ($line -match '^(?<k>[^=]+)=(?<v>.*)$') {
        $k = $matches['k'].Trim()
        $v = $matches['v'].Trim()
        $values[$k] = $v
    }
}

$errors = @()

function assertNumber($name) {
    if (-not $values.ContainsKey($name)) { $script:errors += "Missing key: $name"; return }
    $v = $values[$name]
    # accept integer numbers (positive/negative) — reject anything else
    if (-not ($v -match '^[+-]?\d+$')) { $script:errors += "Value for $name is not a number: $($values[$name])" }
}

assertNumber 'sleep'
if ($values.ContainsKey('sleeprand') -eq $false -and $values.ContainsKey('sleeprandom') -eq $false) {
    $errors += 'Missing sleeprand or sleeprandom key'
}
assertNumber 'sleepmin'
assertNumber 'sleepmax'
assertNumber 'debug'
assertNumber 'debugnosleep'
assertNumber 'debugnoexec'

if ($values.ContainsKey('sleepmin') -and $values.ContainsKey('sleepmax')) {
    if ([int]$values['sleepmin'] -gt [int]$values['sleepmax']) {
        $errors += "sleepmin is greater than sleepmax"
    }
}

if ($values.ContainsKey('execpath')) {
    $path = $values['execpath'].Trim('"')
    if (-not (Test-Path $path)) {
        Write-Warning "execpath does not exist: $path — that might be OK if you use a different machine"
    }
    else {
        Write-Host "execpath exists: $path" -ForegroundColor Green
    }
}
else {
    $errors += 'Missing execpath'
}

# Additional configuration checks
# If logging is enabled we must have a logfile specified
if ($values.ContainsKey('logenabled')) {
    [int]$logEnabled = 0
    [int]::TryParse($values['logenabled'], [ref]$logEnabled) | Out-Null
    if ($logEnabled -ne 0) {
        if (-not $values.ContainsKey('logfile') -or [string]::IsNullOrWhiteSpace($values['logfile'])) {
            $errors += 'logfile is required when logenabled is non-zero'
        }
    }
}

# execstyle validation
if ($values.ContainsKey('execstyle')) {
    $valid = @('shellexecute', 'shell', 'run', 'runwait', 'cmd', 'cmdline')
    if (-not ($valid -contains ($values['execstyle'].ToLower())) ) {
        $errors += "Unknown execstyle: $($values['execstyle'])"
    }
}

# autodiscovery values validation
if ($values.ContainsKey('autodiscover')) { if (-not [int]::TryParse($values['autodiscover'], [ref]([int]$null))) { $errors += "autodiscover must be numeric (0 or 1)" } }
if ($values.ContainsKey('autodiscover_sources')) {
    $pieces = ($values['autodiscover_sources'] -split ',') | ForEach-Object { $_.Trim().ToLower() }
    $allowed = @('registry', 'programfiles', 'cwd', 'currentdir')
    foreach ($p in $pieces) { if ($p -and -not ($allowed -contains $p)) { $errors += "Unknown autodiscover source: $p" } }
}

if ($errors.Count -gt 0) {
    Write-Error "Configuration validation failed:`n`n$($errors -join "`n")"
    exit 1
}
else {
    Write-Host "Validation passed." -ForegroundColor Green
    exit 0
}
