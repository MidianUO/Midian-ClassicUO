# Pubblica un aggiornamento del client per il launcher di Midian.
# Parte dalla cartella del client in uso (come crea-pacchetto.ps1), ci copia il launcher, calcola l'impronta
# SHA-256 di ogni file (senza i dati personali) e:
#  - carica sulla Release "client-file" di MidianUO/Midian-Website solo i file che non ci sono ancora
#    (nome dell'allegato = impronta, cosi' un file uguale non si ricarica mai);
#  - scrive l'elenco in Midian-Website\aggiornamenti\manifest.json (poi: commit e push del sito).
# Con -Prova <cartella> non carica niente: copia i file in <cartella>\file e scrive <cartella>\manifest.json
# con indirizzi file:/// (per provare il launcher in locale).
# Uso: powershell -ExecutionPolicy Bypass -File pubblica-aggiornamento.ps1 [-Prova <cartella>]
param(
	[string]$Client = "C:\Users\paolo\OneDrive\Desktop\Midian-ClientUo",
	[string]$Launcher = "C:\Midian All\Midian-ClassicUO\midian-launcher",
	[string]$Sito = "C:\Midian All\Midian-Website",
	[string]$Repo = "MidianUO/Midian-Website",
	[string]$Prova = ""
)
$ErrorActionPreference = "Stop"

# Stesse esclusioni del pacchetto, piu' i file che il launcher non deve mai toccare.
$escludi = @(
	'^ClassicUO/Data/Profiles/', '^ClassicUO/Data/Client/JournalLogs/', '^ClassicUO/Logs/', '^ClassicUO/Crash\.log$',
	'^ClassicUO/originali-', '\.prec$', '^ClassicUO/Data/Plugins/Razor/Profiles/', '^ClassicUO/Data/Plugins/Razor/Macros/',
	'^UO/Desktop/', '^UO/Macros\.txt$', '^UO/Umacros\.txt$', '^UO/UOReport\d*\.log$', '^UO/uo\.cfg$', '^UO/midian-fuso\.txt$',
	'^ClassicUO/settings\.json$',		# impostazioni del giocatore: il launcher cambia solo ip e porta
	'^ClassicUO/Data/Plugins/Razor/settings\.csv$', '^ClassicUO/Data/Plugins/Razor/counters\.xml$',	# Razor: del giocatore
	'^ClassicUO/Data/Plugins/Razor/Scripts/', '^ClassicUO/Data/Client/MapsCache/',	# script del giocatore, cache
	'^Launcher/stato\.json$', '\.scaricamento$',
	'^Avvia Midian\.bat$',				# il file che sta girando: non si aggiorna
	'^UO/verdata\.mul\.originale$'
)
if (-not (Test-Path "$Client\ClassicUO\ClassicUO.exe")) { throw "Client non trovato in $Client" }
if (Get-Process ClassicUO -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Client\*" }) { throw "Chiudi ClassicUO: i file aperti possono essere a meta'." }

# 1) Il launcher nella cartella del client.
New-Item -ItemType Directory -Force "$Client\Launcher" | Out-Null
foreach ($n in 'aggiorna.ps1', 'sfondo.png') { Copy-Item "$Launcher\$n" "$Client\Launcher\$n" -Force }
Copy-Item "$Launcher\Avvia Midian.bat" "$Client\Avvia Midian.bat" -Force

# 2) Elenco dei file con impronta.
$s = Get-Content "$Client\ClassicUO\settings.json" -Raw | ConvertFrom-Json
$sha = [Security.Cryptography.SHA256]::Create()
$voci = New-Object Collections.ArrayList
foreach ($f in Get-ChildItem $Client -Recurse -File) {
	$rel = $f.FullName.Substring($Client.Length + 1).Replace('\', '/')
	if ($escludi | Where-Object { $rel -match $_ }) { continue }
	$fs = [IO.File]::OpenRead($f.FullName)
	try { $h = ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '').ToLower() } finally { $fs.Dispose() }
	[void]$voci.Add([pscustomobject]@{ p = $rel; s = $f.Length; h = $h; percorso = $f.FullName; nome = $h.Substring(0, 32) + ".bin" })
}
"$($voci.Count) file nell'elenco"

# 3) I file da caricare.
if ($Prova) {
	New-Item -ItemType Directory -Force "$Prova\file" | Out-Null
	foreach ($v in $voci) {
		$d = "$Prova\file\$($v.nome)"
		if (-not (Test-Path $d)) { Copy-Item $v.percorso $d }
		$v | Add-Member -NotePropertyName u -NotePropertyValue ("file:///" + ($d -replace '\\', '/'))
	}
	$uscita = "$Prova\manifest.json"
} else {
	# Release con al massimo 950 allegati ciascuna: client-file, client-file-2, ...
	$presenti = @{}; $tags = @()
	for ($k = 1; $k -le 20; $k++) {
		$tag = if ($k -eq 1) { "client-file" } else { "client-file-$k" }
		$json = gh release view $tag -R $Repo --json assets 2>$null
		if ($LASTEXITCODE -ne 0) { break }
		$tags += $tag
		foreach ($a in ($json | ConvertFrom-Json).assets) { $presenti[$a.name] = $tag }
	}
	$nuovi = @($voci | Where-Object { -not $presenti.ContainsKey($_.nome) } | Sort-Object nome -Unique)
	"$($nuovi.Count) file da caricare ($([math]::Round((($nuovi | Measure-Object s -Sum).Sum) / 1MB, 1)) MB)"
	$stage = Join-Path $env:TEMP "midian-carica"; if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }; New-Item -ItemType Directory $stage | Out-Null
	$i = 0
	while ($i -lt $nuovi.Count) {
		# release con posto libero
		$tag = $null
		foreach ($t in $tags) { if ((@($presenti.Values | Where-Object { $_ -eq $t })).Count -lt 950) { $tag = $t; break } }
		if (-not $tag) {
			$tag = if ($tags.Count -eq 0) { "client-file" } else { "client-file-$($tags.Count + 1)" }
			gh release create $tag -R $Repo -t "File del client per il launcher ($tag)" -n "File del client di Midian scaricati dal launcher. Il nome di ogni file e' la sua impronta SHA-256; l'elenco e' in aggiornamenti/manifest.json sul sito. Per installare il gioco usa il pacchetto della release 'client'." | Out-Null
			if ($LASTEXITCODE -ne 0) { throw "release $tag non creata" }
			$tags += $tag
		}
		$liberi = 950 - (@($presenti.Values | Where-Object { $_ -eq $tag })).Count
		$gruppo = @($nuovi[$i..([math]::Min($i + [math]::Min($liberi, 20), $nuovi.Count) - 1)])
		$file = @()
		foreach ($v in $gruppo) { $d = Join-Path $stage $v.nome; Copy-Item $v.percorso $d -Force; $file += $d }
		$ok = $false
		for ($r = 0; $r -lt 4 -and -not $ok; $r++) { gh release upload $tag @file -R $Repo --clobber; $ok = ($LASTEXITCODE -eq 0); if (-not $ok) { Start-Sleep 10 } }
		if (-not $ok) { throw "caricamento non riuscito su $tag" }
		foreach ($v in $gruppo) { $presenti[$v.nome] = $tag; Remove-Item (Join-Path $stage $v.nome) -Force }
		$i += $gruppo.Count
		"  caricati $i di $($nuovi.Count)"
	}
	Remove-Item $stage -Recurse -Force
	foreach ($v in $voci) { $v | Add-Member -NotePropertyName u -NotePropertyValue "https://github.com/$Repo/releases/download/$($presenti[$v.nome])/$($v.nome)" }
	New-Item -ItemType Directory -Force "$Sito\aggiornamenti" | Out-Null
	$uscita = "$Sito\aggiornamenti\manifest.json"
}

# 4) L'elenco.
$man = [ordered]@{
	versione = (Get-Date -Format "yyyy-MM-dd HH:mm")
	server = [ordered]@{ ip = $s.ip; port = [int]$s.port }
	file = @($voci | Sort-Object p | ForEach-Object { [ordered]@{ p = $_.p; s = $_.s; h = $_.h; u = $_.u } })
}
[IO.File]::WriteAllText($uscita, ($man | ConvertTo-Json -Depth 5 -Compress), (New-Object Text.UTF8Encoding $false))
"elenco scritto: $uscita (server $($s.ip):$($s.port))"
