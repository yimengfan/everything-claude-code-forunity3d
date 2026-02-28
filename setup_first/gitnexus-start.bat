@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo.
echo ============================================================
echo Start GitNexus Local Services (No Install)
echo ============================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "WORKSPACE_ROOT=%%~fI"
for %%I in ("%WORKSPACE_ROOT%\..") do set "PARENT_DIR=%%~fI"

if "%GITNEXUS_DIR%"=="" set "GITNEXUS_DIR=%PARENT_DIR%\GitNexus"
set "FRONTEND_DIR=%GITNEXUS_DIR%\gitnexus-web"
set "HAS_WARN=0"

echo GitNexus Dir: %GITNEXUS_DIR%
echo Frontend Dir: %FRONTEND_DIR%
echo.

if not exist "%FRONTEND_DIR%\package.json" (
  echo [FATAL] Missing frontend package: %FRONTEND_DIR%\package.json
  echo Run gitnexus-install.bat first.
  call :wait_user_exit
  exit /b 1
)

if not exist "%FRONTEND_DIR%\dist\index.html" (
  echo [FATAL] Missing frontend build: %FRONTEND_DIR%\dist\index.html
  echo Run gitnexus-install.bat first.
  call :wait_user_exit
  exit /b 1
)

echo [1/2] Ensuring backend service on 4747...
call :check_port 4747
if "%PORT_LISTENING%"=="1" (
  call :describe_port_owner 4747
  call :warn "Port 4747 already in use. !PORT_OWNER_DESC!"
) else (
  powershell -NoProfile -Command "Start-Process -WindowStyle Minimized -FilePath 'gitnexus.cmd' -ArgumentList 'serve'" >nul 2>&1
  call :wait_for_backend 45
  if not "%BACKEND_UP%"=="1" (
    powershell -NoProfile -Command "Start-Process -WindowStyle Minimized -FilePath 'npx.cmd' -ArgumentList '-y','gitnexus','serve'" >nul 2>&1
    call :wait_for_backend 45
  )
)

call :check_backend_up
if not "%BACKEND_UP%"=="1" (
  echo [FATAL] Backend is not reachable at http://127.0.0.1:4747
  call :wait_user_exit
  exit /b 1
)
echo [ OK ] Backend is reachable

echo [2/2] Ensuring frontend service on 5173...
call :check_port 5173
if "%PORT_LISTENING%"=="1" (
  call :describe_port_owner 5173
  call :warn "Port 5173 already in use. !PORT_OWNER_DESC!"
) else (
  powershell -NoProfile -Command "Start-Process -WindowStyle Minimized -WorkingDirectory '%FRONTEND_DIR%' -FilePath 'npx.cmd' -ArgumentList 'vite','preview','--host','localhost','--port','5173'" >nul 2>&1
  timeout /t 6 >nul
)

call :check_http "http://localhost:5173/"
if not "%HTTP_OK%"=="1" (
  echo [FATAL] Frontend is not reachable at http://localhost:5173/
  call :wait_user_exit
  exit /b 1
)
echo [ OK ] Frontend is reachable

echo.
echo ============================================================
echo Services started successfully
echo ============================================================
echo Backend:  http://127.0.0.1:4747
echo Frontend: http://localhost:5173/
if "%HAS_WARN%"=="1" (
  echo Warnings: yes ^(review output^)
) else (
  echo Warnings: none
)

set "FRONTEND_OPEN_URL=http://localhost:5173/?server=http://127.0.0.1:4747"
start "" "%FRONTEND_OPEN_URL%"
echo Opened: %FRONTEND_OPEN_URL%
echo.
call :wait_user_exit
exit /b 0

:check_port
set "PORT_LISTENING=0"
set "CHECK_PORT=%~1"
powershell -NoProfile -Command "$p=[int]$env:CHECK_PORT; if (Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq $p }) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
  set "PORT_LISTENING=0"
) else (
  set "PORT_LISTENING=1"
)
exit /b 0

:check_http
set "HTTP_OK=0"
set "_URL=%~1"
powershell -NoProfile -Command "$u='%_URL%'; try { $r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 10; if (($r.StatusCode -ge 200) -and ($r.StatusCode -lt 400) -and ($r.Content -match 'GitNexus')) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
  set "HTTP_OK=0"
) else (
  set "HTTP_OK=1"
)
exit /b 0

:check_backend_up
set "BACKEND_UP=0"
powershell -NoProfile -Command "$c = New-Object Net.Sockets.TcpClient; try { $iar = $c.BeginConnect('127.0.0.1', 4747, $null, $null); if ($iar.AsyncWaitHandle.WaitOne(2000, $false)) { $c.EndConnect($iar); $c.Close(); exit 0 } else { $c.Close(); exit 1 } } catch { $c.Close(); exit 1 }" >nul 2>&1
if errorlevel 1 (
  set "BACKEND_UP=0"
) else (
  set "BACKEND_UP=1"
)
exit /b 0

:wait_for_backend
set "_WAIT_SECS=%~1"
set "BACKEND_UP=0"
for /l %%S in (1,1,%_WAIT_SECS%) do (
  call :check_backend_up
  if "!BACKEND_UP!"=="1" exit /b 0
  timeout /t 1 >nul
)
exit /b 0

:describe_port_owner
set "PORT_OWNER_DESC=Port %~1 owner unknown"
set "_PID="
set "_PNAME="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%~1 .*LISTENING"') do (
  if not defined _PID set "_PID=%%P"
)
if defined _PID (
  for /f "tokens=1 delims=," %%N in ('tasklist /FI "PID eq !_PID!" /FO CSV /NH') do (
    if not defined _PNAME set "_PNAME=%%~N"
  )
  if not defined _PNAME set "_PNAME=unknown"
  set "PORT_OWNER_DESC=PID=!_PID! Name=!_PNAME!"
) else (
  set "PORT_OWNER_DESC=No listener details found"
)
exit /b 0

:warn
echo [WARN] %~1
set "HAS_WARN=1"
exit /b 0

:wait_user_exit
if /I "%SKIP_PAUSE%"=="1" exit /b 0
echo Press any key to exit...
pause >nul
exit /b 0
