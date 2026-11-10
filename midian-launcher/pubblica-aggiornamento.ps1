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
	[string]$Prova = "",
	[string]$Riserva = "Administrator@45.13.235.243",	# VPS con la copia di riserva (C:\Midian-Web\file), via SSH
	[string]$RiservaUrl = "http://45.13.235.243/file/",	# gli stessi file, via web (IIS sul VPS)
	[switch]$SoloRiserva								# copia solo sul VPS, senza GitHub e senza riscrivere l'elenco
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
	'^Launcher/stato-hina\.txt$', '^Launcher/launcher\.log', '\.vecchio$', '\.hina\.(tmp|bak)$', '^\.hina/', '\.pdb$',	# launcher eseguibile
	'^Avvia Midian\.bat$',				# il file che sta girando: non si aggiorna
	'^UO/verdata\.mul\.originale$'
)
if (-not (Test-Path "$Client\ClassicUO\ClassicUO.exe")) { throw "Client non trovato in $Client" }
# I file si leggono soltanto, e quelli che il client scrive mentre gioca (profili, impostazioni) sono esclusi:
# con ClassicUO aperto basta un avviso. Per installare un cuo.dll nuovo invece va chiuso.
if (Get-Process ClassicUO -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Client\*" }) { "attenzione: ClassicUO e' aperto (i file si leggono soltanto)" }

# 0) Prima il launcher eseguibile (Hina, #12): mette exe, libsodium.dll, server.txt e le impostazioni di partenza
#    nella cartella del client e pubblica sul VPS. Cosi' l'elenco qui sotto contiene l'exe e chi ha ancora la
#    vecchia script lo riceve, e la nuova aggiorna.ps1 passa all'exe.
if (-not $Prova -and -not $SoloRiserva) {
	& (Join-Path $Launcher "pubblica-hina.ps1") -Client $Client -Launcher $Launcher
	if (-not $?) { throw "pubblicazione Hina non riuscita" }
}

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

# 2b) Copia di riserva sul VPS: solo i file che mancano, in un unico archivio tar via SSH.
#     Il launcher li usa se GitHub non risponde; l'elenco con le impronte resta solo sul sito (HTTPS).
if (-not $Prova -and $Riserva) {
	$chiave = "$env:USERPROFILE\.ssh\midian_vps"
	$opz = @("-i", $chiave, "-o", "BatchMode=yes", "-o", "ConnectTimeout=20", "-o", "LogLevel=ERROR")
	$vecchio = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
	$lista = & ssh @opz $Riserva "cmd /c dir /b C:\Midian-Web\file" 2>$null
	$ErrorActionPreference = $vecchio
	$cisono = @{}; foreach ($n in $lista) { if ($n) { $cisono[$n.Trim()] = $true } }
	$mancano = @($voci | Where-Object { $_.s -gt 0 -and -not $cisono.ContainsKey($_.nome) } | Sort-Object nome -Unique)
	"riserva: $($mancano.Count) file da copiare sul VPS"
	if ($mancano.Count -gt 0) {
		$st = Join-Path $env:TEMP "midian-riserva"; if (Test-Path $st) { Remove-Item $st -Recurse -Force }; New-Item -ItemType Directory $st | Out-Null
		foreach ($v in $mancano) { Copy-Item $v.percorso (Join-Path $st $v.nome) -Force }
		$tar = Join-Path $env:TEMP "midian-riserva.tar"; if (Test-Path $tar) { Remove-Item $tar -Force }
		& "$env:SystemRoot\System32\tar.exe" -cf $tar -C $st .	# quello di Windows: da bash "tar.exe" sarebbe quello di Git
		if ($LASTEXITCODE) { throw "archivio per la riserva non creato" }
		& scp @opz $tar "${Riserva}:C:/Midian-Web/riserva.tar"
		if ($LASTEXITCODE) { throw "copia sul VPS non riuscita" }
		& ssh @opz $Riserva "cmd /c tar -xf C:\Midian-Web\riserva.tar -C C:\Midian-Web\file && del /q C:\Midian-Web\riserva.tar"
		if ($LASTEXITCODE) { throw "estrazione sul VPS non riuscita" }
		Remove-Item $st -Recurse -Force; Remove-Item $tar -Force
		$dopo = (& ssh @opz $Riserva "cmd /c dir /b C:\Midian-Web\file" 2>$null | Where-Object { $_ }).Count
		"riserva: sul VPS ora $dopo file"
	}
	if ($SoloRiserva) { return }
}

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
	# gh scrive gli errori su stderr: con ErrorActionPreference=Stop PowerShell li tratterebbe come eccezioni.
	function InvocaGh([string[]]$argomenti) {
		$vecchio = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
		try { $out = & gh.exe @argomenti 2>&1; $codice = $LASTEXITCODE } finally { $ErrorActionPreference = $vecchio }
		$testo = ($out | ForEach-Object { "$_" }) -join "`n"
		return [pscustomobject]@{ ok = ($codice -eq 0); testo = $testo }
	}
	function VediRelease($tag) {
		# $null se la release non esiste; riprova se GitHub non risponde.
		for ($r = 0; $r -lt 6; $r++) {
			$g = InvocaGh @('release', 'view', $tag, '-R', $Repo, '--json', 'assets')
			if ($g.ok) { return $g.testo }
			if ($g.testo -match 'not found') { return $null }
			Start-Sleep 10
		}
		throw "GitHub non risponde: $($g.testo)"
	}
	$presenti = @{}; $tags = @()
	for ($k = 1; $k -le 20; $k++) {
		$tag = if ($k -eq 1) { "client-file" } else { "client-file-$k" }
		$json = VediRelease $tag
		if ($null -eq $json) { break }
		$tags += $tag
		foreach ($a in ($json | ConvertFrom-Json).assets) { $presenti[$a.name] = $tag }
	}
	# I file vuoti non si caricano (GitHub li rifiuta): il launcher li crea da solo.
	$nuovi = @($voci | Where-Object { $_.s -gt 0 -and -not $presenti.ContainsKey($_.nome) } | Sort-Object nome -Unique)
	"$($nuovi.Count) file da caricare ($([math]::Round((($nuovi | Measure-Object s -Sum).Sum) / 1MB, 1)) MB)"
	$stage = Join-Path $env:TEMP "midian-carica"; if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }; New-Item -ItemType Directory $stage | Out-Null
	$i = 0
	while ($i -lt $nuovi.Count) {
		# release con posto libero
		$tag = $null
		foreach ($t in $tags) { if ((@($presenti.Values | Where-Object { $_ -eq $t })).Count -lt 950) { $tag = $t; break } }
		if (-not $tag) {
			$tag = if ($tags.Count -eq 0) { "client-file" } else { "client-file-$($tags.Count + 1)" }
			$ok = $false
			for ($r = 0; $r -lt 4 -and -not $ok; $r++) {
				$g = InvocaGh @('release', 'create', $tag, '-R', $Repo, '-t', "File del client per il launcher ($tag)", '-n', "File del client di Midian scaricati dal launcher. Il nome di ogni file e' la sua impronta SHA-256; l'elenco e' in aggiornamenti/manifest.json sul sito. Per installare il gioco usa il pacchetto della release 'client'.")
				$ok = $g.ok -or ($null -ne (VediRelease $tag))
				if (-not $ok) { Start-Sleep 10 }
			}
			if (-not $ok) { throw "release $tag non creata: $($g.testo)" }
			$tags += $tag
		}
		$liberi = 950 - (@($presenti.Values | Where-Object { $_ -eq $tag })).Count
		$gruppo = @($nuovi[$i..([math]::Min($i + [math]::Min($liberi, 20), $nuovi.Count) - 1)])
		$file = @()
		foreach ($v in $gruppo) { $d = Join-Path $stage $v.nome; Copy-Item $v.percorso $d -Force; $file += $d }
		$ok = $false
		for ($r = 0; $r -lt 5 -and -not $ok; $r++) { $g = InvocaGh (@('release', 'upload', $tag) + $file + @('-R', $Repo, '--clobber')); $ok = $g.ok; if (-not $ok) { Start-Sleep 15 } }
		if (-not $ok) { throw "caricamento non riuscito su ${tag}: $($g.testo)" }
		foreach ($v in $gruppo) { $presenti[$v.nome] = $tag; Remove-Item (Join-Path $stage $v.nome) -Force }
		$i += $gruppo.Count
		"  caricati $i di $($nuovi.Count)"
	}
	Remove-Item $stage -Recurse -Force
	foreach ($v in $voci) {
		$u = if ($v.s -eq 0) { "" } else { "https://github.com/$Repo/releases/download/$($presenti[$v.nome])/$($v.nome)" }
		if ($v.s -gt 0 -and -not $presenti[$v.nome]) { throw "file non caricato: $($v.p)" }
		$v | Add-Member -NotePropertyName u -NotePropertyValue $u
	}
	New-Item -ItemType Directory -Force "$Sito\aggiornamenti" | Out-Null
	$uscita = "$Sito\aggiornamenti\manifest.json"
}

# 4) L'elenco.
$man = [ordered]@{
	versione = (Get-Date -Format "yyyy-MM-dd HH:mm")
	server = [ordered]@{ ip = $s.ip; port = [int]$s.port }
	riserva = $(if ($Riserva -and -not $Prova) { $RiservaUrl } else { "" })	# dove il launcher ripiega se GitHub non risponde
	file = @($voci | Sort-Object p | ForEach-Object { [ordered]@{ p = $_.p; s = $_.s; h = $_.h; u = $_.u } })
}
[IO.File]::WriteAllText($uscita, ($man | ConvertTo-Json -Depth 5 -Compress), (New-Object Text.UTF8Encoding $false))
"elenco scritto: $uscita (server $($s.ip):$($s.port))"
