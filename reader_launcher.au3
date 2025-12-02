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
Global $cfg_sleep = IniRead($cfg_filename, $cfg_section1, "sleep", 1000), _
	$cfg_sleeprand = IniRead($cfg_filename, $cfg_section1, "sleeprandom", 0), _
	$cfg_sleepmin = IniRead($cfg_filename, $cfg_section1, "sleepmin", 950), _
	$cfg_sleepmax = IniRead($cfg_filename, $cfg_section1, "sleepmax", 1950), _
	$cfg_debug = IniRead($cfg_filename, $cfg_section1, "debug", 0), _
	$cfg_debugnosleep = IniRead($cfg_filename, $cfg_section1, "debugnosleep", 0), _
	$cfg_debugnoexec = IniRead($cfg_filename, $cfg_section1, "debugnoexec", 0), _
	$cfg_execpath = IniRead($cfg_filename, $cfg_section1, "execpath", 'C:\')

$ex_sleep = $cfg_sleeprand ? Random($cfg_sleepmin, $cfg_sleepmax, 1) : $cfg_sleep

$dbg_message = "Sleep time:" & $ex_sleep & @CRLF & "Randomize sleep:" & $cfg_sleeprand
debug($dbg_message)

If ($cfg_debugnosleep = 0) Then Sleep($ex_sleep)

$ex_parameters = StringReplace($CmdLineRaw,@ScriptName,"")

$dbg_message = "Launcher parameters:" & $ex_parameters
debug($dbg_message)

$dbg_message = "Executable path:" & $cfg_execpath
debug($dbg_message)

If ($cfg_debugnoexec = 0) Then ShellExecute($cfg_execpath, $ex_parameters)

Exit

; Displays a Debug message
Func debug($message)
	If ($cfg_debug = 1) Then MsgBox(0, "Debug Message", $message)
EndFunc