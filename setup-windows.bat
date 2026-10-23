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

REM NOTE: do not put unescaped parentheses in echo lines inside ( ... ) blocks.
REM A closing parenthesis ends the block early and breaks the script.

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
    if exist "C:\Program Files\OpenSSH\ssh.exe" set "SSH_EXE=C:\Program Files\OpenSSH\ssh.exe"
    if not defined SSH_EXE (
        echo   [ERROR] No OpenSSH client found on Windows %WIN_VER%.
        echo.
        echo   Recommended: Win32-OpenSSH 7.7.2.0, the most stable build on these systems.
        echo   Download:
        echo   https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.7.2.0p1-Beta/OpenSSH-Win64.zip
        echo   Extract to: C:\Program Files\OpenSSH\
        echo.
        pause
        exit /b 1
    )
    "!SSH_EXE!" -V >"%TEMP%\ssh_ver.txt" 2>&1
    if errorlevel 1 (
        echo   [ERROR] ssh.exe does not start on Windows %WIN_VER%.
        echo   This is usually the VirtualAlloc2 problem with newer OpenSSH builds.
        echo   Install Win32-OpenSSH 7.7.2.0 into C:\Program Files\OpenSSH\
        echo   https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.7.2.0p1-Beta/OpenSSH-Win64.zip
        echo.
        del "%TEMP%\ssh_ver.txt" >nul 2>&1
        pause
        exit /b 1
    )
    findstr /C:"OpenSSH_7.7" "%TEMP%\ssh_ver.txt" >nul
    if errorlevel 1 (
        echo   [WARN] OpenSSH is not version 7.7, the most stable build on Windows 7, 8, and 8.1.
        echo          Found:
        type "%TEMP%\ssh_ver.txt"
        echo          Continuing. If you get a VirtualAlloc2 error later, switch to 7.7.2.0.
    ) else (
        echo   [OK] OpenSSH 7.7 found.
    )
    del "%TEMP%\ssh_ver.txt" >nul 2>&1
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

REM Prefer the ssh-keygen from the Win32-OpenSSH package, same folder as ssh.exe
if exist "C:\Program Files\OpenSSH\ssh-keygen.exe" (
    set "KEYGEN_EXE=C:\Program Files\OpenSSH\ssh-keygen.exe"
    echo   [OK] ssh-keygen found in OpenSSH.
)
REM Fall back to built-in OpenSSH on Windows 10+
if not defined KEYGEN_EXE (
    if exist "%WINDIR%\System32\OpenSSH\ssh-keygen.exe" (
        set "KEYGEN_EXE=%WINDIR%\System32\OpenSSH\ssh-keygen.exe"
        echo   [OK] Built-in ssh-keygen found.
    )
)
REM Fall back to Git for Windows, if present
if not defined KEYGEN_EXE (
    if exist "C:\Program Files\Git\usr\bin\ssh-keygen.exe" (
        set "KEYGEN_EXE=C:\Program Files\Git\usr\bin\ssh-keygen.exe"
        echo   [OK] Git ssh-keygen found.
    )
)
if not defined KEYGEN_EXE (
    echo   [ERROR] ssh-keygen not found.
    echo   It should be in C:\Program Files\OpenSSH\ or %WINDIR%\System32\OpenSSH\
    pause
    exit /b 1
)

REM ============================================================
REM [5/9] Locate VS Code, detect portable mode, read version
REM ============================================================
echo [5/9] Locating VS Code...
set "VSCODE_DIR="
set "VSCODE_CLI="

REM 1. Common install locations
for %%D in (
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

REM 2. code.cmd on PATH
for /f "delims=" %%I in ('where code.cmd 2^>nul') do (
    if not defined VSCODE_DIR (
        set "VSCODE_CLI=%%I"
        for %%J in ("%%~dpI..") do set "VSCODE_DIR=%%~fJ"
    )
)
if defined VSCODE_DIR goto :vscode_found

REM 3. Ask the user
echo   [WARN] VS Code not found in common locations or on PATH.
echo          Enter the path to Code.exe, or to the folder that contains it.
set /p "VSCODE_EXE=  Path: "
set "VSCODE_EXE=!VSCODE_EXE:"=!"
if exist "!VSCODE_EXE!\Code.exe" set "VSCODE_EXE=!VSCODE_EXE!\Code.exe"
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

REM Portable mode: VS Code uses a data folder next to Code.exe
set "SETTINGS_FILE=%APPDATA%\Code\User\settings.json"
if exist "!VSCODE_DIR!\data" (
    set "SETTINGS_FILE=!VSCODE_DIR!\data\user-data\User\settings.json"
    echo   [OK] Portable mode detected, data folder found.
) else (
    echo   [OK] Installed mode, using the user profile settings.
)

REM Read version and commit from the VS Code CLI
set "VSC_VER="
set "VSC_COMMIT="
if exist "!VSCODE_CLI!" (
    echo   Reading VS Code version...
    set "VSC_N=0"
    for /f "delims=" %%L in ('""!VSCODE_CLI!" --version"') do (
        set /a VSC_N+=1
        if "!VSC_N!"=="1" set "VSC_VER=%%L"
        if "!VSC_N!"=="2" set "VSC_COMMIT=%%L"
    )
)
if defined VSC_COMMIT (
    if "!VSC_COMMIT:~39,1!"=="" set "VSC_COMMIT="
)
if defined VSC_COMMIT (
    echo   [OK] VS Code version !VSC_VER!, commit !VSC_COMMIT!
) else (
    echo   [WARN] Could not read the VS Code commit.
    echo          Open VS Code, Help, About, and copy the Commit value.
)

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
    echo     - Phone IP is correct, from getprop dhcp.wlan0.ipaddress.
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

REM Find Python: where python, then the py launcher. Verify that it runs.
set "PYTHON="
for /f "delims=" %%P in ('where python 2^>nul') do if not defined PYTHON set "PYTHON=%%P"
if not defined PYTHON (
    for /f "delims=" %%P in ('where py 2^>nul') do if not defined PYTHON set "PYTHON=%%P"
)
if defined PYTHON (
    "!PYTHON!" --version >nul 2>&1
    if errorlevel 1 set "PYTHON="
)

set "MERGE_OK=0"
if defined PYTHON (
    set "PSETTINGS=%TEMP%\vscode_merge_settings.py"
    > "!PSETTINGS!" (
        echo import json, os, shutil
        echo p = r'!SETTINGS_FILE!'
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
    if not errorlevel 1 set "MERGE_OK=1"
    del "!PSETTINGS!" >nul 2>&1
)

if "!MERGE_OK!"=="1" (
    echo   [OK] settings.json updated, backup saved as settings.json.bak.
    echo        File: !SETTINGS_FILE!
) else (
    echo   [WARN] Could not auto-update settings.json.
    echo          Python was not found, or the file could not be parsed.
    echo          settings.json may contain comments, which this merge cannot read.
    echo          Add these entries manually to:
    echo          !SETTINGS_FILE!
    echo.
    echo          "remote.SSH.path": "!SSH_EXE:\=\\!",
    echo          "remote.SSH.configFile": "!SSH_DIR:\=\\!\\config",
    if "%IS_LEGACY%"=="1" (
        echo          "remote.SSH.useLocalServer": true,
        echo          "remote.SSH.useExecServer": false,
        echo          "remote.SSH.useFlock": false,
    )
    echo          "remote.SSH.defaultExtensions": ["llvm-vs-code-extensions.vscode-clangd"]
    echo.
)

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
set "PUBKEY="
set /p "PUBKEY=" < "%PUB_FILE%"
echo ============================================================
echo   PUBLIC KEY
echo ============================================================
echo !PUBKEY!
echo ============================================================
echo.

REM ============================================================
REM Next steps
REM ============================================================
if defined VSC_COMMIT (
    set "NEXT_ID=!VSC_COMMIT!"
) else (
    set "NEXT_ID=YOUR_COMMIT_ID"
)

echo Next steps:
echo   1. On the phone, in Termux, run the command below.
echo      It already contains your key and the commit of this VS Code:
echo.
echo        bash setup-termux.sh "!NEXT_ID!" "!PUBKEY!"
echo.
if not defined VSC_COMMIT (
    echo      Replace YOUR_COMMIT_ID with the Commit value from VS Code, Help, About.
    echo.
)
echo   2. Still in Termux, start the SSH server:
echo        sshd
echo      Run sshd again after every phone reboot. passwd is optional.
echo.
echo   3. Open VS Code.
echo      Ctrl+Shift+P - Remote-SSH: Connect to Host - termux-phone
echo.
echo   4. The VS Code server was already installed by setup-termux.sh.
echo      First connection starts it directly, no extra download.
echo.

pause
