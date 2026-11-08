# Crea il pacchetto per Windows 7, 8 e 8.1 ("Installazione UOMidian - Windows 7.zip").
# Il ClassicUO di Midian usa .NET 10, che richiede Windows 10: questo pacchetto usa invece ClassicUO 0.1.11.0
# (l'ultimo per .NET Framework 4.7.2, compilato da C:\Midian All\ClassicUO-win7, sorgente ufficiale) con Razor,
# senza le aggiunte di Midian e senza il launcher. C'e' anche il client originale 1.26 (UO\client.exe) di riserva.
# Il pacchetto normale non si tocca.
# Uso: powershell -ExecutionPolicy Bypass -File crea-pacchetto-win7.ps1 [-Ip <indirizzo>] [-Porta <n>]
param(
	[string]$Client = "C:\Users\paolo\OneDrive\Desktop\Midian-ClientUo",
	[string]$CuoVecchio = "C:\Midian All\ClassicUO-win7\bin\Release",
	[string]$Uscita = "C:\Midian All\Installazione UOMidian - Windows 7.zip",
	[string]$Ip = "45.13.235.243",
	[int]$Porta = 2593
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$uo = Join-Path $Client "UO"
if (-not (Test-Path "$uo\client.exe")) { throw "client.exe non trovato in $uo" }
if (-not (Test-Path "$uo\midian-fuso.txt")) { throw "In $uo i file non sono ancora fusi: avvia prima il gioco una volta" }
if (-not (Test-Path "$CuoVecchio\ClassicUO.exe")) { throw "ClassicUO vecchio non compilato in $CuoVecchio" }
$razor = Join-Path $Client "ClassicUO\Data\Plugins\Razor"

# Dati personali e copie che non servono.
$escludiUO = @('^Desktop/', '^Macros\.txt$', '^Umacros\.txt$', '^UOReport\d*\.log$', '^uo\.cfg$', '^midian-fuso\.txt$',
	'^verdata\.mul\.originale$', '^orig_client\.exe$', '\.prec$', '^login\.cfg$')
$escludiRazor = @('^Profiles/', '^Macros/', '^Scripts/', '^settings\.csv$', '^counters\.xml$', '\.prec$')

$settings = [ordered]@{
	username = ""; password = ""; ip = $Ip; port = $Porta; ultimaonlinedirectory = "..\UO"; profilespath = ""
	clientversion = "1.26.4"; lang = "ITA"; lastservernum = 1; last_server_name = "Midian"; fps = 60
	saveaccount = $false; autologin = $false; reconnect = $false; login_music = $true; use_verdata = $false
	encryption = 3; plugins = @("Razor\Razor.exe")
}
$bat = @"
@echo off
rem Midian per Windows 7, 8 e 8.1: ClassicUO 0.1.11 con Razor.
cd /d "%~dp0ClassicUO"
start "" ClassicUO.exe
"@
$batOrig = @"
@echo off
rem Midian: il client originale di Ultima Online 1.26 (senza Razor). Da usare se ClassicUO non parte.
cd /d "%~dp0UO"
start "" client.exe
"@
$leggimi = @"
MIDIAN - pacchetto per Windows 7, 8 e 8.1
==========================================

QUESTO PACCHETTO E' SOLO PER CHI NON HA WINDOWS 10 O 11.
Se hai Windows 10 o 11 usa il pacchetto normale del sito: ha piu' funzioni e si aggiorna da solo.

Prima di giocare (una volta sola), installa da Microsoft se non li hai gia':
  - .NET Framework 4.7.2 o piu' recente
  - Visual C++ Redistributable a 64 bit: https://aka.ms/vs/17/release/vc_redist.x64.exe
Servono Windows a 64 bit e, su Windows 7, il Service Pack 1.

Come si gioca:
  1. Estrai lo zip in una cartella.
  2. Fai doppio clic su "Avvia Midian.bat" (ClassicUO con Razor).
  3. Scrivi nome e password del tuo account.
  Se ClassicUO non parte, prova "Avvia client originale.bat" (il client 1.26 originale, senza Razor).

Cosa manca rispetto al pacchetto per Windows 10/11:
  - gli aggiornamenti automatici (se il sito annuncia un nuovo pacchetto, riscaricalo);
  - la creazione dell'account dal gioco: chiedilo allo staff su Discord (pagina Contatti del sito),
    oppure crealo una volta da un PC con Windows 10/11;
  - la finestra "Effetti attivi" e il pulsante Effetti;
  - i numeri dei danni sopra la testa.

Server: $($Ip), porta $($Porta) (gia' impostato).
"@

if (Test-Path $Uscita) { Remove-Item $Uscita }
$zip = [IO.Compression.ZipFile]::Open($Uscita, 'Create')
$n = 0; $tolti = 0
function Testo($nome, $contenuto, $enc) {
	$e = $zip.CreateEntry($nome, 'Optimal'); $w = New-Object IO.StreamWriter($e.Open(), $enc)
	$w.Write(($contenuto -replace "`r?`n", "`r`n")); $w.Close()
}
function Cartella($da, $dentro, $escludi) {
	foreach ($f in Get-ChildItem $da -Recurse -File) {
		$rel = $f.FullName.Substring($da.Length + 1).Replace('\', '/')
		if ($escludi | Where-Object { $rel -match $_ }) { $script:tolti++; continue }
		[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, "Midian-Win7/$dentro/$rel", 'Optimal') | Out-Null
		$script:n++
	}
}
try {
	Cartella $uo "UO" $escludiUO
	Cartella $CuoVecchio "ClassicUO" @('\.pdb$', '^Logs/', '^Data/Profiles/', '^settings\.json$')
	Cartella $razor "ClassicUO/Data/Plugins/Razor" $escludiRazor
	$ascii = [Text.Encoding]::GetEncoding(1252)
	Testo "Midian-Win7/UO/login.cfg" "LoginServer=$Ip,$Porta`n" $ascii
	Testo "Midian-Win7/ClassicUO/settings.json" ($settings | ConvertTo-Json -Depth 5) (New-Object Text.UTF8Encoding $false)
	Testo "Midian-Win7/Avvia Midian.bat" $bat $ascii
	Testo "Midian-Win7/Avvia client originale.bat" $batOrig $ascii
	Testo "Midian-Win7/LEGGIMI.txt" $leggimi $ascii
	# Licenza di ClassicUO (BSD-2-Clause): va distribuita con il programma.
	$lic = Join-Path (Split-Path (Split-Path $CuoVecchio)) "LICENSE.md"
	if (Test-Path $lic) { Testo "Midian-Win7/ClassicUO/LICENSE-ClassicUO.txt" ([IO.File]::ReadAllText($lic)) (New-Object Text.UTF8Encoding $false) }
} finally { $zip.Dispose() }
"$n file, $tolti esclusi: $Uscita ($([math]::Round((Get-Item $Uscita).Length / 1MB, 1)) MB)"
"SHA-256: " + (Get-FileHash $Uscita -Algorithm SHA256).Hash.ToLower()
