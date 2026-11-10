# Aspetta che l'elenco dei file del client (manifest.json) appena caricato sia davvero online sul sito.
# Dopo pubblica-aggiornamento.ps1 e il push di Midian-Website, GitHub Pages impiega uno o due minuti a pubblicare
# il file nuovo: chi apriva il launcher in quei minuti trovava ancora l'elenco vecchio e non si aggiornava.
# Si lancia prima di riavviare o aprire il server, cosi' i giocatori entrano gia' con i file nuovi (Midian-ClassicUO #10).
# Uso: powershell -ExecutionPolicy Bypass -File attendi-pubblicazione.ps1 [-Minuti 10]
# Esce con 0 quando l'elenco online e' uguale a quello locale, con 1 se non lo diventa entro il tempo.
param(
	[string]$Locale = "C:\Midian All\Midian-Website\aggiornamenti\manifest.json",
	[string]$Online = "https://midianuo.github.io/Midian-Website/aggiornamenti/manifest.json",
	[int]$Minuti = 10
)
$ErrorActionPreference = "Stop"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Normalizza($testo) { return (($testo -replace "`r", "") -replace "^\uFEFF", "").Trim() }

$atteso = Normalizza ([IO.File]::ReadAllText($Locale, [Text.Encoding]::UTF8))
$fine = (Get-Date).AddMinutes($Minuti)
$giro = 0
while ($true) {
	$giro++
	$remoto = $null
	try {
		$wc = New-Object Net.WebClient
		$wc.Headers.Add("User-Agent", "MidianLauncher/1")
		$wc.Encoding = [Text.Encoding]::UTF8
		# Il parametro t evita la cache della rete di GitHub (ogni richiesta e' un indirizzo nuovo).
		$url = $Online + "?t=" + [DateTime]::UtcNow.Ticks
		$remoto = Normalizza ($wc.DownloadString($url))
	} catch {
		Write-Host ("{0}  il sito non risponde: {1}" -f (Get-Date -Format "HH:mm:ss"), $_.Exception.Message)
	}
	if ($remoto -ne $null -and $remoto -eq $atteso) {
		Write-Host ("{0}  l'elenco dei file online e' quello nuovo: i giocatori che aprono il launcher si aggiornano." -f (Get-Date -Format "HH:mm:ss"))
		exit 0
	}
	if ((Get-Date) -gt $fine) {
		Write-Host ("{0}  dopo {1} minuti l'elenco online e' ancora diverso da quello locale: controlla il push di Midian-Website." -f (Get-Date -Format "HH:mm:ss"), $Minuti)
		exit 1
	}
	if ($giro -eq 1 -or $giro % 4 -eq 0) { Write-Host ("{0}  l'elenco online non e' ancora quello nuovo, aspetto..." -f (Get-Date -Format "HH:mm:ss")) }
	Start-Sleep -Seconds 15
}
