@echo off
setlocal
cd /d "%~dp0"

echo Solicitando permisos de administrador...
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    powershell -Command "Start-Process '%0' -Verb RunAs"
    exit /b
)

:: 1. Limpieza de procesos y puertos
echo Preparando entorno...
powershell -Command "Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"
if exist monitor.lock del monitor.lock

:: Limpiar datos antiguos para asegurar sincronización limpia
if exist "data\datos.json" del /q "data\datos.json"

:: 2. Iniciar HWiNFO64 (Se minimiza solo segun tus nuevos ajustes)
tasklist /fi "ImageName eq HWiNFO64.exe" /nh | find /i "HWiNFO64.exe" >nul
if "%errorlevel%" NEQ "0" (
    echo Iniciando HWiNFO64...
    start "" "C:\Program Files\HWiNFO64\HWiNFO64.exe"
)

:: 3. Iniciar Servidor y Colector de inmediato
echo Encendiendo Dashboard...
start "UlanziServer" /min python server.py
start "UlanziEngine" /min powershell -ExecutionPolicy Bypass -NoProfile -File "hwmonitor.ps1"

:: 4. Abrir Dashboard
timeout /t 2 /nobreak >nul
start http://localhost:8000/monitor.html

exit
