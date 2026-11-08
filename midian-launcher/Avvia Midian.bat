@echo off
rem Avvia il launcher di Midian: controlla gli aggiornamenti del client, poi apre il gioco.
rem Se il launcher manca, apre direttamente il gioco (come prima).
if exist "%~dp0Launcher\aggiorna.ps1" (
  start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Launcher\aggiorna.ps1"
  exit /b
)
if exist "%~dp0UO\art.mul" if not exist "%~dp0UO\midian-fuso.txt" (
  xcopy /y /q "%~dp0ClassicUO\Data\Midian-fuso\*" "%~dp0UO\" >nul
  if exist "%~dp0UO\verdata.mul" move /y "%~dp0UO\verdata.mul" "%~dp0UO\verdata.mul.originale" >nul
  echo File fusi copiati da ClassicUO\Data\Midian-fuso. Cancella questo file per ricopiarli.> "%~dp0UO\midian-fuso.txt"
)
cd /d "%~dp0ClassicUO"
start "" ClassicUO.exe
