#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\assets\adobe_reader_logo.ico
#AutoIt3Wrapper_Outfile=reader_launcher.exe
#AutoIt3Wrapper_UseUpx=y
# Ensure compiled binary emits console output when wrapped by AutoIt3Wrapper
#AutoIt3Wrapper_UseConsole=1
# Application metadata (embedded into compiled binary via AutoIt3Wrapper)
# AutoIt3Wrapper resource directives
# NOTE: update these when bumping the release version
#AutoIt3Wrapper_Res_Fileversion=0.25.1.0
#AutoIt3Wrapper_Res_ProductVersion=0.25.1.0
#AutoIt3Wrapper_Res_ProductName=reader-launcher
#AutoIt3Wrapper_Res_FileDescription=A small robust launcher for PDF viewers
#AutoIt3Wrapper_Res_Company=supermarsx
#AutoIt3Wrapper_Res_InternalName=reader_launcher.exe
#AutoIt3Wrapper_Res_OriginalFilename=reader_launcher.exe
#AutoIt3Wrapper_Res_LegalCopyright=Copyright (c) 2025 supermarsx
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
; Application metadata (also visible via CLI)
Global Const $APP_NAME = "reader-launcher"
Global Const $APP_VERSION = "0.25.1"

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
; Read values from INI ? be defensive: support both "sleeprand" and historical "sleeprandom".
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
; Extra params and presets
Local $raw_extra_params = IniRead($cfg_filename, $cfg_section1, "extra_params", "")
Local $raw_preset = IniRead($cfg_filename, $cfg_section1, "preset", "")
; Console mode preference in ini (0/1) ? when set, the launcher behaves as console
Local $raw_console = IniRead($cfg_filename, $cfg_section1, "console", 0)
Local $cfg_console = Int($raw_console)

; Normalize / coerce to numeric where required ? use Int() to convert string
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
Local $cfg_extra_params = StringStripWS(StringReplace($raw_extra_params, '"', ''), 7)
Local $cfg_preset = StringStripWS($raw_preset, 3)

; Ensure sensible sleep range ? avoid negative or inverted limits
If $cfg_sleepmin < 0 Then $cfg_sleepmin = 0
If $cfg_sleepmax < $cfg_sleepmin Then $cfg_sleepmax = $cfg_sleepmin + 1000

; Determine the actual sleep time to use (randomized range or fixed)
Local $ex_sleep = $cfg_sleeprand > 0 ? Random($cfg_sleepmin, $cfg_sleepmax, 1) : $cfg_sleep

; If no config file exists, enable autodiscovery by default and use defaults.
If Not FileExists($cfg_filename) Then
	; prefer autodiscover when there is no user-configured launcher.ini
	$cfg_autodiscover = 1
	_WriteLog("info", "Config file not found at " & $cfg_filename & "; enabling autodiscovery and using defaults.")
EndIf

; Debug info (pop-up when debug=1 and also forwarded to log when enabled)
Local $dbg_message = "Sleep time: " & $ex_sleep & " ms" & @CRLF & "Randomize sleep: " & $cfg_sleeprand
debug($dbg_message)

; Apply the configured sleep delay unless the debug flag requests skipping it
; Small console detection: prefer console output when a console window is present,
; otherwise fall back to GUI message boxes for help/version to support GUI usage.
Local $g_hasConsole = False
Local $dllRet = DllCall("kernel32.dll", "ptr", "GetConsoleWindow")
If @error = 0 And IsArray($dllRet) And $dllRet[0] <> 0 Then $g_hasConsole = True
; If the INI requests console mode, honor it (overrides absence of console window)
If $cfg_console = 1 Then
	$g_hasConsole = True
	_AttachConsoleToParent()
EndIf

; run early CLI checks for --help / --version before potentially sleeping
_CheckForHelpAndVersion()
If ($cfg_debugnosleep = 0) Then Sleep($ex_sleep)

; -------------------------
; CLI helpers: --help / -h / /? and --version / -v
; If these flags are present in the command-line, print a short usage
; message or version and exit immediately. This makes the compiled EXE
; behave like a CLI utility when invoked from scripts.
; -------------------------
Func _CheckForHelpAndVersion()
	If $CmdLine[0] = 0 Then Return
	For $i = 0 To $CmdLine[0] - 1
		Local $a = StringLower(StringStripWS($CmdLine[$i], 3))
		; support forcing console mode via --console or -c
		If $a = "--console" Or $a = "-c" Then
			$g_hasConsole = True
			_AttachConsoleToParent()
			ContinueLoop
		EndIf
		If $a = "--help" Or $a = "-h" Or $a = "/?" Or $a = "/help" Or $a = "/h" Then
			_ShowUsage()
			Exit 0
		ElseIf $a = "--version" Or $a = "-v" Or $a = "/version" Or $a = "/v" Then
			_ShowVersion()
			Exit 0
		EndIf
	Next
EndFunc   ;==>_CheckForHelpAndVersion

Func _ShowUsage()
	If $g_hasConsole Then
		; ensure we have a console attached so ConsoleWrite actually writes to stdout
		_AttachConsoleToParent()
		ConsoleWrite($APP_NAME & " " & $APP_VERSION & @CRLF)
		ConsoleWrite("Usage: " & $APP_NAME & " [options] [file(s)]" & @CRLF)
		ConsoleWrite(@CRLF)
		ConsoleWrite("Options:" & @CRLF)
		ConsoleWrite("  --help, -h, /? /h       Show this help and exit" & @CRLF)
		ConsoleWrite("  --version, -v /v /version Print version information and exit" & @CRLF)
		ConsoleWrite("  /debug=1                Enable debug (message boxes)" & @CRLF)
		ConsoleWrite("  /debugnosleep=1         Skip sleep (for testing)" & @CRLF)
		ConsoleWrite("  /debugnoexec=1          Skip executing the target (dry-run)" & @CRLF)
	Else
		MsgBox(0, $APP_NAME & ' ' & $APP_VERSION, 'Usage: ' & $APP_NAME & ' [options] [file(s)]' & @CRLF & @CRLF & 'Options:' & @CRLF & '/? or --help or /h - Show this help' & @CRLF & '--version or -v or /v - Print version')
	EndIf
EndFunc   ;==>_ShowUsage

Func _ShowVersion()
	If $g_hasConsole Then
		; ensure we have a console attached so ConsoleWrite actually writes to stdout
		_AttachConsoleToParent()
		ConsoleWrite($APP_NAME & " " & $APP_VERSION & @CRLF)
	Else
		MsgBox(0, $APP_NAME & ' ' & $APP_VERSION, 'Version: ' & $APP_VERSION)
	EndIf
EndFunc   ;==>_ShowVersion

; (help/version checks executed earlier before sleep)

; Build the command-line parameter string to forward to the target executable
; (we remove the script name itself so only user-supplied params remain)
Local $ex_parameters = StringStripWS(StringReplace($CmdLineRaw, @ScriptName, ""), 7)
; If the user requested a preset, look up default preset parameters.
Local $presetParams = GetPresetParams($cfg_preset)

; Build final parameters: presets + extra_params + original passed-in params.
Local $final_parameters = StringStripWS($presetParams & " " & $cfg_extra_params & " " & $ex_parameters, 7)
debug("Launcher parameters: " & $final_parameters)

debug("Executable path: " & $cfg_execpath)

; Parse command-line overrides like /debug=1, /autodiscover=1, /execstyle=Run
; This lets callers temporarily override INI settings for one run without
; changing the file on disk.
ParseCmdLineArgs()

; Initialize logging: create parent dir (if required) and write an initial
; log entry. Logging is off by default and must be enabled explicitly.
If $cfg_logenabled = 1 Then
	_EnsureLogDirExists($cfg_logfile)
	_WriteLog("info", "Log initialized, level=" & $cfg_loglevel & " file=" & $cfg_logfile)
EndIf

; Autodiscovery: if enabled, loop through configured sources and attempt to
; locate a candidate executable. If found we use it for this run, and if the
; persist flag is set we write it back into the INI so future runs use it.
; Autodiscovery is intentionally off by default ? set autodiscover=1 to
; experiment.
; NOTE: autodiscovery may return nothing on minimal build machines (no Reader)
; which is expected ? the behavior is conservative and informative.
; Autodiscover (if enabled)
If $cfg_autodiscover = 1 Then
	Local $found = AutoDiscoverExecPath($cfg_autodiscover_sources)
	If StringLen($found) Then
		_WriteLog("info", "Auto-discovered exec path: " & $found)
		If $cfg_autodiscover_persist = 1 Then
			IniWrite($cfg_filename, $cfg_section1, "execpath", $found)
			_WriteLog("info", "Persisted discovered path to INI: " & $found)
			$cfg_execpath = $found
		Else
			$cfg_execpath = $found
		EndIf
	Else
		_WriteLog("warn", "Autodiscover enabled but no candidate found")
	EndIf
EndIf

; If a preset has not been chosen explicitly, try to pick a sensible default
; based on the configured executable path. This helps automation where users
; don't provide a preset but expect common Reader behaviors (e.g., suppress splash)
If StringLen($cfg_preset) = 0 Then
	$cfg_preset = DetermineDefaultPreset($cfg_execpath)
	debug("Auto-selected preset: " & $cfg_preset)
EndIf

; Verify executable exists before attempting to execute unless debugnoexec set
If ($cfg_debugnoexec = 0) Then
	If StringLen($cfg_execpath) = 0 Then
		_WriteLog("error", "No executable path configured in " & $cfg_filename)
		MsgBox(16, "Launcher error", "No executable path configured in " & $cfg_filename)
		Exit 1
	EndIf

	If Not FileExists($cfg_execpath) Then
		_WriteLog("warn", "Configured execpath does not point to an existing file: " & $cfg_execpath)
		MsgBox(48, "Launcher warning", "Configured execpath does not point to an existing file:" & @CRLF & $cfg_execpath)
		; still proceed to attempt execution ? ShellExecute / Run may still attempt
	EndIf

	; Invoke the configured execution style (ShellExecute default)
	; Log files we are about to open (if any appear in the parameter list)
	Local $fileList = _ExtractFilesFromParams($final_parameters)
	If StringLen($fileList) Then
		Local $parts = StringSplit($fileList, @CRLF, 1)
		If IsArray($parts) Then
			For $i = 1 To $parts[0]
				_WriteLog("info", "Opening file: " & $parts[$i])
			Next
		EndIf
	ElseIf StringInStr($final_parameters, ':\\') Then
		; Fallback: if we see a drive-like token but failed to split, log the raw params as a single entry
		_WriteLog("info", "Opening file: " & $final_parameters)
	EndIf
	Local $rc = ExecLaunch($cfg_execpath, $final_parameters, $cfg_execstyle)
	_WriteLog("info", "Executed with style=" & $cfg_execstyle & " rc=" & $rc)
EndIf

Exit

; Displays a Debug message (pop-up when debug=1)
Func debug($message)
	; existing pop-up style debug for compatibility
	If ($cfg_debug = 1) Then MsgBox(0, "Debug Message", $message)
	; also write debug messages to log if enabled and loglevel >= debug
	_WriteLog("debug", $message)
EndFunc   ;==>debug

; Attach to parent console if possible, otherwise allocate a new console.
; Returns True when a console is available after this call.
Func _AttachConsoleToParent()
	; If already have a console window, nothing to do
	Local $dllRet = DllCall("kernel32.dll", "ptr", "GetConsoleWindow")
	If @error = 0 And IsArray($dllRet) And $dllRet[0] <> 0 Then Return True

	; Try to attach to parent process console (ATTACH_PARENT_PROCESS = -1)
	Local $attach = DllCall("kernel32.dll", "int", "AttachConsole", "int", -1)
	If @error = 0 And IsArray($attach) And $attach[0] <> 0 Then Return True

	; Fallback: allocate a new console (AllocConsole)
	Local $alloc = DllCall("kernel32.dll", "int", "AllocConsole")
	If @error = 0 And IsArray($alloc) And $alloc[0] <> 0 Then Return True

	Return False
EndFunc   ;==>_AttachConsoleToParent

; ---------------- helper utilities ----------------
; _EnsureLogDirExists(path) ? ensure the folder for the given file path exists.
; Extracts the directory component and creates it if it does not exist.
Func _EnsureLogDirExists($path)
	Local $dir = StringTrimRight($path, StringInStr($path, '\\', 0, -1) - 1)
	If Not FileExists($dir) Then DirCreate($dir)
EndFunc   ;==>_EnsureLogDirExists

; Log(level, message) ? write timestamped messages to the log file.
; The function respects cfg_logenabled and cfg_loglevel and honors append/overwrite.
; _WriteLog(level, message) ? write timestamped messages to the log file.
Func _WriteLog($level, $message)
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
EndFunc   ;==>_WriteLog

; Extract file-like tokens from a parameter string and return a comma-separated list.
; We look for quoted tokens or whitespace-separated tokens, ignore switches (start with / or -)
; and ignore key=value tokens. A token is considered a file if it looks like an absolute path
; (contains :\) or begins with a backslash, or ends with a filename-like extension.
Func _ExtractFilesFromParams($params)
	If StringLen($params) = 0 Then Return ""
	Local $pattern = '("[^"]+"|[^\s]+)'
	Local $tokens = StringRegExp($params, $pattern, 3)
	If Not IsArray($tokens) Then Return ""
	Local $found = ""
	For $i = 0 To UBound($tokens) - 1
		Local $tok = $tokens[$i]
		If StringLeft($tok, 1) = '"' And StringRight($tok, 1) = '"' Then $tok = StringMid($tok, 2, StringLen($tok) - 2)
		; skip options and key/value pairs
		If StringLeft($tok, 1) = '/' Or StringLeft($tok, 1) = '-' Then ContinueLoop
		If StringInStr($tok, '=') Then ContinueLoop
		; heuristics: drive-style path, UNC path, or ends with an extension like .pdf
		If StringInStr($tok, ':\\') Or StringLeft($tok, 1) = '\\' Or StringRegExp($tok, '\.[A-Za-z0-9]{1,6}$') Then
			If StringLen($found) Then $found &= @CRLF
			$found &= $tok
		EndIf
	Next
	Return $found
EndFunc   ;==>_ExtractFilesFromParams

; MapLevel(name) ? convert a string level into an integer priority
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
EndFunc   ;==>MapLevel

; ExecLaunch ? run executables in various styles
; Returns the PID for Run/RunWait or 0 for ShellExecute (successful) and
; passes through RunWait return code when using runwait.
Func ExecLaunch($path, $params, $style)
	; Safely quote/prepare the path and parameters for each execution style.
	; We avoid double-quoting when the caller already included quotes.
	Local $quotedPath = $path
	If StringLeft($quotedPath, 1) <> '"' Then $quotedPath = '"' & $quotedPath & '"'
	Local $full = $quotedPath
	If StringLen($params) Then
		; ensure a single leading space between path and params
		$full &= ' ' & $params
	EndIf
	Select
		Case $style = "shellexecute" Or $style = "shell"
			; ShellExecute expects raw path and params separately (no additional quoting required)
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
EndFunc   ;==>ExecLaunch

; Parse command-line overrides (very simple parser)
; Supported forms include: --key=value, /key:value, key=value or /key
Func ParseCmdLineArgs()
	If $CmdLine[0] = 0 Then Return
	For $i = 0 To $CmdLine[0] - 1
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
				; unknown param ? leave as file argument
		EndSwitch
	Next
EndFunc   ;==>ParseCmdLineArgs

; Auto-discovery helper ? check registry and common Program Files locations
Func AutoDiscoverExecPath(ByRef $sources)
	; sources is an array from StringSplit earlier
	For $s = 1 To $sources[0]
		Local $src = StringLower(StringStripWS($sources[$s], 3))
		Switch $src
			Case "registry"
				; check App Paths for AcroRd32.exe (explicit keys read below)
				; try known AppPaths keys
				Local $r = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe", "")
				If @error = 0 And StringLen($r) Then
					If FileExists($r) Then Return $r
				EndIf
				Local $r2 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe", "")
				If @error = 0 And StringLen($r2) Then
					If FileExists($r2) Then Return $r2
				EndIf
				; also check for Acrobat.exe AppPaths
				Local $r3 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Acrobat.exe", "")
				Local $r3 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Acrobat.exe", "")
				If @error = 0 And StringLen($r3) Then
					If FileExists($r3) Then Return $r3
				EndIf
				; Check App Paths for Nitro and Foxit variations as well
				Local $r5 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\NitroPDF.exe", "")
				If @error = 0 And StringLen($r5) Then
					If FileExists($r5) Then Return $r5
				EndIf
				Local $r6 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\FoxitReader.exe", "")
				If @error = 0 And StringLen($r6) Then
					If FileExists($r6) Then Return $r6
				EndIf
				Local $r7 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\FoxitPDFEditor.exe", "")
				If @error = 0 And StringLen($r7) Then
					If FileExists($r7) Then Return $r7
				EndIf
				Local $r4 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Paths\Acrobat.exe", "")
				If @error = 0 And StringLen($r4) Then
					If FileExists($r4) Then Return $r4
				EndIf
				; If installer keys exist for Acrobat DC (SCAPackageLevel) the product is installed; try common Acrobat DC path
				Local $inst1 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Adobe\Adobe Acrobat\DC\Installer", "SCAPackageLevel")
				Local $inst1 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Adobe\Adobe Acrobat\DC\Installer", "SCAPackageLevel")
				If @error = 0 And StringLen($inst1) Then
					Local $candidate = @ProgramFilesDir & "\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
					If FileExists($candidate) Then Return $candidate
				EndIf
				; Also check Nitro/Foxit installer registry keys (common installer locations)
				Local $nitroReg = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Nitro\Pro", "InstallDir")
				If @error = 0 And StringLen($nitroReg) Then
					Local $candn = $nitroReg & "\NitroPDF.exe"
					If FileExists($candn) Then Return $candn
				EndIf
				Local $foxitReg = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\FoxitSoftware\FoxitReader", "InstallPath")
				If @error = 0 And StringLen($foxitReg) Then
					Local $candf = $foxitReg & "\FoxitReader.exe"
					If FileExists($candf) Then Return $candf
				EndIf
				Local $inst2 = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Adobe\Adobe Acrobat\DC\Installer", "SCAPackageLevel")
				If @error = 0 And StringLen($inst2) Then
					Local $candidate2 = @ProgramFilesDir & "(x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
					$candidate2 = StringReplace($candidate2, "(x86)", "Program Files (x86)")
					If FileExists($candidate2) Then Return $candidate2
				EndIf
			Case "programfiles", "programfilesx86", "programfilesx64"
				; check common locations ? order: Program Files (x86) and Program Files
				Local $candList = @ProgramFilesDir & "\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe|" & @ProgramFilesDir & "\Adobe\Acrobat DC\Acrobat\Acrobat.exe|" & @ProgramFilesDir & "\Adobe\Acrobat\Acrobat.exe|" & @ProgramFilesDir & "\SumatraPDF\SumatraPDF.exe|" & @ProgramFilesDir & "(x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe|" & @ProgramFilesDir & "(x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe|" & @ProgramFilesDir & "(x86)\Adobe\Acrobat\Acrobat.exe|" & @ProgramFilesDir & "(x86)\SumatraPDF\SumatraPDF.exe"
				Local $candidates = StringSplit($candList, "|", 2)
				For $c = 1 To $candidates[0]
					Local $path = $candidates[$c]
					; attempt to normalize odd strings like (x86) ? perform two common expands
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
EndFunc   ;==>AutoDiscoverExecPath

; DetermineDefaultPreset(path) - heuristic choice of preset based on exec name
Func DetermineDefaultPreset($path)
	If StringLen($path) = 0 Then Return ""
	Local $lower = StringLower($path)
	; Acrobat Reader / Acrobat -> prefer suppressing splash (/s)
	If StringInStr($lower, "acro") Or StringInStr($lower, "acrord") Or StringInStr($lower, "acroRd") Then
		Return "suppress"
	EndIf
	; SumatraPDF ? no special flags by default
	If StringInStr($lower, "sumatrapdf") Then Return ""
	; Fallback: no preset
	Return ""
EndFunc   ;==>DetermineDefaultPreset

; GetPresetParams(name) - return param string for known preset or from [presets] INI.
Func GetPresetParams($name)
	If StringLen($name) = 0 Then Return ""

	; allow the INI to override or define custom presets in [presets] section
	Local $iniVal = IniRead($cfg_filename, "presets", $name, "")
	If StringLen($iniVal) Then Return StringStripWS($iniVal, 7)

	; built-in helpers for common Acrobat/Reader options
	Local $n = StringLower($name)
	; Match several common names using an If/ElseIf chain to avoid complex Case expressions
	If $n = "open" Then
		Return ""
	ElseIf $n = "newinstance" Then
		Return "/n"
	ElseIf $n = "suppress" Or $n = "splash" Then
		Return "/s"
	ElseIf $n = "openminimized" Or $n = "minimized" Then
		Return "/h"
	ElseIf $n = "openquiet" Or $n = "nowindow" Then
		Return "/o"
	ElseIf $n = "printdialog" Then
		Return "/p"
	ElseIf $n = "silentprint" Then
		Return "/t"
	ElseIf $n = "silentprintdefaults" Or $n = "pt" Or $n = "/pt" Then
		Return "/pt"
	ElseIf $n = "external" Or $n = "dde" Then
		Return "/x"
	Else
		Return ""
	EndIf
EndFunc   ;==>GetPresetParams




