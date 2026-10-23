@echo off
setlocal enabledelayedexpansion
title VS Code Remote-SSH Setup

echo.
echo ============================================================
echo   VS Code Remote-SSH - Windows Setup
echo   Works on Windows 7, 8, 8.1, 10, 11
echo ============================================================
echo.

set "SSH_DIR=%USERPROFILE%\.ssh"
set "CONFIG_FILE=%SSH_DIR%\config"
set "KEY_FILE=%SSH_DIR%\termux_key"
set "PUB_FILE=%SSH_DIR%\termux_key.pub"

REM ============================================================
REM [1/9] Detect Windows version
REM ============================================================
echo [1/9] Detecting Windows version...
set "WIN_VER="
set "IS_LEGACY=0"

ver | findstr /C:"Version 6.1." >nul
if not errorlevel 1 (
    set "WIN_VER=7"
    set "IS_LEGACY=1"
    goto :ver_detected
)
ver | findstr /C:"Version 6.2." >nul
if not errorlevel 1 (
    set "WIN_VER=8"
    set "IS_LEGACY=1"
    goto :ver_detected
)
ver | findstr /C:"Version 6.3." >nul
if not errorlevel 1 (
    set "WIN_VER=8.1"
    set "IS_LEGACY=1"
    goto :ver_detected
)
ver | findstr /C:"Version 10.0." >nul
if not errorlevel 1 (
    set "WIN_VER=10+"
    set "IS_LEGACY=0"
    goto :ver_detected
)
echo   [WARN] Unrecognized Windows version.
ver
choice /C YN /M "  Continue anyway"
if errorlevel 2 exit /b 1
set "WIN_VER=unknown"
set "IS_LEGACY=1"
:ver_detected
echo   [OK] Windows %WIN_VER%.

REM ============================================================
REM [2/9] VxKex NEXT (legacy only)
REM ============================================================
echo [2/9] Checking VxKex NEXT...
if "%IS_LEGACY%"=="1" (
    set "VXKEX_FOUND=0"
    if exist "C:\Program Files\VxKex" set "VXKEX_FOUND=1"
    if exist "C:\Program Files (x86)\VxKex" set "VXKEX_FOUND=1"
    if exist "C:\Program Files\VxKex NEXT" set "VXKEX_FOUND=1"
    if exist "C:\Program Files (x86)\VxKex NEXT" set "VXKEX_FOUND=1"
    if "!VXKEX_FOUND!"=="0" (
        echo   [WARN] VxKex NEXT not found.
        echo.
        echo   VS Code 1.143+ requires VxKex NEXT on Windows 7, 8, and 8.1.
        echo   Download: https://github.com/YuZhouRen86/VxKex-NEXT/releases
        echo   Install the latest KexSetup_Release_*.exe.
        echo.
        choice /C YN /M "  Continue anyway"
        if errorlevel 2 exit /b 1
    ) else (
        echo   [OK] VxKex NEXT found.
    )
) else (
    echo   [SKIP] VxKex NEXT not needed on Windows %WIN_VER%.
)

REM ============================================================
REM [3/9] Locate SSH client
REM ============================================================
echo [3/9] Locating SSH client...
set "SSH_EXE="

if "%IS_LEGACY%"=="1" (
    if exist "C:\Program Files\OpenSSH\ssh.exe" (
        "C:\Program Files\OpenSSH\ssh.exe" -V 2>&1 | findstr /C:"7.7" >nul
        if not errorlevel 1 (
            set "SSH_EXE=C:\Program Files\OpenSSH\ssh.exe"
            echo   [OK] OpenSSH 7.7 found.
        )
    )
    if not defined SSH_EXE (
        echo   [ERROR] OpenSSH 7.7 required on Windows %WIN_VER%.
        echo.
        echo   Download:
        echo   https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.7.2.0p1-Beta/OpenSSH-Win64.zip
        echo   Extract to: C:\Program Files\OpenSSH\
        echo.
        pause
        exit /b 1
    )
) else (
    if exist "%WINDIR%\System32\OpenSSH\ssh.exe" (
        set "SSH_EXE=%WINDIR%\System32\OpenSSH\ssh.exe"
        echo   [OK] Built-in OpenSSH found.
    )
    if not defined SSH_EXE (
        if exist "C:\Program Files\OpenSSH\ssh.exe" (
            set "SSH_EXE=C:\Program Files\OpenSSH\ssh.exe"
            echo   [OK] OpenSSH found at C:\Program Files\OpenSSH\.
        )
    )
    if not defined SSH_EXE (
        echo   [ERROR] No SSH client found.
        echo.
        echo   Windows 10 and 11 normally include OpenSSH at:
        echo   %WINDIR%\System32\OpenSSH\
        echo.
        echo   If missing, add it via:
        echo   Settings - Apps - Optional Features - OpenSSH Client
        echo.
        pause
        exit /b 1
    )
)

REM ============================================================
REM [4/9] Locate ssh-keygen
REM ============================================================
echo [4/9] Locating ssh-keygen...
set "KEYGEN_EXE="

if exist "C:\Program Files\Git\usr\bin\ssh-keygen.exe" (
    set "KEYGEN_EXE=C:\Program Files\Git\usr\bin\ssh-keygen.exe"
    echo   [OK] Git ssh-keygen found.
)
if not defined KEYGEN_EXE (
    if "%IS_LEGACY%"=="1" (
        echo   [ERROR] Git for Windows required on Windows %WIN_VER%.
        echo   Download: https://git-scm.com/download/win
        pause
        exit /b 1
    )
    if exist "%WINDIR%\System32\OpenSSH\ssh-keygen.exe" (
        set "KEYGEN_EXE=%WINDIR%\System32\OpenSSH\ssh-keygen.exe"
        echo   [OK] Built-in ssh-keygen found.
    )
)
if not defined KEYGEN_EXE (
    echo   [ERROR] ssh-keygen not found.
    pause
    exit /b 1
)

REM ============================================================
REM [5/9] Locate VS Code
REM ============================================================
echo [5/9] Locating VS Code...
set "VSCODE_DIR="
set "VSCODE_CLI="

for %%D in (
    "F:\VSCode-New-Portable"
    "C:\Program Files\Microsoft VS Code"
    "C:\Program Files (x86)\Microsoft VS Code"
    "%LOCALAPPDATA%\Programs\Microsoft VS Code"
) do (
    if exist "%%~D\bin\code.cmd" (
        set "VSCODE_DIR=%%~D"
        set "VSCODE_CLI=%%~D\bin\code.cmd"
        goto :vscode_found
    )
)

echo   [ERROR] VS Code not found in common locations.
set /p "VSCODE_EXE=  Path to Code.exe: "
if not exist "!VSCODE_EXE!" (
    echo   [ERROR] File not found.
    pause
    exit /b 1
)
for %%F in ("!VSCODE_EXE!") do set "VSCODE_DIR=%%~dpF"
set "VSCODE_DIR=!VSCODE_DIR:~0,-1!"
set "VSCODE_CLI=!VSCODE_DIR!\bin\code.cmd"
:vscode_found
echo   [OK] VS Code: !VSCODE_DIR!

REM ============================================================
REM [6/9] Phone details
REM ============================================================
echo.
echo [6/9] Phone details.
echo        On the phone, in Termux, run:
echo          getprop dhcp.wlan0.ipaddress
echo          whoami
echo.
set /p "PHONE_IP=  Phone IP: "
echo %PHONE_IP% | findstr /R /C:"^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo   [ERROR] Invalid IP format.
    pause
    exit /b 1
)
set /p "PHONE_USER=  Termux username: "
if "!PHONE_USER!"=="" (
    echo   [ERROR] Username required.
    pause
    exit /b 1
)

REM ============================================================
REM [7/9] Connectivity test
REM ============================================================
echo.
echo [7/9] Testing connectivity to %PHONE_IP%...
ping -n 1 -w 2000 %PHONE_IP% >nul
if errorlevel 1 (
    echo   [ERROR] Cannot reach %PHONE_IP%.
    echo.
    echo   Check:
    echo     - Phone and laptop are on the same WiFi network.
    echo     - Phone IP is correct (getprop dhcp.wlan0.ipaddress).
    echo     - Phone firewall is not blocking.
    echo.
    pause
    exit /b 1
)
echo   [OK] Phone reachable.

REM ============================================================
REM [8/9] SSH key and config
REM ============================================================
echo.
echo [8/9] SSH key and config...
if not exist "%SSH_DIR%" mkdir "%SSH_DIR%"

if exist "%KEY_FILE%" (
    echo   [OK] Key already exists.
) else (
    "!KEYGEN_EXE!" -t rsa -b 2048 -f "%KEY_FILE%" -N "" -q
    if errorlevel 1 (
        echo   [ERROR] Key generation failed.
        pause
        exit /b 1
    )
    echo   [OK] Key generated.
)

findstr /C:"Host termux-phone" "%CONFIG_FILE%" >nul 2>&1
if errorlevel 1 (
    echo.>> "%CONFIG_FILE%"
    echo Host termux-phone>> "%CONFIG_FILE%"
    echo     HostName %PHONE_IP%>> "%CONFIG_FILE%"
    echo     Port 8022>> "%CONFIG_FILE%"
    echo     User %PHONE_USER%>> "%CONFIG_FILE%"
    echo     IdentityFile ~/.ssh/termux_key>> "%CONFIG_FILE%"
    echo     PreferredAuthentications publickey>> "%CONFIG_FILE%"
    echo     IdentitiesOnly yes>> "%CONFIG_FILE%"
    echo   [OK] Added termux-phone to %CONFIG_FILE%.
) else (
    echo   [SKIP] termux-phone already in config, not modified.
)

REM ============================================================
REM [9/9] Remote-SSH extension and settings.json
REM ============================================================
echo.
echo [9/9] Installing Remote-SSH extension and configuring settings...

if exist "!VSCODE_CLI!" (
    "!VSCODE_CLI!" --install-extension ms-vscode-remote.remote-ssh --force >nul 2>&1
    if errorlevel 1 (
        echo   [WARN] Extension install may have failed.
        echo          Install manually from the Extensions panel: Remote - SSH.
    ) else (
        echo   [OK] Remote-SSH installed.
    )
) else (
    echo   [WARN] VS Code CLI not found. Install Remote-SSH manually.
)

set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
if not exist "!PYTHON!" set "PYTHON=python"

set "PSETTINGS=%TEMP%\vscode_merge_settings.py"
> "!PSETTINGS!" (
    echo import json, os, shutil
    echo p = os.path.join^(os.environ['APPDATA'], 'Code', 'User', 'settings.json'^)
    echo os.makedirs^(os.path.dirname^(p^), exist_ok=True^)
    echo if os.path.exists^(p^):
    echo     shutil.copy^(p, p + '.bak'^)
    echo     with open^(p, 'r', encoding='utf-8'^) as f:
    echo         d = json.load^(f^)
    echo else:
    echo     d = {}
    echo d['remote.SSH.path'] = r'!SSH_EXE!'
    echo d['remote.SSH.configFile'] = os.path.join^(os.environ['USERPROFILE'], '.ssh', 'config'^)
    echo if '!IS_LEGACY!' == '1':
    echo     d['remote.SSH.useLocalServer'] = True
    echo     d['remote.SSH.useExecServer'] = False
    echo     d['remote.SSH.useFlock'] = False
    echo d.setdefault^('remote.SSH.defaultExtensions', []^)
    echo if 'llvm-vs-code-extensions.vscode-clangd' not in d['remote.SSH.defaultExtensions']:
    echo     d['remote.SSH.defaultExtensions'].append^('llvm-vs-code-extensions.vscode-clangd'^)
    echo with open^(p, 'w', encoding='utf-8'^) as f:
    echo     json.dump^(d, f, indent=4^)
)

"!PYTHON!" "!PSETTINGS!" >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Could not auto-update settings.json.
    echo          Add manually:
    echo.
    echo          "remote.SSH.path": "!SSH_EXE!"
    echo          "remote.SSH.configFile": "C:\\Users\\%USERNAME%\\.ssh\\config"
    if "%IS_LEGACY%"=="1" (
        echo          "remote.SSH.useLocalServer": true
        echo          "remote.SSH.useExecServer": false
        echo          "remote.SSH.useFlock": false
    )
    echo.
) else (
    echo   [OK] settings.json updated (backup saved as settings.json.bak).
)
del "!PSETTINGS!" >nul 2>&1

REM ============================================================
REM VxKex NEXT reminder (legacy only)
REM ============================================================
if "%IS_LEGACY%"=="1" (
    echo.
    echo ============================================================
    echo   IMPORTANT: Enable VxKex NEXT on Code.exe
    echo ============================================================
    echo   1. Right-click: !VSCODE_DIR!\Code.exe
    echo   2. Properties
    echo   3. VxKex NEXT tab
    echo   4. Check "Enable VxKex for this program"
    echo   5. Set "Report a different version of Windows" to Windows 10
    echo   6. OK
    echo.
)

REM ============================================================
REM Public key
REM ============================================================
echo ============================================================
echo   PUBLIC KEY (paste into setup-termux.sh)
echo ============================================================
type "%PUB_FILE%"
echo ============================================================
echo.

REM ============================================================
REM Next steps
REM ============================================================
echo Next steps:
echo   1. On phone, in Termux:
echo        bash setup-termux.sh "1.143.1" "ssh-rsa AAAA... user@host"
echo        passwd
echo        sshd
echo.
echo   2. Open VS Code.
echo      Ctrl+Shift+P - Remote-SSH: Connect to Host - termux-phone
echo.
echo   3. The VS Code server was already installed by setup-termux.sh.
echo      First connection starts it directly, no extra download.
echo.

pause
