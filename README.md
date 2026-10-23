# VS Code Remote-SSH between Legacy Windows and Termux

Run modern VS Code on Windows 7, 8, 8.1, 10, or 11, and use an Android phone running Termux as a remote development server over SSH. Files, compilation, and execution happen on the phone. The laptop only renders the editor UI.

This is useful when:

- The laptop is old, weak, or runs an unsupported Windows version.
- You want a real Linux development environment (clang, gcc, make, git, Python) inside Windows without WSL, dual boot, or virtual machines.
- You have a spare Android phone that can be reused as a portable build server.
- Cloud IDEs are blocked or unavailable on your network.

Windows 7, 8, and 8.1 require VxKex NEXT and OpenSSH 7.7. Windows 10 and 11 work with the built-in OpenSSH client and need no extra compatibility tools.


## Use cases

- Weak or old laptop that cannot run modern VS Code or modern Linux tooling locally.
- Windows 7, 8, or 8.1 machine that still works but is unsupported by recent editors.
- Any Windows version where WSL is not available (Windows 7, 8, 8.1) or not desirable (small disk, limited RAM).
- Need for a Linux development environment (clang, gcc, make, git, Python) inside Windows without dual boot or virtual machines.
- Old Android phone that can be reused as a portable build server.
- Air-gapped or restricted networks where cloud IDEs are blocked.
- Situations where a full IDE feels too heavy but a terminal editor is not enough.
- Modern Windows 10 or 11 users who want to offload compilation to a phone on the same network, for example when testing ARM64 code.


## Requirements

### Laptop (any Windows version)

- Windows 7 SP1, 8, 8.1, 10, or 11.
- VS Code 1.143.1 (portable or installed). Older or newer versions may work but are untested.
- Same WiFi network as the phone.

### Laptop (Windows 7, 8, 8.1 only)

Windows 7, 8, and 8.1 need three extra components. Windows 10 and 11 do not.

- VxKex NEXT: https://github.com/YuZhouRen86/VxKex-NEXT/releases
  Download the latest `KexSetup_Release_*.exe` from the Releases page and install it.
- Win32-OpenSSH 7.7.2.0p1-Beta: https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.7.2.0p1-Beta/OpenSSH-Win64.zip
  Extract to `C:\Program Files\OpenSSH\`.
- Git for Windows: https://git-scm.com/download/win
  Only needed for `ssh-keygen`.

### Laptop (Windows 10, 11 only)

No extra installation. The script uses the OpenSSH client that ships with Windows. If it is missing, add it via Settings, Apps, Optional Features, OpenSSH Client.

### Phone (Android)

- Termux from F-Droid: https://f-droid.org/packages/com.termux/
- Same WiFi network as the laptop.
- At least 600 MB of free storage for the VS Code server.


## Usage

### 1. Prepare the laptop

Install the following first:

- VxKex Next
- VS Code 1.143.1 (portable or installed)
- Win32-OpenSSH 7.7.2.0p1-Beta, extracted to C:\Program Files\OpenSSH\
- Git for Windows

The setup script checks for these and stops with instructions if any are missing.

### 2. Get the scripts

Download both scripts from this repository:

- `setup-windows.bat` — save anywhere on the laptop (e.g. Desktop)
- `setup-termux.sh` — needs to end up on the phone

To place `setup-termux.sh` on the phone, either transfer via USB, or in Termux run:

    pkg install wget
    wget https://raw.githubusercontent.com/USERNAME/REPO/main/setup-termux.sh
    chmod +x setup-termux.sh

### 3. Collect phone details

In Termux on the phone, run:

    getprop dhcp.wlan0.ipaddress
    whoami

Note the IP address and username. The next step asks for both.

### 4. Run the Windows setup

Double-click `setup-windows.bat`. The script will:

- Verify Windows 7, VxKex, OpenSSH, Git, and VS Code
- Ask for the phone IP and username from step 3
- Ping the phone to confirm reachability
- Generate an SSH key pair at %USERPROFILE%\.ssh\termux_key
- Write or update ~/.ssh/config (will not overwrite an existing termux-phone entry)
- Install the Remote-SSH extension
- Merge required settings into settings.json (backup saved as settings.json.bak)
- Print the SSH public key

Copy the printed public key. Step 5 needs it.

If Python is not installed, the script prints the required settings for manual addition.

### 5. Run the phone setup

In Termux, run the script with your VS Code version and the public key from step 4:

    bash setup-termux.sh "1.143.1" "ssh-rsa AAAA... user@host"

The script will back up any existing configuration, install packages, create ~/ssh-login.sh and ~/.fakebin/ln, write ~/.ssh/authorized_keys, download and extract the VS Code server, fix shebangs, and verify that node runs under proot.

The script is idempotent. Running it again with the same version does not re-download or overwrite working files.

If you do not know the VS Code version, run the script without arguments; it will prompt for version, commit, or "latest".

### 6. Start SSH

In Termux:

    passwd
    sshd

`passwd` sets the SSH password. `sshd` starts the SSH server. `sshd` must be re-run after every phone reboot; everything else persists.

### 7. Enable VxKex on Code.exe

Right-click `Code.exe`, open Properties, go to the VxKex tab:

- Enable VxKex for this program
- Report a different version of Windows: Windows 10

Click OK. This is only needed once, and only for launching VS Code. The setup scripts themselves do not require VxKex.

### 8. Connect

Open VS Code. Press Ctrl+Shift+P, choose "Remote-SSH: Connect to Host", select "termux-phone".

On first connection, VS Code downloads the server (around 200 MB). Wait for completion. After connection, VS Code opens with the phone as the remote workspace. All files, compilation, and execution happen on the phone.

### Alternative: one-liner for the phone

If you already have the public key from step 4, you can skip the manual download in step 2 and use:

    curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/setup-termux.sh | bash

The script prompts for version and public key interactively.


## How it works

The setup uses four components. Two are only needed on legacy Windows.

1. VxKex NEXT (Windows 7, 8, 8.1 only). Shims Windows 10 APIs that modern VS Code needs. VxKex NEXT explicitly lists VS Code among supported applications. Without it, VS Code 1.143.1 will not launch on these versions. Repository: https://github.com/YuZhouRen86/VxKex-NEXT

2. Win32-OpenSSH 7.7 (Windows 7, 8, 8.1 only). The last OpenSSH build that works on these versions. Newer builds require VirtualAlloc2, which Windows 7, 8, and 8.1 do not have.

3. proot plus glibc (all Windows versions). The VS Code server requires glibc. Android uses bionic. The script installs glibc alongside bionic and wraps the server in proot so the linker finds the right libc without patching binaries. This is the core of the solution and is independent of the client's operating system.

4. fake ln (all Windows versions). Android filesystems reject hard links, which VS Code's installer uses for file locking. A small wrapper converts hard link attempts into symlinks. Also independent of the client OS.

The hard problems are on the phone side, not the laptop side. Any SSH-capable client on the same network will work, whether it runs Windows 7 or Windows 11.


## Important notes

- Only tested end-to-end on Windows 7 SP1 with VS Code 1.143.1, VxKex NEXT, Termux aarch64 on Android 13. Windows 8, 8.1, 10, and 11 should work but are not verified. Other VS Code versions may work but are not verified.
- VxKex NEXT is the maintained fork. The older `i486/VxKex` repository is not the one referenced by this project. Use https://github.com/YuZhouRen86/VxKex-NEXT/releases.
- Never run patchelf on the server binary. patchelf corrupts ELF files on Android and causes SIGSEGV. The setup script intentionally avoids patchelf.
- The SSH key is required. The `command="$HOME/ssh-login.sh ..."` prefix in `authorized_keys` only executes when authentication uses a key, not a password. Without the key, proot never starts.
- VS Code internal terminal on Windows 7, 8, 8.1. ConPTY, which VS Code uses for its built-in terminal, requires Windows 10. Opening the terminal may fail with "Cannot launch conpty". Use a separate PuTTY session for running commands. This does not affect Remote-SSH and does not occur on Windows 10 or 11.
- C/C++ extension crashes under proot. The official Microsoft C/C++ extension uses a language server that segfaults on proot, on any Windows version. Use clangd instead. The Windows setup script adds clangd to `remote.SSH.defaultExtensions` so it installs automatically on the remote.
- After phone reboot, only one command is needed: `sshd`. Everything else persists.
- Backup the SSH private key at `%USERPROFILE%\.ssh\termux_key`. If lost, regenerate it and update `authorized_keys` on the phone.
- `setup-termux.sh` is independent of the client operating system. It can be used with any SSH client (Linux, macOS, another Android device), not only with Windows.
- The VS Code server is pre-installed by `setup-termux.sh`. On first connection, VS Code does not download anything; it detects the existing installation and starts the server directly.


## Troubleshooting

### Windows 7, 8, 8.1

**VS Code does not launch**
- Cause: VxKex NEXT is not installed or not enabled on `Code.exe`.
- Fix: install VxKex NEXT from https://github.com/YuZhouRen86/VxKex-NEXT/releases and enable it on `Code.exe` as described in step 7.

**BadInstallScriptResult**
- Cause: ConPTY not available on these Windows versions.
- Fix: ensure `remote.SSH.useLocalServer` is `true` and `remote.SSH.useExecServer` is `false` in `settings.json`.

**VirtualAlloc2 error when checking SSH**
- Cause: modern OpenSSH on Windows 7, 8, or 8.1.
- Fix: use Win32-OpenSSH 7.7.2.0.

**SSH installation not found in VS Code**
- Cause: VS Code is using Git Bash's ssh.exe, which requires VirtualAlloc2.
- Fix: set `remote.SSH.path` to `C:\Program Files\OpenSSH\ssh.exe`.

**Cannot launch conpty**
- Cause: VS Code built-in terminal on Windows 7, 8, 8.1.
- Fix: use a separate PuTTY session for terminal commands. Remote-SSH is unaffected.

### All Windows versions

**ln: failed to create hard link**
- Cause: Android filesystem rejects hard links.
- Fix: verify that `~/.fakebin/ln` exists and is executable on the phone.

**Missing GLIBC >= 2.17**
- Cause: VS Code server tried to patch itself with patchelf.
- Fix: remove `VSCODE_SERVER_CUSTOM_GLIBC_LINKER`, `VSCODE_SERVER_CUSTOM_GLIBC_PATH`, and `VSCODE_SERVER_PATCHELF_PATH` from `ssh-login.sh`.

**Segmentation fault when starting node**
- Cause: patchelf was applied to `node`.
- Fix: re-extract `node` from `vscode-server.tar.gz` and do not run patchelf.

**Remote extension host terminated unexpectedly**
- Cause: `node` corrupted by patchelf.
- Fix: same as above.

**Permission denied (publickey)**
- Cause: incorrect permissions or mismatched key.
- Fix: `chmod 700 ~/.ssh` and `chmod 600 ~/.ssh/authorized_keys` on the phone.

**C/C++ extension fails with SIGSEGV**
- Cause: cpptools incompatible with proot.
- Fix: disable C/C++ extension and use clangd instead.

**Connection works but files appear empty**
- Cause: SSH key authentication failed; session is running with password only, so `ssh-login.sh` did not execute and proot did not start.
- Fix: verify `ssh -F ~/.ssh/config termux-phone echo OK` returns `OK` without asking for a password.


## What did not work

For reference, the following approaches were tested and rejected during development. All testing was done on Windows 7 SP1 with VS Code 1.143.1 and Termux aarch64 on Android 13. Results on other configurations may differ.

- VS Code 1.70.3 with glibc patch. Version 1.70.3 predates the `VSCODE_SERVER_CUSTOM_GLIBC` variables (added in 1.82). The 1.70.3 server tarball was also removed from Microsoft's CDN.
- `patchelf --set-interpreter` with `--set-rpath`. Causes SIGSEGV on Android.
- `patchelf` from the Termux repository. Broken due to a missing bionic symbol (`_ZNSt6__ndk113__hash_memoryEPKvm`).
- `plink.exe` as SSH. Does not accept OpenSSH flags such as `-F`, `-D`, `-T`.
- Git Bash `ssh.exe`. Requires VirtualAlloc2, unavailable on Windows 7, 8, 8.1.
- `code-server`. Works but runs in the browser, not as native VS Code. Kept as a fallback.


## Versions

Tested end-to-end:

- Windows 7 SP1 with KB4474419 and KB4490628
- VxKex NEXT from https://github.com/YuZhouRen86/VxKex-NEXT/releases
- VS Code 1.143.1, commit e646868227c3e3a9e3f24277c8c7220be42c0be7
- Remote-SSH 0.128.0
- Win32-OpenSSH 7.7.2.0p1-Beta
- Termux glibc 2.35
- Node on server v24.22.1
- Architecture: aarch64 (arm64)

Expected to work but not verified:

- Windows 8, 8.1, 10, 11
- VS Code versions other than 1.143.1
- Termux on armhf and x64


## Tested by

- @vahidrezaa — Windows 7 SP1, VS Code 1.143.1, VxKex NEXT, Termux aarch64 (Android 13)


## License

MIT
