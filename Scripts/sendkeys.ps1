<#
===============================================================================
 DISABLED - THIS SCRIPT IS INTENTIONALLY COMMENTED OUT. DO NOT RE-ENABLE
             WITHOUT READING THIS FIRST.
===============================================================================

 What it did
 -----------
 Waited 10 seconds, then every 5-20 minutes sent the keystrokes "J" and ENTER
 to whatever window happened to have focus. In practice: an idle-defeater, to
 keep a workstation or a chat client from showing as away.

 Why it is disabled
 ------------------
 1. TECHNICAL. It sends keys to the FOREGROUND window, whatever that is at the
    moment the timer fires -- not to a window it chose. A stray ENTER lands on
    whatever button, form, or dialog is focused: Send, Submit, Delete, OK.
    It runs unattended in an infinite loop, so nobody is watching when it does.

 2. OPERATIONAL. SetForegroundWindow + SendKeys on a timer is a signature that
    endpoint protection (EDR) and data-loss-prevention tooling flag as input
    injection. On a managed or domain-joined machine, expect it to be caught.

 3. PROFESSIONAL. Defeating idle/presence detection is, at most employers, a
    policy violation and a disciplinary matter regardless of intent. This file
    lives in a public repository under a real name.

 Kept rather than deleted for reference: the Add-Type / P-Invoke block below is
 a correct, reusable example of calling user32.dll from PowerShell, which is
 worth having even though this particular use of it is not.

 If you need a legitimate keep-awake, use the supported mechanisms instead:
   - powercfg /change standby-timeout-ac 0
   - SetThreadExecutionState (ES_CONTINUOUS | ES_DISPLAY_REQUIRED)
   - Microsoft PowerToys "Awake"
 All three tell Windows not to sleep, rather than faking user activity.

 Disabled: 2026-09-08
===============================================================================
#>

<#  ORIGINAL CODE BELOW - COMMENTED OUT, NON-FUNCTIONAL

# # Load necessary assembly
# Add-Type -AssemblyName System.Windows.Forms
# Add-Type -TypeDefinition @"
# using System;
# using System.Runtime.InteropServices;
#
# public class User32 {
#     [DllImport("user32.dll")]
#     public static extern IntPtr GetForegroundWindow();
#     [DllImport("user32.dll")]
#     [return: MarshalAs(UnmanagedType.Bool)]
#     public static extern bool SetForegroundWindow(IntPtr hWnd);
# }
# "@
#
# # Wait for 10 seconds at the start
# # give you time to place your cursor
# Start-Sleep -Seconds 10
#
# while ($true) {
#     # Get the handle of the active window
#     $handle = [User32]::GetForegroundWindow()
#
#     # Set the active window
#     [User32]::SetForegroundWindow($handle)
#
#     # Send the character "J" followed by Enter key
#     [System.Windows.Forms.SendKeys]::SendWait("J{ENTER}")
#
#     # Wait for a random interval between 300 and 1500 seconds
#     Start-Sleep -Seconds (Get-Random -Minimum 300 -Maximum 1200)
# }
END OF ORIGINAL CODE
#>
