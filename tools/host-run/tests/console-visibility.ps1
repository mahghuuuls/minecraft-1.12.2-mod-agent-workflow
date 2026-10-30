$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HostRunConsoleVisibility {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWindowVisible(IntPtr handle);
}
'@
$handle = [HostRunConsoleVisibility]::GetConsoleWindow()
if ($handle -ne [IntPtr]::Zero -and [HostRunConsoleVisibility]::IsWindowVisible($handle)) {
    throw 'The background command has a visible console window.'
}
Write-Output 'host-run console hidden'
