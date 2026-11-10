# Launcher di Midian: controlla i file del client, scarica quelli cambiati e avvia ClassicUO.
# Si avvia da "Avvia Midian.bat" (cartella del client). Sta in <client>\Launcher\aggiorna.ps1.
#
# Come funziona:
#  - scarica l'elenco dei file (manifest.json) dal sito di Midian, in HTTPS;
#  - per ogni file confronta dimensione e impronta SHA-256 con quello sul disco (con una cache in stato.json,
#    cosi' i file non cambiati non si rileggono ogni volta);
#  - scarica solo i file diversi o mancanti e li accetta solo se l'impronta corrisponde;
#  - non tocca mai i file personali (account, profili, macro, Razor, journal): non sono nell'elenco;
#  - se nell'elenco cambia l'indirizzo del server, aggiorna solo ip e porta in ClassicUO\settings.json.
# Senza internet, o se qualcosa va storto, avvia comunque il gioco.
param(
	[string]$Manifest = "https://midianuo.github.io/Midian-Website/aggiornamenti/manifest.json",
	[switch]$Riavviato,		# gia' riavviato dopo l'aggiornamento del launcher stesso
	[switch]$NonAvviare		# per le prove: aggiorna ma non avvia il gioco
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Qui = Split-Path -Parent $MyInvocation.MyCommand.Path
$Radice = Split-Path -Parent $Qui
$FileStato = Join-Path $Qui "stato.json"

# Dal launcher eseguibile in poi (Midian-ClassicUO #12) aggiorna e avvia "Avvia Midian.exe" (Hina), se c'e'.
# Su Windows 7 e 8 l'exe non parte (.NET 10): resta questa script.
$exeNuovo = Join-Path $Radice "Avvia Midian.exe"
if ([Environment]::OSVersion.Version.Major -ge 10 -and (Test-Path $exeNuovo) -and -not $NonAvviare) {
	Start-Process -FilePath $exeNuovo -WorkingDirectory $Radice
	return
}

# --- Finestra -------------------------------------------------------------------------------------------
$form = New-Object Windows.Forms.Form
$form.Text = "Midian"
$form.ClientSize = New-Object Drawing.Size 640, 480
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"
$form.BackColor = [Drawing.Color]::Black
$sfondo = Join-Path $Qui "sfondo.png"
if (Test-Path $sfondo) { try { $form.BackgroundImage = [Drawing.Image]::FromFile($sfondo) } catch {} }
$icona = Join-Path $Radice "ClassicUO\ClassicUO.exe"
if (Test-Path $icona) { try { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon($icona) } catch {} }

$colScuro = [Drawing.Color]::FromArgb(40, 32, 20)
function NuovaEtichetta($x, $y, $w, $h, $testo, $font, $colore, $allinea) {
	$l = New-Object Windows.Forms.Label
	$l.SetBounds($x, $y, $w, $h); $l.Text = $testo; $l.Font = $font; $l.ForeColor = $colore
	$l.BackColor = [Drawing.Color]::Transparent; $l.TextAlign = $allinea
	$form.Controls.Add($l); return $l
}
$titolo = NuovaEtichetta 140 298 428 44 "MIDIAN" (New-Object Drawing.Font "Georgia", 24, ([Drawing.FontStyle]::Bold)) $colScuro "MiddleCenter"
$stato = NuovaEtichetta 150 346 408 22 "Controllo degli aggiornamenti..." (New-Object Drawing.Font "Georgia", 11) $colScuro "MiddleCenter"
$barra = New-Object Windows.Forms.ProgressBar
$barra.SetBounds(160, 374, 388, 18); $barra.Minimum = 0; $barra.Maximum = 1000
$form.Controls.Add($barra)
$dettaglio = NuovaEtichetta 150 396 408 18 "" (New-Object Drawing.Font "Segoe UI", 8) $colScuro "MiddleCenter"
$pulsante = New-Object Windows.Forms.Button
$pulsante.SetBounds(279, 416, 150, 24); $pulsante.Text = "Gioca senza aggiornare"; $pulsante.Font = New-Object Drawing.Font "Segoe UI", 8
$pulsante.FlatStyle = "Flat"; $pulsante.BackColor = [Drawing.Color]::FromArgb(70, 58, 40); $pulsante.ForeColor = [Drawing.Color]::FromArgb(240, 225, 185)
$pulsante.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(212, 175, 55); $pulsante.Cursor = [Windows.Forms.Cursors]::Hand
$pulsante.Add_Click({ $script:Salta = $true })
$form.Controls.Add($pulsante)
$script:Salta = $false
$script:GithubGiu = $false
$form.Add_FormClosing({ $script:Chiuso = $true })
$script:Chiuso = $false
$form.Show()
function Ridisegna { [Windows.Forms.Application]::DoEvents() }
function Stato($t, $d = "") { $stato.Text = $t; $dettaglio.Text = $d; Ridisegna }
Ridisegna

# --- Utilita' -------------------------------------------------------------------------------------------
function Sha256File($percorso) {
	$sha = [Security.Cryptography.SHA256]::Create()
	$fs = [IO.File]::OpenRead($percorso)
	try { return ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '').ToLower() } finally { $fs.Dispose(); $sha.Dispose() }
}
function Scarica($url, $dest, $dimensione, $etichetta) {
	# Scarica in $dest con la barra che avanza; funziona anche con file:/// (prove).
	$req = [Net.WebRequest]::Create($url)
	if ($req -is [Net.HttpWebRequest]) { $req.UserAgent = "MidianLauncher/1"; $req.Timeout = 30000; $req.ReadWriteTimeout = 60000 }
	$resp = $req.GetResponse()
	$in = $resp.GetResponseStream(); $out = [IO.File]::Create($dest)
	try {
		$buf = New-Object byte[] 65536; $letti = 0; $ultimo = [DateTime]::Now
		while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
			$out.Write($buf, 0, $n); $letti += $n
			if (([DateTime]::Now - $ultimo).TotalMilliseconds -gt 100) {
				$ultimo = [DateTime]::Now
				$p = if ($dimensione -gt 0) { [math]::Min(100, [int]($letti * 100 / $dimensione)) } else { 0 }
				$dettaglio.Text = "$etichetta  $p%"; Ridisegna
				if ($script:Salta -or $script:Chiuso) { throw "annullato" }
			}
		}
	} finally { $out.Dispose(); $in.Dispose(); $resp.Close() }
}
function AvviaGioco {
	if ($NonAvviare) { return }
	$exe = Join-Path $Radice "ClassicUO\ClassicUO.exe"
	Start-Process -FilePath $exe -WorkingDirectory (Join-Path $Radice "ClassicUO")
}
function Fusione {
	# Come faceva "Avvia Midian.bat": i file di gioco con le patch di verdata gia' fuse (ClassicUO legge male
	# i colori di verdata). Una volta sola, segnaposto UO\midian-fuso.txt.
	$uo = Join-Path $Radice "UO"; $fuso = Join-Path $Radice "ClassicUO\Data\Midian-fuso"
	if ((Test-Path "$uo\art.mul") -and -not (Test-Path "$uo\midian-fuso.txt") -and (Test-Path $fuso)) {
		Stato "Preparazione dei file di gioco..."
		Copy-Item "$fuso\*" $uo -Force
		if (Test-Path "$uo\verdata.mul") { Move-Item "$uo\verdata.mul" "$uo\verdata.mul.originale" -Force }
		Set-Content "$uo\midian-fuso.txt" "File fusi copiati da ClassicUO\Data\Midian-fuso. Cancella questo file per ricopiarli." -Encoding Ascii
	}
}

# --- Aggiornamento ---------------------------------------------------------------------------------------
$errori = 0; $scaricati = 0; $launcherCambiato = $false
try {
	Fusione
	# Un client aperto tiene bloccati i file. Prima il launcher saltava l'aggiornamento, ma chi chiudeva il gioco e
	# riapriva subito trovava ClassicUO ancora in chiusura e restava senza i file nuovi (Midian-ClassicUO #10).
	# Ora aspetta che si chiuda; "Gioca senza aggiornare" apre comunque un altro client.
	while (-not $script:Salta -and -not $script:Chiuso -and (Get-Process ClassicUO -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Radice\*" })) {
		Stato "Il gioco e' ancora aperto: chiudilo per aggiornare." "Oppure premi 'Gioca senza aggiornare' per aprire un altro client."
		Start-Sleep -Milliseconds 500
	}
	if ($script:Chiuso) { return }
	if ($script:Salta) { AvviaGioco; $form.Close(); return }

	Stato "Controllo degli aggiornamenti..."
	$sep = if ($Manifest.Contains("?")) { "&" } else { "?" }
	$url = if ($Manifest -match '^https?://') { "$Manifest${sep}t=$([DateTime]::UtcNow.Ticks)" } else { $Manifest }
	$tmpMan = Join-Path $env:TEMP ("midian-manifest-" + [guid]::NewGuid().ToString("N") + ".json")
	Scarica $url $tmpMan 0 "elenco dei file"
	$man = [IO.File]::ReadAllText($tmpMan, [Text.Encoding]::UTF8) | ConvertFrom-Json
	Remove-Item $tmpMan -Force

	# Cache delle impronte: percorso -> dimensione, data di modifica, sha256.
	$cache = @{}
	if (Test-Path $FileStato) {
		try { (Get-Content $FileStato -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value } } catch {}
	}

	# 1) Quali file mancano o sono diversi.
	$daFare = New-Object Collections.ArrayList
	$tot = @($man.file).Count; $i = 0
	foreach ($f in $man.file) {
		$i++
		if ($script:Salta -or $script:Chiuso) { break }
		if ($i % 20 -eq 0) { $barra.Value = [int]($i * 1000 / $tot); Stato "Controllo dei file ($i di $tot)..." }
		if ($f.p -match '\.\.|^[\\/]|:') { continue }	# solo percorsi dentro la cartella del client
		$loc = Join-Path $Radice ($f.p -replace '/', '\')
		$uguale = $false
		if (Test-Path -LiteralPath $loc) {
			$fi = Get-Item -LiteralPath $loc
			if ($fi.Length -eq [long]$f.s) {
				$t = $fi.LastWriteTimeUtc.Ticks; $c = $cache[$f.p]
				if ($c -and [long]$c.s -eq $fi.Length -and [long]$c.t -eq $t) { $h = $c.h }
				else { $h = Sha256File $loc; $cache[$f.p] = [pscustomobject]@{ s = $fi.Length; t = $t; h = $h } }
				$uguale = ($h -eq $f.h)
			}
		}
		if (-not $uguale) { [void]$daFare.Add($f) }
	}

	# 2) Scarica quelli da aggiornare.
	if ($daFare.Count -gt 0 -and -not $script:Salta -and -not $script:Chiuso) {
		$totByte = ($daFare | Measure-Object -Property s -Sum).Sum
		$mb = [math]::Round($totByte / 1MB, 1)
		$fatti = 0
		foreach ($f in $daFare) {
			if ($script:Salta -or $script:Chiuso) { break }
			$fatti++
			$barra.Value = [int](($fatti - 1) * 1000 / $daFare.Count)
			Stato "Aggiornamento: file $fatti di $($daFare.Count) ($mb MB in tutto)" ($f.p)
			$loc = Join-Path $Radice ($f.p -replace '/', '\')
			$cart = Split-Path -Parent $loc
			if (-not (Test-Path $cart)) { New-Item -ItemType Directory -Force $cart | Out-Null }
			$tmp = "$loc.scaricamento"
			try {
				# Prima GitHub, poi la copia di riserva sul VPS (se l'elenco la indica), 2 tentativi ciascuno:
				# un intoppo di rete o un guasto di GitHub non devono fermare l'aggiornamento. L'impronta viene
				# dall'elenco in HTTPS, quindi anche il file della riserva e' accettato solo se identico.
				$fonti = @($f.u)
				if ($man.riserva -and $f.u) {
					$ris = $man.riserva + ($f.u -split '/')[-1]
					# GitHub ha gia' fallito su un file: si parte dalla riserva, senza riaspettarlo.
					if ($script:GithubGiu) { $fonti = @($ris, $f.u) } else { $fonti += $ris }
				}
				$tentativi = New-Object Collections.ArrayList
				foreach ($fonte in $fonti) { [void]$tentativi.Add($fonte); [void]$tentativi.Add($fonte) }
				for ($tent = 0; $tent -lt $tentativi.Count; $tent++) {
					try {
						if ([long]$f.s -eq 0) { [IO.File]::WriteAllBytes($tmp, [byte[]]@()) }	# file vuoto: niente da scaricare
						else { Scarica $tentativi[$tent] $tmp ([long]$f.s) ([IO.Path]::GetFileName($f.p)) }
						$h = Sha256File $tmp
						if ($h -ne $f.h -or (Get-Item $tmp).Length -ne [long]$f.s) { throw "impronta diversa" }
						break
					} catch {
						if ("$_" -eq "annullato" -or $tent -eq $tentativi.Count - 1) { throw }
						Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
						if ($tentativi[$tent] -eq $f.u -and $tentativi[$tent + 1] -ne $f.u) { $script:GithubGiu = $true }
						$dove = if ($tentativi[$tent + 1] -ne $f.u) { "server di riserva" } else { "GitHub" }
						$dettaglio.Text = "Nuovo tentativo dal $dove..."; Ridisegna; Start-Sleep -Seconds 2
					}
				}
				Move-Item -LiteralPath $tmp -Destination $loc -Force
				$fi = Get-Item -LiteralPath $loc
				$cache[$f.p] = [pscustomobject]@{ s = $fi.Length; t = $fi.LastWriteTimeUtc.Ticks; h = $h }
				$scaricati++
				if ($f.p -eq 'Launcher/aggiorna.ps1') { $launcherCambiato = $true }
			} catch {
				if ("$_" -eq "annullato") { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; break }
				$errori++
				try { Add-Content -Path (Join-Path $Qui "errori.log") -Value ("{0}  {1}: {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $f.p, $_.Exception.Message) } catch {}
				Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
			}
		}
	}

	# 3) Indirizzo del server.
	if ($man.server -and $man.server.ip) {
		$set = Join-Path $Radice "ClassicUO\settings.json"
		if (Test-Path $set) {
			$s = Get-Content $set -Raw | ConvertFrom-Json
			if ($s.ip -ne $man.server.ip -or [int]$s.port -ne [int]$man.server.port) {
				$s.ip = $man.server.ip; $s.port = [int]$man.server.port
				[IO.File]::WriteAllText($set, ($s | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
			}
		}
	}

	# Cache salvata.
	try {
		$o = New-Object PSObject
		foreach ($k in $cache.Keys) { $o | Add-Member -NotePropertyName $k -NotePropertyValue $cache[$k] }
		[IO.File]::WriteAllText($FileStato, ($o | ConvertTo-Json -Depth 3 -Compress), (New-Object Text.UTF8Encoding $false))
	} catch {}

	$barra.Value = 1000
	if ($launcherCambiato -and -not $Riavviato) {
		# Il launcher stesso e' cambiato: riparte con la versione nuova (una volta sola).
		Stato "Launcher aggiornato, riavvio..."
		$arg = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$Qui\aggiorna.ps1`"", '-Riavviato')
		if ($NonAvviare) { $arg += '-NonAvviare' }
		if ($Manifest -ne "https://midianuo.github.io/Midian-Website/aggiornamenti/manifest.json") { $arg += @('-Manifest', "`"$Manifest`"") }
		Start-Process powershell.exe -ArgumentList $arg
		$form.Close(); return
	}
	if ($errori -gt 0) {
		[Windows.Forms.MessageBox]::Show("Non sono riuscito a scaricare $errori file. Il gioco parte lo stesso: riprova piu' tardi, o riscarica il pacchetto dal sito se qualcosa non funziona.", "Midian", "OK", "Warning") | Out-Null
	}
	if ($script:Chiuso) { return }
	if ($scaricati -gt 0) { Stato "Aggiornato ($scaricati file). Buon gioco!" } else { Stato "Il gioco e' aggiornato. Buon gioco!" }
	Start-Sleep -Milliseconds 700
	AvviaGioco
} catch {
	if (-not $script:Chiuso) {
		Stato "Impossibile controllare gli aggiornamenti: avvio il gioco." "$($_.Exception.Message)"
		Start-Sleep -Milliseconds 1500
		AvviaGioco
	}
} finally {
	if (-not $form.IsDisposed) { $form.Close() }
}
