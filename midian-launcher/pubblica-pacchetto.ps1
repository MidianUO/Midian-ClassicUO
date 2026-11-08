# Pubblica il pacchetto d'installazione del client ("Installazione UOMidian.zip", fatto con crea-pacchetto.ps1):
#  - sulla Release "client" di MidianUO/Midian-Website (asset Installazione-UOMidian.zip);
#  - sulla copia di riserva del VPS (http://45.13.235.243/Installazione-UOMidian.zip).
# Stampa l'impronta SHA-256 da scrivere nella pagina Download.
# Uso: powershell -ExecutionPolicy Bypass -File pubblica-pacchetto.ps1 [-SoloRiserva]
param(
	[string]$Zip = "C:\Midian All\Installazione UOMidian.zip",
	[string]$Repo = "MidianUO/Midian-Website",
	[string]$Riserva = "Administrator@45.13.235.243",
	[switch]$SoloRiserva
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Zip)) { throw "Pacchetto non trovato: $Zip" }
$h = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLower()
$st = Join-Path $env:TEMP "midian-pacchetto"; if (Test-Path $st) { Remove-Item $st -Recurse -Force }; New-Item -ItemType Directory $st | Out-Null
$nome = Join-Path $st "Installazione-UOMidian.zip"; Copy-Item $Zip $nome

if (-not $SoloRiserva) {
	$ok = $false
	for ($r = 0; $r -lt 4 -and -not $ok; $r++) {
		$v = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
		& gh.exe release upload client $nome -R $Repo --clobber 2>&1 | Out-Null; $ok = ($LASTEXITCODE -eq 0)
		$ErrorActionPreference = $v
		if (-not $ok) { Start-Sleep 20 }
	}
	if ($ok) { "GitHub: caricato" } else { "GitHub: NON caricato (riprova piu' tardi)" }
}

$opz = @("-i", "$env:USERPROFILE\.ssh\midian_vps", "-o", "BatchMode=yes", "-o", "ConnectTimeout=20", "-o", "LogLevel=ERROR")
& scp @opz $nome "${Riserva}:C:/Midian-Web/Installazione-UOMidian.zip.nuovo"
if ($LASTEXITCODE) { throw "copia sul VPS non riuscita" }
& ssh @opz $Riserva "cmd /c move /y C:\Midian-Web\Installazione-UOMidian.zip.nuovo C:\Midian-Web\Installazione-UOMidian.zip >nul"
if ($LASTEXITCODE) { throw "sostituzione sul VPS non riuscita" }
"riserva: caricato"
Remove-Item $st -Recurse -Force
"SHA-256 del pacchetto: $h"
