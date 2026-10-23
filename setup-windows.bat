@echo off
setlocal enabledelayedexpansion
title VS Code Remote-SSH Setup

echo.
echo ============================================================
echo   VS Code Remote-SSH - Windows Setup
echo ============================================================
echo.

set "SSH_DIR=%USERPROFILE%\.ssh"
set "CONFIG_FILE=%SSH_DIR%\config"
set "KEY_FILE=%SSH_DIR%\termux_key"
set "PUB_FILE=%SSH_DIR%\termux_key.pub"

REM ---------- [1/9] Detect Windows version ----------
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

REM ---------- [2/9] VxKex (legacy only) ----------
echo [2/9] Checking VxKex...
if "%IS_LEGACY%"=="1" (
    set "VXKEX_FOUND=0"
    if exist "C:\Program Files\VxKex" set "VXKEX_FOUND=1"
    if exist "C:\Program Files (x86)\VxKex" set "VXKEX_FOUND=1"
    if "!VXKEX_FOUND!"=="0" (
        echo   [WARN] VxKex not found.
        echo   VS Code 1.143+ requires VxKex on Windows 7 / 8 / 8.1.
        echo   Download: https://github.com/i486/VxKex/releases
        choice /C YN /M "  Continue anyway"
        if errorlevel 2 exit /b 1
    ) else (
        echo   [OK] VxKex found.
    )
) else (
    echo   [SKIP] VxKex not needed on Windows %WIN_VER%.
)

REM ---------- [3/9] SSH client ----------
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
        echo   Download: https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.7.2.0p1-Beta/OpenSSH-Win64.zip
        echo   Extract to: C:\Program Files\OpenSSH\
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
            echo   [OK] OpenSSH found.
        )
    )
    if not defined SSH_EXE (
        echo   [ERROR] No SSH client found.
        echo   Windows 10+ usually includes OpenSSH at %WINDIR%\System32\OpenSSH\
        echo   If missing: Settings - Apps - Optional Features - OpenSSH Client
        pause
        exit /b 1
    )
)

REM ---------- [4/9] ssh-keygen ----------
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

REM ---------- [5/9] Locate VS Code ----------
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

REM ---------- [6/9] Phone details ----------
echo.
echo [6/9] Phone details (on phone: getprop dhcp.wlan0.ipaddress / whoami)
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

REM ---------- [7/9] Connectivity ----------
echo.
echo [7/9] Testing connectivity to %PHONE_IP%...
ping -n 1 -w 2000 %PHONE_IP% >nul
if errorlevel 1 (
    echo   [ERROR] Cannot reach %PHONE_IP%.
    pause
    exit /b 1
)
echo   [OK] Phone reachable.

REM ---------- [8/9] SSH key + config ----------
echo.
echo [8/9] SSH key and config...
if not exist "%SSH_DIR%" mkdir "%SSH_DIR%"
if exist "%KEY_FILE%" (
    echo   [OK] Key exists.
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
    echo   [OK] Added termux-phone to config.
) else (
    echo   [SKIP] termux-phone already in config.
)

REM ---------- [9/9] Extension + settings ----------
echo.
echo [9/9] Installing Remote-SSH extension and configuring settings...
if exist "!VSCODE_CLI!" (
    "!VSCODE_CLI!" --install-extension ms-vscode-remote.remote-ssh --force >nul 2>&1
    if errorlevel 1 (
        echo   [WARN] Extension install may have failed.
    ) else (
        echo   [OK] Remote-SSH installed.
    )
)

set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
if not exist "!PYTHON!" set "PYTHON=python"

set "PYCODE=import json,os,shutil;p=os.path.join(os.environ['APPDATA'],'Code','User','settings.json');os.makedirs(os.path.dirname(p),exist_ok=True);d=json.load(open(p,'r',encoding='utf-8')) if os.path.exists(p) else {};shutil.copy(p,p+'.bak') if os.path.exists(p) else None;d['remote.SSH.path']=r'!SSH_EXE!';d['remote.SSH.configFile']=os.path.join(os.environ['USERPROFILE'],'.ssh','config');d['remote.SSH.useLocalServer']=True if '!IS_LEGACY!'=='1' else d.get('remote.SSH.useLocalServer',True);d['remote.SSH.useExecServer']=False if '!IS_LEGACY!'=='1' else d.get('remote.SSH.useExecServer',True);d['remote.SSH.useFlock']=False if '!IS_LEGACY!'=='1' else d.get('remote.SSH.useFlock',True);d.setdefault('remote.SSH.defaultExtensions',[]);'llvm-vs-code-extensions.vscode-clangd' not in d['remote.SSH.defaultExtensions'] and d['remote.SSH.defaultExtensions'].append('llvm-vs-code-extensions.vscode-clangd');json.dump(d,open(p,'w',encoding='utf-8'),indent=4)"
"!PYTHON!" -c "!PYCODE!" >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Could not auto-update settings.json. Add manually:
    echo     "remote.SSH.path": "!SSH_EXE!"
    echo     "remote.SSH.configFile": "C:\\Users\\%USERNAME%\\.ssh\\config"
    if "%IS_LEGACY%"=="1" (
        echo     "remote.SSH.useLocalServer": true
        echo     "remote.SSH.useExecServer": false
        echo     "remote.SSH.useFlock": false
    )
) else (
    echo   [OK] settings.json updated.
)

REM ---------- Done ----------
echo.
if "%IS_LEGACY%"=="1" (
    echo ============================================================
    echo   IMPORTANT: Enable VxKex on Code.exe
    echo ============================================================
    echo   1. Right-click: !VSCODE_DIR!\Code.exe
    echo   2. Properties -^> VxKex tab
    echo   3. Enable VxKex for this program
    echo   4. Report different version: Windows 10
    echo.
)

echo ============================================================
echo   PUBLIC KEY (paste into setup-termux.sh)
echo ============================================================
type "%PUB_FILE%"
echo ============================================================
echo.
echo Next steps:
echo   1. On phone: bash setup-termux.sh "1.143.1" "<public key above>"
echo   2. On phone: passwd
echo   3. On phone: sshd
echo   4. Open VS Code - Ctrl+Shift+P - Remote-SSH: Connect to Host - termux-phone
echo.
pause
