@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: Everything Claude Code - Complete Installation Script
:: Installs all plugins (Rules, Agents, Commands, Skills, Hooks)
:: and configures debug display for Claude Code.
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "SOURCE_DIR=%SCRIPT_DIR%.."
set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "BACKUP_DIR=%CLAUDE_DIR%\backups"
set "INSTALL_MARKER=%CLAUDE_DIR%\.ecc-installed"
set "SETTINGS_FILE=%CLAUDE_DIR%\settings.json"

:: Color codes for Windows 10+
for /f %%i in ('echo prompt $E^| cmd') do set "ESC=%%i"
set "GREEN=!ESC![92m"
set "YELLOW=!ESC![93m"
set "RED=!ESC![91m"
set "CYAN=!ESC![96m"
set "WHITE=!ESC![97m"
set "GRAY=!ESC![90m"
set "RESET=!ESC![0m"

:: Statistics
set "RULES_COUNT=0"
set "AGENTS_COUNT=0"
set "COMMANDS_COUNT=0"
set "SKILLS_COUNT=0"

echo.
echo !CYAN!================================================!RESET!
echo !CYAN!  Everything Claude Code - Installer!RESET!
echo !CYAN!================================================!RESET!
echo.

:: Check if source directory exists
if not exist "%SOURCE_DIR%\rules" (
    echo !RED![ERROR] Source directory not found: %SOURCE_DIR%\rules!RESET!
    echo Please ensure this script is in the setup_first directory.
    goto :error
)

:: Check if already installed
if exist "%INSTALL_MARKER%" (
    echo !YELLOW![INFO] ECC is already installed.!RESET!
    echo.
    type "%INSTALL_MARKER%" 2>nul
    echo.
    choice /c YN /m "Do you want to reinstall/update? (Y/N)"
    if errorlevel 2 (
        echo.
        echo !GREEN!Installation cancelled. Existing installation preserved.!RESET!
        goto :end
    )
    echo.
    echo !YELLOW!Reinstalling...!RESET!
)

:: Select languages to install
echo !CYAN!Select Rules to install:!RESET!
echo   1. All languages (recommended)
echo   2. TypeScript only
echo   3. Python only
echo   4. Go only
echo   5. Swift only
echo   6. Custom selection
echo.
choice /c 123456 /n /m "Enter choice (1-6): "
set "LANG_CHOICE=%errorlevel%"

set "INSTALL_TYPESCRIPT=0"
set "INSTALL_PYTHON=0"
set "INSTALL_GOLANG=0"
set "INSTALL_SWIFT=0"

if "%LANG_CHOICE%"=="1" (
    set "INSTALL_TYPESCRIPT=1"
    set "INSTALL_PYTHON=1"
    set "INSTALL_GOLANG=1"
    set "INSTALL_SWIFT=1"
) else if "%LANG_CHOICE%"=="2" (
    set "INSTALL_TYPESCRIPT=1"
) else if "%LANG_CHOICE%"=="3" (
    set "INSTALL_PYTHON=1"
) else if "%LANG_CHOICE%"=="4" (
    set "INSTALL_GOLANG=1"
) else if "%LANG_CHOICE%"=="5" (
    set "INSTALL_SWIFT=1"
) else if "%LANG_CHOICE%"=="6" (
    echo.
    choice /c YN /m "Install TypeScript rules? (Y/N)"
    if !errorlevel! equ 1 set "INSTALL_TYPESCRIPT=1"
    
    choice /c YN /m "Install Python rules? (Y/N)"
    if !errorlevel! equ 1 set "INSTALL_PYTHON=1"
    
    choice /c YN /m "Install Go rules? (Y/N)"
    if !errorlevel! equ 1 set "INSTALL_GOLANG=1"
    
    choice /c YN /m "Install Swift rules? (Y/N)"
    if !errorlevel! equ 1 set "INSTALL_SWIFT=1"
)

:: Ask about debug config
echo.
choice /c YN /m "Enable debug display (show [Skill: name], [Rule: name] in responses)? (Y/N)"
set "ENABLE_DEBUG=%errorlevel%"
if "%ENABLE_DEBUG%"=="1" (
    set "ENABLE_DEBUG=1"
) else (
    set "ENABLE_DEBUG=0"
)

echo.
echo !CYAN!========================================!RESET!
echo !CYAN!  Starting Installation...!RESET!
echo !CYAN!========================================!RESET!
echo.

:: Create directories
echo !YELLOW!Step 1/7: Creating directories...!RESET!
call :create_dir "%CLAUDE_DIR%"
call :create_dir "%BACKUP_DIR%"
call :create_dir "%CLAUDE_DIR%\rules"
call :create_dir "%CLAUDE_DIR%\rules\common"
call :create_dir "%CLAUDE_DIR%\agents"
call :create_dir "%CLAUDE_DIR%\commands"
call :create_dir "%CLAUDE_DIR%\skills"
call :create_dir "%CLAUDE_DIR%\scripts"
echo !GREEN!  Done.!RESET!
echo.

:: Backup existing files
echo !YELLOW!Step 2/7: Backing up existing files...!RESET!
if exist "%CLAUDE_DIR%\rules\common" (
    if exist "%BACKUP_DIR%\rules_common" rd /s /q "%BACKUP_DIR%\rules_common" 2>nul
    xcopy "%CLAUDE_DIR%\rules\common" "%BACKUP_DIR%\rules_common\" /E /I /Q /Y >nul 2>&1
    echo   Backed up: rules\common
)
if exist "%CLAUDE_DIR%\agents" (
    if exist "%BACKUP_DIR%\agents" rd /s /q "%BACKUP_DIR%\agents" 2>nul
    xcopy "%CLAUDE_DIR%\agents" "%BACKUP_DIR%\agents\" /E /I /Q /Y >nul 2>&1
    echo   Backed up: agents
)
if exist "%CLAUDE_DIR%\commands" (
    if exist "%BACKUP_DIR%\commands" rd /s /q "%BACKUP_DIR%\commands" 2>nul
    xcopy "%CLAUDE_DIR%\commands" "%BACKUP_DIR%\commands\" /E /I /Q /Y >nul 2>&1
    echo   Backed up: commands
)
if exist "%CLAUDE_DIR%\skills" (
    if exist "%BACKUP_DIR%\skills" rd /s /q "%BACKUP_DIR%\skills" 2>nul
    xcopy "%CLAUDE_DIR%\skills" "%BACKUP_DIR%\skills\" /E /I /Q /Y >nul 2>&1
    echo   Backed up: skills
)
if exist "%SETTINGS_FILE%" (
    set "BACKUP_FILE=%BACKUP_DIR%\settings.json.%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
    set "BACKUP_FILE=!BACKUP_FILE: =0!"
    copy "%SETTINGS_FILE%" "!BACKUP_FILE!" >nul 2>&1
    echo   Backed up: settings.json
)
echo !GREEN!  Done.!RESET!
echo.

:: Install Rules
echo !YELLOW!Step 3/7: Installing Rules...!RESET!

:: Common rules (always installed)
echo   Installing common rules...
xcopy "%SOURCE_DIR%\rules\common" "%CLAUDE_DIR%\rules\common\" /E /I /Q /Y >nul 2>&1
if !errorlevel! equ 0 (
    set /a RULES_COUNT+=5
    echo   !GREEN!OK!RESET! common rules
) else (
    echo   !YELLOW!Warning: common rules copy may have issues!RESET!
)

:: Language-specific rules
if "%INSTALL_TYPESCRIPT%"=="1" (
    if exist "%SOURCE_DIR%\rules\typescript" (
        call :create_dir "%CLAUDE_DIR%\rules\typescript"
        echo   Installing TypeScript rules...
        xcopy "%SOURCE_DIR%\rules\typescript" "%CLAUDE_DIR%\rules\typescript\" /E /I /Q /Y >nul 2>&1
        if !errorlevel! equ 0 (
            set /a RULES_COUNT+=5
            echo   !GREEN!OK!RESET! TypeScript rules
        )
    )
)

if "%INSTALL_PYTHON%"=="1" (
    if exist "%SOURCE_DIR%\rules\python" (
        call :create_dir "%CLAUDE_DIR%\rules\python"
        echo   Installing Python rules...
        xcopy "%SOURCE_DIR%\rules\python" "%CLAUDE_DIR%\rules\python\" /E /I /Q /Y >nul 2>&1
        if !errorlevel! equ 0 (
            set /a RULES_COUNT+=5
            echo   !GREEN!OK!RESET! Python rules
        )
    )
)

if "%INSTALL_GOLANG%"=="1" (
    if exist "%SOURCE_DIR%\rules\golang" (
        call :create_dir "%CLAUDE_DIR%\rules\golang"
        echo   Installing Go rules...
        xcopy "%SOURCE_DIR%\rules\golang" "%CLAUDE_DIR%\rules\golang\" /E /I /Q /Y >nul 2>&1
        if !errorlevel! equ 0 (
            set /a RULES_COUNT+=5
            echo   !GREEN!OK!RESET! Go rules
        )
    )
)

if "%INSTALL_SWIFT%"=="1" (
    if exist "%SOURCE_DIR%\rules\swift" (
        call :create_dir "%CLAUDE_DIR%\rules\swift"
        echo   Installing Swift rules...
        xcopy "%SOURCE_DIR%\rules\swift" "%CLAUDE_DIR%\rules\swift\" /E /I /Q /Y >nul 2>&1
        if !errorlevel! equ 0 (
            set /a RULES_COUNT+=5
            echo   !GREEN!OK!RESET! Swift rules
        )
    )
)

echo !GREEN!  Done (!RULES_COUNT! rule files installed)!RESET!
echo.

:: Install Agents
echo !YELLOW!Step 4/7: Installing Agents...!RESET!
if exist "%SOURCE_DIR%\agents" (
    for %%f in ("%SOURCE_DIR%\agents\*.md") do (
        copy "%%f" "%CLAUDE_DIR%\agents\" /Y >nul 2>&1
        echo   Installed: %%~nxf
        set /a AGENTS_COUNT+=1
    )
)
echo !GREEN!  Done (!AGENTS_COUNT! agents installed)!RESET!
echo.

:: Install Commands
echo !YELLOW!Step 5/7: Installing Commands...!RESET!
if exist "%SOURCE_DIR%\commands" (
    for %%f in ("%SOURCE_DIR%\commands\*.md") do (
        copy "%%f" "%CLAUDE_DIR%\commands\" /Y >nul 2>&1
        echo   Installed: %%~nxf
        set /a COMMANDS_COUNT+=1
    )
)
echo !GREEN!  Done (!COMMANDS_COUNT! commands installed)!RESET!
echo.

:: Install Skills
echo !YELLOW!Step 6/7: Installing Skills...!RESET!
if exist "%SOURCE_DIR%\skills" (
    for /d %%d in ("%SOURCE_DIR%\skills\*") do (
        if exist "%%d\SKILL.md" (
            set "SKILL_NAME=%%~nxd"
            call :create_dir "%CLAUDE_DIR%\skills\!SKILL_NAME!"
            copy "%%d\SKILL.md" "%CLAUDE_DIR%\skills\!SKILL_NAME!\" /Y >nul 2>&1
            echo   Installed: !SKILL_NAME!
            set /a SKILLS_COUNT+=1
        )
    )
)
echo !GREEN!  Done (!SKILLS_COUNT! skills installed)!RESET!
echo.

:: Install Scripts (for hooks)
echo !YELLOW!Installing Hook Scripts...!RESET!
if exist "%SOURCE_DIR%\scripts\hooks" (
    xcopy "%SOURCE_DIR%\scripts\hooks" "%CLAUDE_DIR%\scripts\" /E /I /Q /Y >nul 2>&1
    echo   Hook scripts installed.
)
if exist "%SOURCE_DIR%\scripts\lib" (
    xcopy "%SOURCE_DIR%\scripts\lib" "%CLAUDE_DIR%\scripts\lib\" /E /I /Q /Y >nul 2>&1
    echo   Library scripts installed.
)
echo !GREEN!  Done.!RESET!
echo.

:: Configure debug display
echo !YELLOW!Step 7/7: Configuring debug display...!RESET!
if "%ENABLE_DEBUG%"=="1" (
    echo   Enabling debug display...
    
    if exist "%SETTINGS_FILE%" (
        powershell -ExecutionPolicy Bypass -Command ^
            "$existing = Get-Content -Raw -Path '%SETTINGS_FILE%' | ConvertFrom-Json; " ^
            "$existing | Add-Member -NotePropertyName 'verbose' -NotePropertyValue $true -Force; " ^
            "$prompt = 'IMPORTANT: When you load or use any configuration component, explicitly state it:\n- [Skill: name] when a skill is activated\n- [Rule: name] when a rule is being followed\n- [Agent: name] when delegating to a subagent\n- [Hook: type] when a hook fires\n\nThis helps with debugging and transparency.'; " ^
            "$existing | Add-Member -NotePropertyName 'appendSystemPrompt' -NotePropertyValue $prompt -Force; " ^
            "$existing | ConvertTo-Json -Depth 10 | Set-Content -Path '%SETTINGS_FILE%' -Encoding UTF8"
        
        if !errorlevel! equ 0 (
            echo   !GREEN!Debug display enabled.!RESET!
        ) else (
            echo   !YELLOW!Warning: Failed to update settings.json!RESET!
        )
    ) else (
        powershell -ExecutionPolicy Bypass -Command ^
            "$settings = @{}; " ^
            "$settings.verbose = $true; " ^
            "$settings.appendSystemPrompt = 'IMPORTANT: When you load or use any configuration component, explicitly state it:\n- [Skill: name] when a skill is activated\n- [Rule: name] when a rule is being followed\n- [Agent: name] when delegating to a subagent\n- [Hook: type] when a hook fires\n\nThis helps with debugging and transparency.'; " ^
            "$settings | ConvertTo-Json -Depth 10 | Set-Content -Path '%SETTINGS_FILE%' -Encoding UTF8"
        
        if !errorlevel! equ 0 (
            echo   !GREEN!Debug display enabled (new settings.json created).!RESET!
        ) else (
            echo   !YELLOW!Warning: Failed to create settings.json!RESET!
        )
    )
) else (
    echo   Debug display skipped.
)
echo !GREEN!  Done.!RESET!
echo.

:: Create installation marker
echo !CYAN!Creating installation marker...!RESET!
echo Installed on: %date% %time% > "%INSTALL_MARKER%"
echo. >> "%INSTALL_MARKER%"
echo Components: >> "%INSTALL_MARKER%"
echo   - Rules: !RULES_COUNT! files >> "%INSTALL_MARKER%"
echo   - Agents: !AGENTS_COUNT! >> "%INSTALL_MARKER%"
echo   - Commands: !COMMANDS_COUNT! >> "%INSTALL_MARKER%"
echo   - Skills: !SKILLS_COUNT! >> "%INSTALL_MARKER%"
if "%INSTALL_TYPESCRIPT%"=="1" echo   - TypeScript rules: Yes >> "%INSTALL_MARKER%"
if "%INSTALL_PYTHON%"=="1" echo   - Python rules: Yes >> "%INSTALL_MARKER%"
if "%INSTALL_GOLANG%"=="1" echo   - Go rules: Yes >> "%INSTALL_MARKER%"
if "%INSTALL_SWIFT%"=="1" echo   - Swift rules: Yes >> "%INSTALL_MARKER%"
if "%ENABLE_DEBUG%"=="1" echo   - Debug display: Enabled >> "%INSTALL_MARKER%"

:: Success message
echo.
echo !GREEN!================================================!RESET!
echo !GREEN!  Installation Complete!!RESET!
echo !GREEN!================================================!RESET!
echo.
echo !WHITE!Installed Components:!RESET!
echo   !CYAN!Rules:!RESET!    !RULES_COUNT! files
echo   !CYAN!Agents:!RESET!   !AGENTS_COUNT!
echo   !CYAN!Commands:!RESET! !COMMANDS_COUNT!
echo   !CYAN!Skills:!RESET!   !SKILLS_COUNT!
if "%ENABLE_DEBUG%"=="1" (
    echo   !CYAN!Debug:!RESET!    Enabled
)
echo.
echo !WHITE!Installation Directory:!RESET!
echo   %CLAUDE_DIR%
echo.
if "%ENABLE_DEBUG%"=="1" (
    echo !WHITE!Debug Display:!RESET!
    echo   Claude will now show [Skill: name], [Rule: name], etc.
    echo.
)
echo !WHITE!Available Commands:!RESET!
echo   /plan, /tdd, /code-review, /build-fix, /security-scan
echo   /go-review, /python-review, /test-coverage, /orchestrate
echo.
echo !YELLOW!Next Steps:!RESET!
echo   1. Restart Claude Code to load new configuration
echo   2. Run /agents to see available agents
echo   3. Run /plan "your feature" to start planning
echo.
echo !GRAY!To uninstall, run: uninstall-ecc.bat!RESET!
echo.

goto :end

:: ============================================================
:: Subroutines
:: ============================================================

:create_dir
if not exist "%~1" (
    mkdir "%~1" >nul 2>&1
)
exit /b

:error
echo.
echo !RED!================================================!RESET!
echo !RED!  Installation Failed!!RESET!
echo !RED!================================================!RESET!
echo.
echo Please check:
echo   1. You have write permissions to %CLAUDE_DIR%
echo   2. Source files exist in %SOURCE_DIR%
echo   3. No files are locked by other processes
echo.
if exist "%BACKUP_DIR%" (
    echo Backups available in: %BACKUP_DIR%
)
echo.

:end
echo Press any key to exit...
pause >nul
endlocal
