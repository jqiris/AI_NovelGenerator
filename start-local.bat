@echo off
rem ============================================================
rem  AI Novel Generator - one-click START (local, no Docker)
rem  This window STAYS OPEN and shows live backend/frontend logs.
rem  CLOSE THIS WINDOW (X) = stop all services (data kept).
rem  Already-running services are skipped. Safe to re-run.
rem  stop-local.bat still works as an alternative stop button.
rem ============================================================
title AI Novel Generator - close this window to stop
setlocal
cd /d %~dp0

set "MONGOD=C:\Program Files\MongoDB\Server\9.0\bin\mongod.exe"
set "MONGOSH=%LOCALAPPDATA%\Programs\mongosh\mongosh.exe"
set "DBPATH=%~dp0local_data\db"
set "LOGPATH=%~dp0local_data\log\mongod.log"

if not exist "%MONGOD%" (
    echo [ERROR] MongoDB not found: %MONGOD%
    pause & exit /b 1
)
if not exist "%DBPATH%" mkdir "%DBPATH%"
if not exist "%~dp0local_data\log" mkdir "%~dp0local_data\log"

echo [1/3] MongoDB replica set rs0 (port 27018, log: local_data\log\mongod.log)...
netstat -ano | findstr ":27018 " | findstr LISTENING >nul
if %errorlevel%==0 (
    echo     already running, skip.
    goto :mongo_done
)
start /b "" "%MONGOD%" --dbpath "%DBPATH%" --logpath "%LOGPATH%" --logappend --replSet rs0 --port 27018 --bind_ip 127.0.0.1 --oplogSize 128
echo     starting, waiting for ready...
set "READY=0"
for /l %%i in (1,1,15) do (
    ping -n 2 127.0.0.1 >nul
    netstat -ano | findstr ":27018 " | findstr LISTENING >nul && set "READY=1" && goto :mongo_check
)
:mongo_check
if "%READY%"=="0" (
    echo [ERROR] MongoDB failed to start. See %LOGPATH%
    pause & exit /b 1
)
rem rs.initiate only on first use; harmless if already initialized
"%MONGOSH%" --port 27018 --quiet --eval "try{rs.status();print('    rs0 ready')}catch(e){rs.initiate({_id:'rs0',members:[{_id:0,host:'127.0.0.1:27018'}]});print('    rs0 initialized (new)')}" 2>nul
:mongo_done

rem backend/frontend pick these up through the inherited environment
set "NOVEL_GENERATOR_BACKEND_PORT=8200"
set "NOVEL_GENERATOR_MONGODB_URL=mongodb://127.0.0.1:27018/?replicaSet=rs0&directConnection=true"
set "NOVEL_GENERATOR_MONGO_DATABASE_NAME=novel_generator"
set "NEXT_PUBLIC_API_BASE=http://127.0.0.1:8200"

echo [2/3] Backend FastAPI (port 8200) - its logs stream into this window...
netstat -ano | findstr ":8200 " | findstr LISTENING >nul
if %errorlevel%==0 (
    echo     already running, skip.
) else (
    start /b "" "%~dp0.venv\Scripts\python.exe" "%~dp0main.py"
)

echo [3/3] Frontend Next.js (port 3300) - its logs stream into this window...
netstat -ano | findstr ":3300 " | findstr LISTENING >nul
if %errorlevel%==0 (
    echo     already running, skip.
) else (
    pushd "%~dp0frontend"
    start /b "" cmd /c "npm run start -- --hostname 127.0.0.1 --port 3300"
    popd
)

echo.
echo waiting for services (up to 30s)...
set "UP=0"
for /l %%i in (1,1,30) do (
    ping -n 2 127.0.0.1 >nul
    netstat -ano | findstr ":8200 " | findstr LISTENING >nul && netstat -ano | findstr ":3300 " | findstr LISTENING >nul && set "UP=1" && goto :ready
)
:ready
if "%UP%"=="1" (
    echo.
    echo ============================================
    echo   ALL UP: http://127.0.0.1:3300
    echo   Default provider: unsloth (8888) / ninfer (8889)
    echo   Keep this window open while writing.
    echo   CLOSE THIS WINDOW = stop all services.
    echo ============================================
) else (
    echo [WARN] Some services not ready, check logs above.
)
start "" http://127.0.0.1:3300

rem ---- keep the window open; closing it terminates all attached services ----
:monitor
ping -n 6 127.0.0.1 >nul
netstat -ano | findstr ":8200 " | findstr LISTENING >nul && netstat -ano | findstr ":3300 " | findstr LISTENING >nul && goto :monitor
echo.
echo [INFO] Services stopped. Safe to close this window now.
pause
