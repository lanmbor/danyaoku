; Set up the language key See 
; http://msdn.microsoft.com/en-us/library/dd318693%28v=vs.85%29.aspx
; for the language identifiers list.
zh := DllCall("LoadKeyboardLayout", "Str", 0x00020804, "Int", 1)
en := DllCall("LoadKeyboardLayout", "Str", 0x00000409, "Int", 1)

GetGUIThreadInfo_hwndActive(WinTitle="A")
{
	ControlGet, hwnd, HWND,,, %WinTitle%
	if (WinActive(WinTitle)) {
		ptrSize := !A_PtrSize ? 4 : A_PtrSize
		VarSetCapacity(stGTI, cbSize:=4+4+(PtrSize*6)+16, 0)
		NumPut(cbSize, stGTI,  0, "UInt")
		return hwnd := DllCall("GetGUIThreadInfo", "Uint", 0, "Ptr", &stGTI)
				 ? NumGet(stGTI, 8+PtrSize, "Ptr") : hwnd
	}
	else {
		return hwnd
	}
}



^j::
WinActivate, SAP Logon 800
If WinExist("SAP Logon 800")
{
     WinActivate ; Use the window found by WinExist.

}
else
{
    RunWait, C:\ProgramData\Microsoft\Windows\Start Menu\Programs\SAP Front End\SAP Logon
	Sleep,3000
	WinActivate, SAP Logon 800
	Sleep, 1000      ; Keep it down for one second.
}
send _{Tab}
sleep, 1000
send {Down}
sleep,1000
send {Tab}
sleep,1000
send {Enter}
return


::Eng::
w := DllCall("GetForegroundWindow")
pid := DllCall("GetWindowThreadProcessId", "UInt", w, "Ptr", 0)
l := DllCall("GetKeyboardLayout", "UInt", pid)
if (l = en)
{
    PostMessage 0x50, 0, 0,, A
;	result := SendMessage 0x283, 0x001, 0, , A
;	Msgbox %result%
	
}
else
{
    PostMessage 0x50, 0, 0,, A
}

return

::ONOTES::
InputBox, NOTESNO, Enter notes number
if ErrorLevel
    MsgBox, CANCEL was pressed.
else
	Run https://launchpad.support.sap.com/#/notes/%NOTESNO%
return

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
; Toggle Proxy
^!p::  ; Ctrl+Alt+P as the hotkey.
ToggleProxy()
return

ToggleProxy() {
    ; Access the registry key where proxy settings are stored.
    RegRead, ProxyEnable, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable
    
    ; Check if the proxy is currently enabled (ProxyEnable = 1).
    if (ProxyEnable = 1) {
        ; Proxy is enabled, so disable it.
        RegWrite, REG_DWORD, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable, 0
        Tooltip, Proxy disabled.
    } else {
        ; Proxy is disabled, so enable it.
        RegWrite, REG_DWORD, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Internet Settings, ProxyEnable, 1
        Tooltip, Proxy enabled.
    }

    ; Refresh Internet settings to apply changes.
    DllCall("Wininet.dll\InternetSetOptionW", UInt, 0, UInt, 39, UInt, 0, UInt, 0)  ; INTERNET_OPTION_SETTINGS_CHANGED
    DllCall("Wininet.dll\InternetSetOptionW", UInt, 0, UInt, 37, UInt, 0, UInt, 0)  ; INTERNET_OPTION_REFRESH

    ; Show a notification for 1 second.
    SetTimer, RemoveTooltip, 1000  ; Remove the tooltip after 1 second.
    return
}

RemoveTooltip:
    SetTimer, RemoveTooltip, Off
    Tooltip
return




