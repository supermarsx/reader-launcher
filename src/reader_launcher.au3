#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\assets\adobe_reader_logo.ico
#AutoIt3Wrapper_Outfile=reader_launcher.exe
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#Region
#EndRegion
#cs ----------------------------------------------------------------------------
 AutoIt Version: 3.3.14.3
 Author:         Mariana

 Script Function:
     A tiny, robust launcher written in AutoIt that starts a configured PDF
     viewer or other application. The launcher reads configuration from
     `../launcher.ini` (beside the compiled executable or while running
     from `src/` during development). Key features:

     - Config-driven sleep delay (fixed or randomized range) before launching
     - Optional debug flags to disable sleep or execution for testing
     - Logging to a file with configurable level and append/overwrite behavior
     - Multiple execution styles: ShellExecute (default), Run, RunWait, Cmd
     - Optional autodiscovery (disabled by default) that scans registry and
        common folders for likely PDF readers; can optionally persist discovered
        path back into `launcher.ini`.

     The launcher is designed to be small and cross-machine friendly. It
     provides reasonable defaults and is defensive in its parsing of INI keys.

 Running / overrides
     You can pass simple overrides on the command line, such as:

     /debug=1 /debugnosleep=1 /autodiscover=1 /autodiscover_persist=1

     Any unknown arguments are passed through to the target executable.

#ce ----------------------------------------------------------------------------

; Global Configurations
Global $cfg_filename = @ScriptDir & "\..\launcher.ini", _
	$cfg_section1 = "general"

; -------------------------------
; Configuration loading & normalization
; Read values from launcher.ini (section [general]). We are defensive:
; - Support both current and legacy keys (sleeprand / sleeprandom)
; - Provide sensible defaults when keys are missing
; - Normalize/convert numeric values using Int() and strip surrounding quotes
; - Keep exec path, logfile path relative to script directory where helpful
; -------------------------------
; Read values from INI — be defensive: support both "sleeprand" and historical "sleeprandom".
Local $raw_sleep = IniRead($cfg_filename, $cfg_section1, "sleep", 1000)
Local $raw_sleeprand = IniRead($cfg_filename, $cfg_section1, "sleeprand", "")
If $raw_sleeprand = "" Then $raw_sleeprand = IniRead($cfg_filename, $cfg_section1, "sleeprandom", 0)
Local $raw_sleepmin = IniRead($cfg_filename, $cfg_section1, "sleepmin", 950)
Local $raw_sleepmax = IniRead($cfg_filename, $cfg_section1, "sleepmax", 1950)
Local $raw_debug = IniRead($cfg_filename, $cfg_section1, "debug", 0)
Local $raw_debugnosleep = IniRead($cfg_filename, $cfg_section1, "debugnosleep", 0)
Local $raw_debugnoexec = IniRead($cfg_filename, $cfg_section1, "debugnoexec", 0)
Local $raw_execpath = IniRead($cfg_filename, $cfg_section1, "execpath", "C:\")
; New config keys: logging, execstyle and autodiscovery
Local $raw_logenabled = IniRead($cfg_filename, $cfg_section1, "logenabled", 0)
Local $raw_logfile = IniRead($cfg_filename, $cfg_section1, "logfile", @ScriptDir & "\\..\\logs\\reader-launcher.log")
Local $raw_logappend = IniRead($cfg_filename, $cfg_section1, "logappend", 1)
Local $raw_loglevel = IniRead($cfg_filename, $cfg_section1, "loglevel", 3) ; 0=none,1=error,2=warn,3=info,4=debug

; Execution style: ShellExecute (default), Run, RunWait, Cmd
Local $raw_execstyle = IniRead($cfg_filename, $cfg_section1, "execstyle", "ShellExecute")

; autodiscovery (off by default) and persistence
Local $raw_autodiscover = IniRead($cfg_filename, $cfg_section1, "autodiscover", 0)
Local $raw_autodiscover_sources = IniRead($cfg_filename, $cfg_section1, "autodiscover_sources", "registry,programfiles")
Local $raw_autodiscover_persist = IniRead($cfg_filename, $cfg_section1, "autodiscover_persist", 0)

; Normalize / coerce to numeric where required — use Int() to convert string
; values from INI to integers and protect our runtime logic.
Local $cfg_sleep = Int($raw_sleep)
Local $cfg_sleeprand = Int($raw_sleeprand)
Local $cfg_sleepmin = Int($raw_sleepmin)
Local $cfg_sleepmax = Int($raw_sleepmax)
Local $cfg_debug = Int($raw_debug)
Local $cfg_debugnosleep = Int($raw_debugnosleep)
Local $cfg_debugnoexec = Int($raw_debugnoexec)

; Trim possible wrapping quotes from execpath and any surrounding whitespace
; (INI values sometimes include quotes; this makes it resilient)
Local $cfg_execpath = StringStripWS(StringReplace($raw_execpath, '"', ''), 3)
Local $cfg_logenabled = Int($raw_logenabled)
Local $cfg_logfile = StringStripWS(StringReplace($raw_logfile, '"', ''), 3)
Local $cfg_logappend = Int($raw_logappend)
Local $cfg_loglevel = Int($raw_loglevel)

Local $cfg_execstyle = StringLower(StringStripWS($raw_execstyle, 3))

Local $cfg_autodiscover = Int($raw_autodiscover)
Local $cfg_autodiscover_sources = StringSplit(StringStripWS($raw_autodiscover_sources, 3), ",", 2)
Local $cfg_autodiscover_persist = Int($raw_autodiscover_persist)

; Ensure sensible sleep range — avoid negative or inverted limits
If $cfg_sleepmin < 0 Then $cfg_sleepmin = 0
If $cfg_sleepmax < $cfg_sleepmin Then $cfg_sleepmax = $cfg_sleepmin + 1000

; Determine the actual sleep time to use (randomized range or fixed)
Local $ex_sleep = $cfg_sleeprand > 0 ? Random($cfg_sleepmin, $cfg_sleepmax, 1) : $cfg_sleep

; Debug info (pop-up when debug=1 and also forwarded to log when enabled)
Local $dbg_message = "Sleep time: " & $ex_sleep & " ms" & @CRLF & "Randomize sleep: " & $cfg_sleeprand
debug($dbg_message)

; Apply the configured sleep delay unless the debug flag requests skipping it
If ($cfg_debugnosleep = 0) Then Sleep($ex_sleep)

; Build the command-line parameter string to forward to the target executable
; (we remove the script name itself so only user-supplied params remain)
Local $ex_parameters = StringStripWS(StringReplace($CmdLineRaw, @ScriptName, ""), 7)
debug("Launcher parameters: " & $ex_parameters)

debug("Executable path: " & $cfg_execpath)

; Parse command-line overrides like /debug=1, /autodiscover=1, /execstyle=Run
; This lets callers temporarily override INI settings for one run without
; changing the file on disk.
ParseCmdLineArgs()

; Initialize logging: create parent dir (if required) and write an initial
; log entry. Logging is off by default and must be enabled explicitly.
If $cfg_logenabled = 1 Then
    _EnsureLogDirExists($cfg_logfile)
    Log("info", "Log initialized, level=" & $cfg_loglevel & " file=" & $cfg_logfile)
EndIf

; Autodiscovery: if enabled, loop through configured sources and attempt to
; locate a candidate executable. If found we use it for this run, and if the
; persist flag is set we write it back into the INI so future runs use it.
; Autodiscovery is intentionally off by default — set autodiscover=1 to
; experiment.
; NOTE: autodiscovery may return nothing on minimal build machines (no Reader)
; which is expected — the behavior is conservative and informative.
; Autodiscover (if enabled)
If $cfg_autodiscover = 1 Then
    Local $found = AutoDiscoverExecPath($cfg_autodiscover_sources)
    If StringLen($found) Then
        Log("info", "Auto-discovered exec path: " & $found)
        If $cfg_autodiscover_persist = 1 Then
            IniWrite($cfg_filename, $cfg_section1, "execpath", $found)
            Log("info", "Persisted discovered path to INI: " & $found)
            $cfg_execpath = $found
        Else
            $cfg_execpath = $found
        EndIf
    Else
        Log("warn", "Autodiscover enabled but no candidate found")
    EndIf
EndIf

; Verify executable exists before attempting to execute unless debugnoexec set
If ($cfg_debugnoexec = 0) Then
    If StringLen($cfg_execpath) = 0 Then
        Log("error", "No executable path configured in " & $cfg_filename)
        MsgBox(16, "Launcher error", "No executable path configured in " & $cfg_filename)
        Exit 1
    EndIf

    If Not FileExists($cfg_execpath) Then
        Log("warn", "Configured execpath does not point to an existing file: " & $cfg_execpath)
        MsgBox(48, "Launcher warning", "Configured execpath does not point to an existing file:" & @CRLF & $cfg_execpath)
        ; still proceed to attempt execution — ShellExecute / Run may still attempt
    EndIf

    ; Invoke the configured execution style (ShellExecute default)
    Local $rc = ExecLaunch($cfg_execpath, $ex_parameters, $cfg_execstyle)
    Log("info", "Executed with style=" & $cfg_execstyle & " rc=" & $rc)
EndIf

Exit

; Displays a Debug message (pop-up when debug=1)
Func debug($message)
    ; existing pop-up style debug for compatibility
    If ($cfg_debug = 1) Then MsgBox(0, "Debug Message", $message)
    ; also write debug messages to log if enabled and loglevel >= debug
    Log("debug", $message)
EndFunc

; ---------------- helper utilities ----------------
; _EnsureLogDirExists(path) — ensure the folder for the given file path exists.
; Extracts the directory component and creates it if it does not exist.
Func _EnsureLogDirExists($path)
    Local $dir = StringTrimRight($path, StringInStr($path, '\\', 0, -1) - 1)
    If Not FileExists($dir) Then DirCreate($dir)
EndFunc

; Log(level, message) — write timestamped messages to the log file.
; The function respects cfg_logenabled and cfg_loglevel and honors append/overwrite.
Func Log($level, $message)
    If $cfg_logenabled <> 1 Then Return
    Local $map = MapLevel($level)
    If $map > $cfg_loglevel Then Return
    Local $time = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $line = $time & " [" & $level & "] " & $message & @CRLF
    ; Choose file mode: 1 = append, 2 = overwrite
    Local $mode = ($cfg_logappend = 1) ? 1 : 2
    Local $h = FileOpen($cfg_logfile, $mode)
    If $h = -1 Then Return
    FileWrite($h, $line)
    FileClose($h)
EndFunc

; MapLevel(name) — convert a string level into an integer priority
; Lower numbers map to more severe events (error=1..debug=4)
Func MapLevel($name)
    Select
        Case StringLower($name) = "error"
            Return 1
        Case StringLower($name) = "warn" Or StringLower($name) = "warning"
            Return 2
        Case StringLower($name) = "info"
            Return 3
        Case StringLower($name) = "debug"
            Return 4
        Case Else
            Return 0
    EndSelect
EndFunc

; ExecLaunch — run executables in various styles
; Returns the PID for Run/RunWait or 0 for ShellExecute (successful) and
; passes through RunWait return code when using runwait.
Func ExecLaunch($path, $params, $style)
    Local $full = '"' & $path & '"'
    If StringLen($params) Then $full &= ' ' & $params
    Select
        Case $style = "shellexecute" Or $style = "shell"
            ShellExecute($path, $params)
            Return 0
        Case $style = "run"
            Local $pid = Run($full, "", @SW_SHOW)
            Return $pid
        Case $style = "runwait"
            Local $rc = RunWait($full, "", @SW_SHOW)
            Return $rc
        Case $style = "cmd" Or $style = "cmdline"
            ; Start via cmd /c so parameters are handled consistently
            Local $cmd = 'cmd /c start "" "' & $path & '" ' & $params
            Local $pid2 = Run($cmd, "", @SW_HIDE)
            Return $pid2
        Case Else
            ; fallback to ShellExecute
            ShellExecute($path, $params)
            Return 0
    EndSelect
EndFunc

; Parse command-line overrides (very simple parser)
; Supported forms include: --key=value, /key:value, key=value or /key
Func ParseCmdLineArgs()
    If $CmdLineCount = 0 Then Return
    For $i = 0 To $CmdLineCount - 1
        Local $arg = $CmdLine[$i]
        Local $lower = StringLower($arg)
        ; support key=value or /key:value or --key=value
        Local $name = "", $val = ""
        If StringInStr($arg, "=") Then
            $name = StringLeft($arg, StringInStr($arg, "=") - 1)
            $val = StringMid($arg, StringInStr($arg, "=") + 1)
        ElseIf StringInStr($arg, ":") Then
            $name = StringLeft($arg, StringInStr($arg, ":") - 1)
            $val = StringMid($arg, StringInStr($arg, ":") + 1)
        Else
            $name = $arg
            $val = "1"
        EndIf

        $name = StringStripWS(StringReplace(StringLower($name), "--", ""), 3)
        $name = StringReplace($name, "/", "")

        Switch $name
            Case "debug"
                $cfg_debug = Int($val)
            Case "debugnosleep"
                $cfg_debugnosleep = Int($val)
            Case "debugnoexec"
                $cfg_debugnoexec = Int($val)
            Case "logenabled"
                $cfg_logenabled = Int($val)
            Case "logfile"
                $cfg_logfile = StringStripWS(StringReplace($val, '"', ''), 3)
            Case "logappend"
                $cfg_logappend = Int($val)
            Case "loglevel"
                $cfg_loglevel = Int($val)
            Case "execstyle"
                $cfg_execstyle = StringLower($val)
            Case "autodiscover"
                $cfg_autodiscover = Int($val)
            Case "autodiscover_persist", "autodiscoverpersist"
                $cfg_autodiscover_persist = Int($val)
            Case Else
                ; unknown param — leave as file argument
        EndSwitch
    Next
EndFunc

; Auto-discovery helper — check registry and common Program Files locations
Func AutoDiscoverExecPath(ByRef $sources)
    ; sources is an array from StringSplit earlier
    For $s = 1 To $sources[0]
        Local $src = StringLower(StringStripWS($sources[$s], 3))
        Switch $src
            Case "registry"
                ; check App Paths for AcroRd32.exe
                Local $keys[2] = [
                    "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe", _
                    "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe"
                ]
                For $k = 0 To UBound($keys) - 1
                    Local $r = ""
                    OnErrorResumeNext
                    $r = RegRead($keys[$k], "")
                    If @error = 0 And StringLen($r) Then
                        If FileExists($r) Then Return $r
                    EndIf
                    OnErrorGoTo0
                Next
            Case "programfiles", "programfilesx86", "programfilesx64"
                ; check common locations — order: Program Files (x86) and Program Files
                Local $candidates[6] = [ _
                    @ProgramFilesDir & "\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe", _
                    @ProgramFilesDir & "\Adobe\Acrobat\Acrobat.exe", _
                    @ProgramFilesDir & "\SumatraPDF\SumatraPDF.exe", _
                    @ProgramFilesDir & "(x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe", _
                    @ProgramFilesDir & "(x86)\Adobe\Acrobat\Acrobat.exe", _
                    @ProgramFilesDir & "(x86)\SumatraPDF\SumatraPDF.exe" _
                ]
                For $c = 0 To UBound($candidates) - 1
                    Local $path = $candidates[$c]
                    ; attempt to normalize odd strings like (x86) — perform two common expands
                    $path = StringReplace($path, "(x86)", "Program Files (x86)")
                    If FileExists($path) Then Return $path
                Next
            Case "cwd", "currentdir"
                ; check the same dir as the script
                Local $cand = @ScriptDir & "\AcroRd32.exe"
                If FileExists($cand) Then Return $cand
            Case Else
                ; unknown source
        EndSwitch
    Next
    Return ""
EndFunc
