# Scrive una riga nella console di sphere.exe sul VPS, come se la si battesse a mano (poi Invio).
# Gira nella sessione del Desktop remoto (attivita' pianificata "Midian Console"), perche' la console sta li'.
# Uso: powershell -ExecutionPolicy Bypass -File console.ps1 -Testo "#"
param([Parameter(Mandatory = $true)][string]$Testo, [string]$Esito = "C:\Midian-Setup\console-esito.txt")
$ErrorActionPreference = "Stop"
try {
	$p = Get-Process sphere -ErrorAction Stop | Select-Object -First 1
	Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class MidianConsole {
	[StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode)]
	public struct KEY_EVENT_RECORD {
		[FieldOffset(0)] public int bKeyDown;
		[FieldOffset(4)] public short wRepeatCount;
		[FieldOffset(6)] public short wVirtualKeyCode;
		[FieldOffset(8)] public short wVirtualScanCode;
		[FieldOffset(10)] public char UnicodeChar;
		[FieldOffset(12)] public int dwControlKeyState;
	}
	[StructLayout(LayoutKind.Explicit)]
	public struct INPUT_RECORD {
		[FieldOffset(0)] public short EventType;
		[FieldOffset(4)] public KEY_EVENT_RECORD KeyEvent;
	}
	[DllImport("kernel32.dll", SetLastError = true)] public static extern bool FreeConsole();
	[DllImport("kernel32.dll", SetLastError = true)] public static extern bool AttachConsole(uint pid);
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	public static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	public static extern bool WriteConsoleInput(IntPtr h, INPUT_RECORD[] buf, uint len, out uint written);
	[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
	public static string Scrivi(uint pid, string testo) {
		FreeConsole();
		if (!AttachConsole(pid)) return "AttachConsole fallito " + Marshal.GetLastWin32Error();
		IntPtr h = CreateFile("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
		if (h == new IntPtr(-1)) { FreeConsole(); return "CONIN$ non aperto " + Marshal.GetLastWin32Error(); }
		string s = testo + "\r";
		INPUT_RECORD[] r = new INPUT_RECORD[s.Length * 2];
		for (int i = 0; i < s.Length; i++) {
			for (int k = 0; k < 2; k++) {
				r[i * 2 + k].EventType = 1;
				r[i * 2 + k].KeyEvent.bKeyDown = (k == 0) ? 1 : 0;
				r[i * 2 + k].KeyEvent.wRepeatCount = 1;
				r[i * 2 + k].KeyEvent.UnicodeChar = s[i];
				r[i * 2 + k].KeyEvent.wVirtualKeyCode = (short)(s[i] == '\r' ? 0x0D : 0);
			}
		}
		uint n;
		bool ok = WriteConsoleInput(h, r, (uint)r.Length, out n);
		CloseHandle(h); FreeConsole();
		return ok ? ("ok " + n) : ("WriteConsoleInput fallito " + Marshal.GetLastWin32Error());
	}
}
"@
	$r = [MidianConsole]::Scrivi([uint32]$p.Id, $Testo)
	Set-Content $Esito ("{0} {1}" -f (Get-Date -Format "HH:mm:ss"), $r) -Encoding Ascii
} catch {
	Set-Content $Esito ("{0} errore: {1}" -f (Get-Date -Format "HH:mm:ss"), $_.Exception.Message) -Encoding Ascii
}
