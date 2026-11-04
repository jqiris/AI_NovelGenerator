@echo off
rem ============================================================
rem  AI Novel Generator - one-click STOP (local, no Docker)
rem  Stops by port: frontend (3300) -> backend (8200) -> MongoDB (27018)
rem  Does NOT touch the system MongoDB service on 27017.
rem  Data is kept. Start again with start-local.bat
rem ============================================================
setlocal
cd /d %~dp0

echo [1/3] Stop frontend (port 3300)...
call :killport 3300

echo [2/3] Stop backend (port 8200)...
call :killport 8200

echo [3/3] Stop MongoDB replica set (port 27018, data kept)...
set "MONGOD=C:\Program Files\MongoDB\Server\9.0\bin\mongod.exe"
if exist "%MONGOD%" "%MONGOD%" --dbpath "%~dp0local_data\db" --shutdown >nul 2>&1
call :killport 27018

echo.
echo All stopped. Data stays in local_data\db and the MongoDB database.
echo Run start-local.bat again to bring everything back up.
endlocal
ping -n 4 127.0.0.1 >nul
exit /b 0

:killport
rem usage: call :killport PORT
set "FOUND="
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":%~1 " ^| findstr LISTENING') do (
    set "FOUND=1"
    taskkill /f /t /pid %%p >nul 2>&1 && echo     stopped PID %%p
)
if not defined FOUND echo     port %~1 not in use, skip.
goto :eof
