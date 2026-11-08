# Crea il pacchetto d'installazione del client di Midian ("Installazione UOMidian.zip") dalla cartella del
# client in uso, senza i dati personali: account e password, profili dei personaggi, journal, log, macro,
# profili di Razor, copie di riserva.
# Uso: powershell -ExecutionPolicy Bypass -File crea-pacchetto.ps1 [-Uscita <zip>] [-Ip <indirizzo>] [-Porta <n>]
param(
	[string]$Client = "C:\Users\paolo\OneDrive\Desktop\Midian-ClientUo",
	[string]$Uscita = "C:\Midian All\Installazione UOMidian.zip",
	[string]$Ip = "",
	[int]$Porta = 0
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

# Percorsi relativi (con /) da non mettere nel pacchetto.
$escludi = @(
	'^ClassicUO/Data/Profiles/',			# profili dei personaggi, ultimo account usato
	'^ClassicUO/Data/Client/JournalLogs/',
	'^ClassicUO/Logs/',
	'^ClassicUO/Crash\.log$',
	'^ClassicUO/originali-',				# copia di riserva del ClassicUO originale
	'\.prec$',
	'^ClassicUO/Data/Plugins/Razor/Profiles/',	# profili e personaggi di Razor
	'^ClassicUO/Data/Plugins/Razor/Macros/',
	'^UO/Desktop/',							# macro e impostazioni dei personaggi del client 2D
	'^UO/Macros\.txt$', '^UO/Umacros\.txt$', '^UO/UOReport\d*\.log$',
	'^UO/uo\.cfg$',							# client 2D: account, password e percorsi del PC; ClassicUO non la usa
	'^UO/midian-fuso\.txt$',				# segnaposto: "Avvia Midian.bat" copia i file fusi al primo avvio
	'^Launcher/stato\.json$', '\.scaricamento$',	# cache e scaricamenti a meta' del launcher
	'^ClassicUO/Data/Plugins/Razor/settings\.csv$', '^ClassicUO/Data/Plugins/Razor/counters\.xml$',	# Razor: del giocatore
	'^ClassicUO/Data/Client/MapsCache/'
)
if (-not (Test-Path "$Client\ClassicUO\ClassicUO.exe")) { throw "Client non trovato in $Client" }

# settings.json senza account; l'indirizzo del server si puo' cambiare con -Ip e -Porta.
$s = Get-Content "$Client\ClassicUO\settings.json" -Raw | ConvertFrom-Json
$s.username = ""; $s.password = ""; $s.saveaccount = $false; $s.autologin = $false; $s.profilespath = ""
if ($Ip) { $s.ip = $Ip }
if ($Porta) { $s.port = $Porta }
$settings = $s | ConvertTo-Json -Depth 10

if (Test-Path $Uscita) { Remove-Item $Uscita }
$zip = [IO.Compression.ZipFile]::Open($Uscita, 'Create')
$n = 0; $tolti = 0
try {
	foreach ($f in Get-ChildItem $Client -Recurse -File) {
		$rel = $f.FullName.Substring($Client.Length + 1).Replace('\', '/')
		if ($escludi | Where-Object { $rel -match $_ }) { $tolti++; continue }
		$nome = "Midian-ClientUo/$rel"
		if ($rel -eq 'ClassicUO/settings.json') {
			$e = $zip.CreateEntry($nome, 'Optimal'); $w = New-Object IO.StreamWriter($e.Open(), (New-Object Text.UTF8Encoding $false)); $w.Write($settings); $w.Close()
		} else {
			[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $nome, 'Optimal') | Out-Null
		}
		$n++
	}
} finally { $zip.Dispose() }
"$n file nel pacchetto, $tolti esclusi: $Uscita ($([math]::Round((Get-Item $Uscita).Length / 1MB, 1)) MB)"
"server nel pacchetto: $($s.ip):$($s.port)"
