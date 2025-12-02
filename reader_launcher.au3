#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=adobe_reader_logo.ico
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
	Simple Adobe Reader Launcher

#ce ----------------------------------------------------------------------------

; Global Configurations
Global $cfg_filename = @ScriptDir & "\launcher.ini", _
	$cfg_section1 = "general"

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

; Normalize / coerce to numeric where required
Local $cfg_sleep = Int($raw_sleep)
Local $cfg_sleeprand = Int($raw_sleeprand)
Local $cfg_sleepmin = Int($raw_sleepmin)
Local $cfg_sleepmax = Int($raw_sleepmax)
Local $cfg_debug = Int($raw_debug)
Local $cfg_debugnosleep = Int($raw_debugnosleep)
Local $cfg_debugnoexec = Int($raw_debugnoexec)

; Trim possible wrapping quotes from execpath and any surrounding whitespace
Local $cfg_execpath = StringStripWS(StringReplace($raw_execpath, '"', ''), 3)

; Ensure sensible sleep range
If $cfg_sleepmin < 0 Then $cfg_sleepmin = 0
If $cfg_sleepmax < $cfg_sleepmin Then $cfg_sleepmax = $cfg_sleepmin + 1000

; Determine sleep time to use
Local $ex_sleep = $cfg_sleeprand > 0 ? Random($cfg_sleepmin, $cfg_sleepmax, 1) : $cfg_sleep

; Debug info
Local $dbg_message = "Sleep time: " & $ex_sleep & " ms" & @CRLF & "Randomize sleep: " & $cfg_sleeprand
debug($dbg_message)

; Sleep unless debugnosleep is set
If ($cfg_debugnosleep = 0) Then Sleep($ex_sleep)

; Build parameter string — remove the script name and trim whitespace
Local $ex_parameters = StringStripWS(StringReplace($CmdLineRaw, @ScriptName, ""), 7)
debug("Launcher parameters: " & $ex_parameters)

debug("Executable path: " & $cfg_execpath)

; Verify executable exists before attempting to execute unless debugnoexec set
If ($cfg_debugnoexec = 0) Then
	If StringLen($cfg_execpath) = 0 Then
		MsgBox(16, "Launcher error", "No executable path configured in " & $cfg_filename)
		Exit 1
	EndIf

	; If path is a folder then attempt to open it using ShellExecute; otherwise check file existence
	If Not FileExists($cfg_execpath) Then
		MsgBox(48, "Launcher warning", "Configured execpath does not point to an existing file:" & @CRLF & $cfg_execpath)
		; still attempt to run it; ShellExecute will fail gracefully if invalid
	EndIf

	ShellExecute($cfg_execpath, $ex_parameters)
EndIf

Exit

; Displays a Debug message (pop-up when debug=1)
Func debug($message)
	If ($cfg_debug = 1) Then MsgBox(0, "Debug Message", $message)
EndFunc