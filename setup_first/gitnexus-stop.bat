@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo.
echo ============================================================
echo Stop GitNexus Local Services
echo ============================================================
echo.

set "KILLED_COUNT=0"
set "WARN_COUNT=0"
set "KILLED_PIDS=;"

call :stop_port 4747 "GitNexus backend"
call :stop_port 5173 "GitNexus frontend"

echo.
echo ============================================================
echo Stop completed
echo ============================================================
echo Killed:   !KILLED_COUNT!
echo Warnings: !WARN_COUNT!
echo.
exit /b 0

:stop_port
set "_PORT=%~1"
set "_LABEL=%~2"
set "FOUND=0"
echo [CHECK] %_LABEL% on port %_PORT%...
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%_PORT% .*LISTENING"') do (
  set "FOUND=1"
  call :kill_pid %%P %_PORT%
)
if "!FOUND!"=="0" (
  echo [ OK ] Nothing listening on %_PORT%
)
exit /b 0

:kill_pid
set "_PID=%~1"
set "_PORT=%~2"
set "_PNAME=unknown"
if "%_PID%"=="0" exit /b 0

if not "!KILLED_PIDS:;%_PID%;=!"=="!KILLED_PIDS!" (
  echo [SKIP] PID %_PID% already handled
  exit /b 0
)

for /f "tokens=1 delims=," %%N in ('tasklist /FI "PID eq %_PID%" /FO CSV /NH') do (
  if not "%%~N"=="INFO: No tasks are running which match the specified criteria." set "_PNAME=%%~N"
)

echo [INFO] Stopping PID %_PID% (%_PNAME%) on port %_PORT%...
taskkill /PID %_PID% /T /F >nul 2>nul
tasklist /FI "PID eq %_PID%" 2>nul | findstr /R /C:" %_PID% " >nul
if errorlevel 1 (
  echo [ OK ] Stopped PID %_PID% (%_PNAME%)
  set /a KILLED_COUNT+=1
  set "KILLED_PIDS=!KILLED_PIDS!%_PID%;"
) else (
  echo [WARN] Failed to stop PID %_PID% (%_PNAME%)
  set /a WARN_COUNT+=1
)
exit /b 0
