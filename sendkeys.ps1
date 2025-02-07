# Load necessary assembly
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class User32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

# Wait for 10 seconds at the start
Start-Sleep -Seconds 10

while ($true) {
    # Get the handle of the active window
    $handle = [User32]::GetForegroundWindow()
    
    # Set the active window
    [User32]::SetForegroundWindow($handle)

    # Send the character "J" followed by Enter key
    [System.Windows.Forms.SendKeys]::SendWait("J{ENTER}")

    # Wait for a random interval between 300 and 1500 seconds
    Start-Sleep -Seconds (Get-Random -Minimum 300 -Maximum 1200)
}
