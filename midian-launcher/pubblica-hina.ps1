# Pubblica il client per il launcher eseguibile "Avvia Midian.exe" (Hina, Midian-ClassicUO #12).
# Parte dalla cartella del client in uso, come pubblica-aggiornamento.ps1, e:
#  1. ci copia il launcher (exe + libsodium.dll, Launcher\aggiorna.ps1) e scrive Launcher\server.txt (ip e porta);
#  2. prepara una cartella con solo i file da pubblicare (collegamenti fisici, niente copie), senza i dati personali;
#  3. Hina.Builder crea l'elenco firmato (manifest.json) e i pezzi compressi (chunks\) in $Uscita;
#  4. carica sul VPS (C:\Midian-Web\hina = http://45.13.235.243/hina/) i pezzi nuovi e per ultimo l'elenco.
# La chiave privata ($Chiave) firma l'elenco: resta su questo PC, mai in un repo o sul VPS.
# Uso: powershell -ExecutionPolicy Bypass -File pubblica-hina.ps1 [-SoloLocale]
#  -SoloLocale: prepara $Uscita senza caricare (per provare il launcher con --indirizzo http://127.0.0.1:porta/).
param(
	[string]$Client = "C:\Users\paolo\OneDrive\Desktop\Midian-ClientUo",
	[string]$Launcher = "C:\Midian All\Midian-ClassicUO\midian-launcher",
	[string]$Exe = "C:\Midian All\hina-strumenti\launcher",				# dotnet publish midian-launcher-exe -c Release -r win-x64 -o qui
	[string]$Builder = "C:\Midian All\hina-strumenti\builder\Hina.Builder.exe",
	[string]$Uscita = "C:\Midian All\hina-strumenti\uscita",
	[string]$Prep = "C:\Midian All\hina-strumenti\preparazione",
	[string]$Chiave = "C:\Midian All\chiavi\midian-hina.key.b64",
	[string]$Base = "http://45.13.235.243/hina/",
	[string]$Vps = "Administrator@45.13.235.243",
	[switch]$SoloLocale
)
$ErrorActionPreference = "Stop"

# Le stesse esclusioni di pubblica-aggiornamento.ps1, piu' i file del launcher eseguibile e di Hina.
$escludi = @(
	'^ClassicUO/Data/Profiles/', '^ClassicUO/Data/Client/JournalLogs/', '^ClassicUO/Logs/', '^ClassicUO/Crash\.log$',
	'^ClassicUO/originali-', '\.prec$', '^ClassicUO/Data/Plugins/Razor/Profiles/', '^ClassicUO/Data/Plugins/Razor/Macros/',
	'^UO/Desktop/', '^UO/Macros\.txt$', '^UO/Umacros\.txt$', '^UO/UOReport\d*\.log$', '^UO/uo\.cfg$', '^UO/midian-fuso\.txt$',
	'^ClassicUO/settings\.json$',
	'^ClassicUO/Data/Plugins/Razor/settings\.csv$', '^ClassicUO/Data/Plugins/Razor/counters\.xml$',
	'^ClassicUO/Data/Plugins/Razor/Scripts/', '^ClassicUO/Data/Client/MapsCache/',
	'^Launcher/stato\.json$', '\.scaricamento$', '^UO/verdata\.mul\.originale$',
	'^Launcher/stato-hina\.txt$', '^Launcher/launcher\.log', '^Launcher/errori\.log$', '\.vecchio$', '\.hina\.(tmp|bak)$', '^\.hina/',
	'\.pdb$'
)
foreach ($p in $Client, "$Exe\Avvia Midian.exe", "$Exe\libsodium.dll", $Builder, $Chiave) { if (-not (Test-Path $p)) { throw "manca: $p" } }
if (Get-Process ClassicUO -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Client\*" }) { "attenzione: ClassicUO e' aperto (i file si leggono soltanto)" }

# 1) Launcher nella cartella del client.
Copy-Item "$Exe\Avvia Midian.exe", "$Exe\libsodium.dll" $Client -Force
New-Item -ItemType Directory -Force "$Client\Launcher" | Out-Null
foreach ($n in 'aggiorna.ps1', 'sfondo.png') { Copy-Item "$Launcher\$n" "$Client\Launcher\$n" -Force }
Copy-Item "$Launcher\Avvia Midian.bat" "$Client\Avvia Midian.bat" -Force
$s = Get-Content "$Client\ClassicUO\settings.json" -Raw | ConvertFrom-Json
[IO.File]::WriteAllText("$Client\Launcher\server.txt", "$($s.ip) $($s.port)", (New-Object Text.UTF8Encoding $false))
# Impostazioni per chi installa da zero (il launcher le copia in ClassicUO\settings.json se manca): come nel pacchetto
# zip (crea-pacchetto.ps1), senza account.
$s.username = ""; $s.password = ""; $s.saveaccount = $false; $s.autologin = $false; $s.profilespath = ""; $s.last_server_name = ""
[IO.File]::WriteAllText("$Client\Launcher\settings-predefinite.json", ($s | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))

# 2) Cartella di preparazione con collegamenti fisici ai file da pubblicare.
if (Test-Path $Prep) { Remove-Item $Prep -Recurse -Force }
New-Item -ItemType Directory $Prep | Out-Null
$n = 0; $byte = 0
foreach ($f in Get-ChildItem $Client -Recurse -File -Force) {
	$rel = $f.FullName.Substring($Client.Length + 1).Replace('\', '/')
	if ($escludi | Where-Object { $rel -match $_ }) { continue }
	$d = Join-Path $Prep ($rel -replace '/', '\')
	$cart = Split-Path -Parent $d
	if (-not (Test-Path $cart)) { New-Item -ItemType Directory -Force $cart | Out-Null }
	try { New-Item -ItemType HardLink -Path $d -Target $f.FullName -ErrorAction Stop | Out-Null } catch { Copy-Item $f.FullName $d }
	$n++; $byte += $f.Length
}
"$n file da pubblicare ($([math]::Round($byte / 1MB)) MB)"

# 3) Elenco firmato e pezzi. I pezzi gia' presenti in $Uscita non si riscrivono (hanno il nome della loro impronta).
$versione = Get-Date -Format "yyyy.MM.dd.HHmm"
$inizio = Get-Date
New-Item -ItemType Directory -Force $Uscita | Out-Null
$vecchio = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $Builder build --input $Prep --out $Uscita --base $Base --sign-key $Chiave --version $versione --chunk 262144 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match 'error|warn|complete|Manifest' }
$codice = $LASTEXITCODE
$ErrorActionPreference = $vecchio
if ($codice) { throw "Hina.Builder non riuscito ($codice)" }
Remove-Item $Prep -Recurse -Force
"elenco: $Uscita\manifest.json (versione $versione)"
if ($SoloLocale) { return }

# 4) Sul VPS: prima i pezzi nuovi (quelli non ancora caricati, segnati in caricati.txt), poi l'elenco.
$chiaveSsh = "$env:USERPROFILE\.ssh\midian_vps"
$opz = @("-i", $chiaveSsh, "-o", "BatchMode=yes", "-o", "ConnectTimeout=20", "-o", "LogLevel=ERROR")
$registro = Join-Path $Uscita "caricati.txt"
$caricati = @{}; if (Test-Path $registro) { foreach ($r in Get-Content $registro) { if ($r) { $caricati[$r] = $true } } }
$tutti = Get-ChildItem "$Uscita\chunks" -Recurse -File | ForEach-Object { $_.FullName.Substring($Uscita.Length + 1).Replace('\', '/') }
$nuovi = @($tutti | Where-Object { -not $caricati.ContainsKey($_) })
"pezzi nuovi da caricare: $($nuovi.Count) di $($tutti.Count)"
if ($nuovi.Count -gt 0) {
	$lista = Join-Path $env:TEMP "midian-hina-lista.txt"
	[IO.File]::WriteAllLines($lista, $nuovi)
	$tar = Join-Path $env:TEMP "midian-hina.tar"; if (Test-Path $tar) { Remove-Item $tar -Force }
	& "$env:SystemRoot\System32\tar.exe" -cf $tar -C $Uscita -T $lista
	if ($LASTEXITCODE) { throw "archivio dei pezzi non creato" }
	& ssh @opz $Vps "cmd /c if not exist C:\Midian-Web\hina mkdir C:\Midian-Web\hina"
	& scp @opz $tar "${Vps}:C:/Midian-Web/hina/pezzi.tar"
	if ($LASTEXITCODE) { throw "copia dei pezzi sul VPS non riuscita" }
	& ssh @opz $Vps "cmd /c tar -xf C:\Midian-Web\hina\pezzi.tar -C C:\Midian-Web\hina && del /q C:\Midian-Web\hina\pezzi.tar"
	if ($LASTEXITCODE) { throw "estrazione dei pezzi sul VPS non riuscita" }
	Add-Content $registro $nuovi
	Remove-Item $tar, $lista -Force
}
& scp @opz "$Launcher\hina-web.config" "${Vps}:C:/Midian-Web/hina/web.config"
& scp @opz "$Uscita\manifest.json" "${Vps}:C:/Midian-Web/hina/manifest.nuovo"
if ($LASTEXITCODE) { throw "copia dell'elenco sul VPS non riuscita" }
& ssh @opz $Vps "cmd /c move /y C:\Midian-Web\hina\manifest.nuovo C:\Midian-Web\hina\manifest.json"
if ($LASTEXITCODE) { throw "elenco non sostituito sul VPS" }
"pubblicato: $Base (versione $versione)"
