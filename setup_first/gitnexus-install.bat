@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM GitNexus Full Local Setup (Windows)
REM - Install/verify GitNexus CLI
REM - Configure Claude MCP + skills + hooks
REM - Clone/update GitNexus repo
REM - Install/build frontend
REM - Start backend (4747) and frontend (5173)
REM - Validate each step with checks
REM ============================================================

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "TS=%%i"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "WORKSPACE_ROOT=%%~fI"
for %%I in ("%WORKSPACE_ROOT%\..") do set "PARENT_DIR=%%~fI"

if "%GITNEXUS_DIR%"=="" set "GITNEXUS_DIR=%PARENT_DIR%\GitNexus"
set "FRONTEND_DIR=%GITNEXUS_DIR%\gitnexus-web"
set "CLAUDE_HOME=%USERPROFILE%\.claude"
set "CLAUDE_GLOBAL=%USERPROFILE%\.claude.json"
set "LOG_FILE=%SCRIPT_DIR%\install-log-%TS%.txt"

set "HAS_WARN=0"

echo.
echo ============================================================
echo GitNexus Local Installer
echo ============================================================
echo Workspace: %WORKSPACE_ROOT%
echo GitNexus Dir: %GITNEXUS_DIR%
echo Log File: %LOG_FILE%
echo.

call :log INFO "Start installation"

REM ---------- Step 1: Preflight ----------
echo [1/9] Preflight checks...
call :require_cmd git || goto :fatal
call :require_cmd node || goto :fatal
call :require_cmd npm || goto :fatal
call :require_cmd npx || goto :fatal
call :ok "Preflight checks passed"

REM ---------- Step 2: Install/Verify gitnexus ----------
echo [2/9] Installing/verifying gitnexus CLI...
where gitnexus >nul 2>nul
if errorlevel 1 (
  call :log INFO "gitnexus not found, installing globally"
  call :run_or_fail "npm install -g gitnexus" "Install gitnexus globally" || goto :fatal
) else (
  call :log INFO "gitnexus already present"
)

set "GITNEXUS_CMD="
set "GITNEXUS_ANY="
for /f "delims=" %%p in ('where gitnexus 2^>nul') do (
  if not defined GITNEXUS_ANY set "GITNEXUS_ANY=%%p"
  if /I "%%~xp"==".cmd" set "GITNEXUS_CMD=%%p"
)
if not defined GITNEXUS_CMD set "GITNEXUS_CMD=%GITNEXUS_ANY%"
if not defined GITNEXUS_CMD goto :fatal_gitnexus

call gitnexus --version >>"%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :run_or_fail "npm install -g gitnexus" "Repair gitnexus install" || goto :fatal
  call gitnexus --version >>"%LOG_FILE%" 2>&1
  if errorlevel 1 goto :fatal_gitnexus
)
for /f "delims=" %%v in ('gitnexus --version 2^>nul') do set "GN_CLI_VER=%%v"
if not defined GN_CLI_VER set "GN_CLI_VER=unknown"
call :ok "gitnexus CLI ready (reported version: %GN_CLI_VER%)"

REM ---------- Step 3: Setup skills/hooks ----------
echo [3/9] Running gitnexus setup (skills/hooks)...
call :run_or_fail "gitnexus setup" "Run gitnexus setup" || goto :fatal

set "SKILL_COUNT=0"
if exist "%CLAUDE_HOME%\skills" (
  for /d %%D in ("%CLAUDE_HOME%\skills\gitnexus-*") do set /a SKILL_COUNT+=1
  if exist "%CLAUDE_HOME%\skills\gitnexus" (
    for /d %%D in ("%CLAUDE_HOME%\skills\gitnexus\*") do set /a SKILL_COUNT+=1
  )
)
if %SKILL_COUNT% GEQ 4 (
  call :ok "GitNexus skills detected (%SKILL_COUNT%)"
) else (
  call :warn "GitNexus skills count looks low (%SKILL_COUNT%). Continue anyway."
)

if exist "%CLAUDE_GLOBAL%" (
  findstr /I /C:"gitnexus" "%CLAUDE_GLOBAL%" >nul 2>&1
  if errorlevel 1 (
    call :warn "No gitnexus marker found in %CLAUDE_GLOBAL% yet"
  ) else (
    call :ok "Detected gitnexus entries in %CLAUDE_GLOBAL%"
  )
) else (
  call :warn "%CLAUDE_GLOBAL% not found yet"
)

REM ---------- Step 4: Configure Claude MCP ----------
echo [4/9] Configuring Claude MCP...
where claude >nul 2>nul
if errorlevel 1 (
  call :warn "claude command not found. Skipping MCP add."
  goto :after_mcp
)

call :has_gitnexus_mcp
if "%MCP_OK%"=="1" (
  call :ok "Claude MCP already has gitnexus"
) else (
  call :log INFO "Adding MCP server (user scope)"
  call claude mcp add -s user gitnexus -- npx gitnexus mcp >>"%LOG_FILE%" 2>&1
  if errorlevel 1 (
    call :log WARN "User scope add failed, retrying default scope"
    call claude mcp add gitnexus -- npx gitnexus mcp >>"%LOG_FILE%" 2>&1
  )
  call :has_gitnexus_mcp
  if "%MCP_OK%"=="1" (
    call :ok "Claude MCP configured for gitnexus"
  ) else (
    call :warn "Could not confirm MCP registration; run manually: claude mcp add gitnexus -- npx gitnexus mcp"
  )
)

:after_mcp

REM ---------- Step 5: Clone/Update GitNexus repo ----------
echo [5/9] Preparing GitNexus source repository...
if exist "%GITNEXUS_DIR%\.git" (
  call :log INFO "GitNexus repo exists; pulling latest"
  git -C "%GITNEXUS_DIR%" pull --ff-only >>"%LOG_FILE%" 2>&1
  if errorlevel 1 call :warn "git pull failed (continuing with local copy)"
) else (
  call :run_or_fail "git clone https://github.com/abhigyanpatwari/GitNexus.git ^"%GITNEXUS_DIR%^"" "Clone GitNexus repository" || goto :fatal
)

if not exist "%FRONTEND_DIR%\package.json" goto :fatal_frontend_missing
call :ok "GitNexus source ready"

REM ---------- Step 6: Frontend install ----------
echo [6/9] Installing frontend dependencies...
pushd "%FRONTEND_DIR%" >nul 2>&1
if errorlevel 1 goto :fatal_frontend_missing
call npm install >>"%LOG_FILE%" 2>&1
if errorlevel 1 (
  popd >nul 2>&1
  call :log ERROR "Failed: Install frontend dependencies"
  goto :fatal
)
popd >nul 2>&1
call :ok "Frontend dependencies installed"

REM ---------- Step 7: Frontend build ----------
echo [7/9] Building frontend...
pushd "%FRONTEND_DIR%" >nul 2>&1
if errorlevel 1 goto :fatal_frontend_missing
call npm run build >>"%LOG_FILE%" 2>&1
if errorlevel 1 (
  popd >nul 2>&1
  call :log ERROR "Failed: Build frontend"
  goto :fatal
)
popd >nul 2>&1
if not exist "%FRONTEND_DIR%\dist\index.html" goto :fatal_dist
call :ok "Frontend build verified"

REM ---------- Step 8: Start backend ----------
echo [8/9] Ensuring backend service on 4747...
call :check_port 4747
if "%PORT_LISTENING%"=="1" (
  call :describe_port_owner 4747
  call :warn "Port 4747 is already in use. !PORT_OWNER_DESC!"
  call :check_backend_up
  if "%BACKEND_UP%"=="1" (
    call :ok "Backend already reachable on 4747"
  ) else (
    call :warn "Port 4747 is occupied but backend is not responding yet"
  )
) else (
  start "gitnexus-backend" /min cmd /c "gitnexus serve"
  call :wait_for_backend 45
  if not "%BACKEND_UP%"=="1" (
    call :warn "Backend not up yet, retrying with npx gitnexus serve"
    start "gitnexus-backend-npx" /min cmd /c "npx -y gitnexus serve"
    call :wait_for_backend 45
  )
  if not "%BACKEND_UP%"=="1" (
    call :warn "Backend startup is slow; waiting a bit longer"
    call :wait_for_backend 30
  )
  if "%BACKEND_UP%"=="1" (
    call :ok "Backend started on 4747"
  ) else goto :fatal_backend
)

REM ---------- Step 9: Start frontend and verify HTTP ----------
echo [9/9] Ensuring frontend service on 5173...
call :check_port 5173
if "%PORT_LISTENING%"=="1" (
  call :describe_port_owner 5173
  call :warn "Port 5173 is already in use. !PORT_OWNER_DESC!"
  call :log INFO "Port 5173 already in use; validating HTTP"
) else (
  pushd "%FRONTEND_DIR%"
  powershell -NoProfile -Command "Start-Process -WindowStyle Minimized -WorkingDirectory '%FRONTEND_DIR%' -FilePath 'npx.cmd' -ArgumentList 'vite','preview','--host','localhost','--port','5173'" >nul 2>&1
  popd
  timeout /t 6 >nul
)

call :check_http "http://localhost:5173/"
if "%HTTP_OK%"=="1" (
  call :ok "Frontend HTTP check passed"
) else (
  call :warn "Preview startup check failed, trying dev fallback"
  pushd "%FRONTEND_DIR%"
  powershell -NoProfile -Command "Start-Process -WindowStyle Minimized -WorkingDirectory '%FRONTEND_DIR%' -FilePath 'npx.cmd' -ArgumentList 'vite','--host','localhost','--port','5173'" >nul 2>&1
  popd
  timeout /t 6 >nul
  call :check_http "http://localhost:5173/"
  if not "%HTTP_OK%"=="1" goto :fatal_frontend_http
  call :ok "Frontend HTTP check passed via dev fallback"
)

echo.
echo ============================================================
echo Setup completed successfully
echo ============================================================
echo Backend:  http://127.0.0.1:4747
echo Frontend: http://localhost:5173/
echo Log:      %LOG_FILE%
if "%HAS_WARN%"=="1" (
  echo Warnings: yes ^(review log^)
) else (
  echo Warnings: none
)
set "FRONTEND_OPEN_URL=http://localhost:5173/?server=http://127.0.0.1:4747"
start "" "%FRONTEND_OPEN_URL%"
call :log INFO "Opened frontend URL in default browser: %FRONTEND_OPEN_URL%"
echo.
call :wait_user_exit
exit /b 0

:has_gitnexus_mcp
set "MCP_OK=0"
for /f "delims=" %%L in ('claude mcp list 2^>nul ^| findstr /I "gitnexus"') do set "MCP_OK=1"
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

:wait_for_port
set "_WAIT_PORT=%~1"
set "_WAIT_SECS=%~2"
set "PORT_LISTENING=0"
for /l %%S in (1,1,%_WAIT_SECS%) do (
  call :check_port %_WAIT_PORT%
  if "!PORT_LISTENING!"=="1" exit /b 0
  timeout /t 1 >nul
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

:run_or_fail
set "_CMD=%~1"
set "_DESC=%~2"
call :log INFO "Running: %_DESC%"
cmd /c "%_CMD%" >>"%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :log ERROR "Failed: %_DESC%"
  echo [FAIL] %_DESC%
  echo See log: %LOG_FILE%
  exit /b 1
)
exit /b 0

:require_cmd
where %~1 >nul 2>nul
if errorlevel 1 (
  echo [FAIL] Missing required command: %~1
  call :log ERROR "Missing command: %~1"
  exit /b 1
)
call :log INFO "Found command: %~1"
exit /b 0

:warn
echo [WARN] %~1
call :log WARN "%~1"
set "HAS_WARN=1"
exit /b 0

:ok
echo [ OK ] %~1
call :log INFO "%~1"
exit /b 0

:log
echo [%date% %time%] [%~1] %~2>>"%LOG_FILE%"
exit /b 0

:fatal_gitnexus
echo [FATAL] gitnexus CLI still unavailable after install
call :log ERROR "gitnexus unavailable after install"
goto :fatal

:fatal_frontend_missing
echo [FATAL] Frontend package.json not found: %FRONTEND_DIR%\package.json
call :log ERROR "Missing frontend package.json"
goto :fatal

:fatal_dist
echo [FATAL] Build completed but dist\index.html not found
call :log ERROR "Missing dist\index.html"
goto :fatal

:fatal_backend
echo [FATAL] Backend did not start on port 4747
call :log ERROR "Backend start failed"
goto :fatal

:fatal_frontend_http
echo [FATAL] Frontend not reachable at http://localhost:5173/
call :log ERROR "Frontend HTTP check failed"
goto :fatal

:fatal
echo.
echo Setup failed. Check log:
echo %LOG_FILE%
echo.
call :wait_user_exit
exit /b 1

:wait_user_exit
if /I "%SKIP_PAUSE%"=="1" exit /b 0
echo Press any key to exit...
pause >nul
exit /b 0
