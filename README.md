# VS Code Remote-SSH between Legacy Windows and Termux

Run modern VS Code on Windows 7, 8, 8.1, 10, or 11, and use an Android phone running Termux as a remote development server over SSH. Files, compilation, and execution happen on the phone. The laptop only renders the editor UI.

This is useful when:

- The laptop is old, weak, or runs an unsupported Windows version.
- You want a real Linux development environment (clang, gcc, make, git, Python) inside Windows without WSL, dual boot, or virtual machines.
- You have a spare Android phone that can be reused as a portable build server.
- Cloud IDEs are blocked or unavailable on your network.

Windows 7, 8, and 8.1 require VxKex NEXT and an OpenSSH client. Version 7.7.2.0 is the most stable build confirmed on these systems, and later 8.x releases also work in practice. Windows 10 and 11 work with the built-in OpenSSH client and need no extra compatibility tools.


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

Windows 7, 8, and 8.1 need two extra components. Windows 10 and 11 do not.

- VxKex NEXT: https://github.com/YuZhouRen86/VxKex-NEXT/releases
  Download the latest `KexSetup_Release_*.exe` from the Releases page and install it.
- Win32-OpenSSH 7.7.2.0p1-Beta: https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.7.2.0p1-Beta/OpenSSH-Win64.zip
  Extract to `C:\Program Files\OpenSSH\`. This package includes both `ssh.exe` and `ssh-keygen.exe`.
  Version 7.7 is the most stable build confirmed on Windows 7, 8, and 8.1. Later 8.x releases also work in practice. 9.x and newer may work depending on the specific build and system updates, but are not guaranteed. If `ssh -V` runs and you can connect, your version is fine.

### Laptop (Windows 10, 11 only)

No extra installation. The script uses the OpenSSH client that ships with Windows. If it is missing, add it via Settings, Apps, Optional Features, OpenSSH Client.

### Phone (Android)

- Termux from F-Droid: https://f-droid.org/packages/com.termux/
- Same WiFi network as the laptop.
- At least 600 MB of free storage for the VS Code server.


## Usage

### 1. Prepare the laptop

Any Windows:

- VS Code 1.143.1 (portable or installed).
- Same WiFi network as the phone.

Windows 7, 8, 8.1 only (skip this list on Windows 10 and 11):

- VxKex NEXT: https://github.com/YuZhouRen86/VxKex-NEXT/releases
- Win32-OpenSSH 7.7.2.0p1-Beta (or a newer version that works), extracted to `C:\Program Files\OpenSSH\`

`setup-windows.bat` checks for the required components based on your Windows version and stops with instructions if any are missing. An OpenSSH version other than 7.7 only produces a warning.

### 2. Get the scripts

Download both scripts from this repository:

- `setup-windows.bat` — save anywhere on the laptop (e.g. Desktop)
- `setup-termux.sh` — needs to end up on the phone

To place `setup-termux.sh` on the phone, either transfer via USB, or in Termux run:

    pkg install wget
    wget https://raw.githubusercontent.com/vahidrezaa/vscode-remote-ssh-termux/main/setup-termux.sh
    chmod +x setup-termux.sh

### 3. Collect phone details

In Termux on the phone, run:

    getprop dhcp.wlan0.ipaddress
    whoami

Note the IP address and username. The next step asks for both.

### 4. Run the Windows setup

Double-click `setup-windows.bat`. The script will:

- Verify the required components for your Windows version
- Find VS Code (common install locations, then `PATH`; it asks for the path to `Code.exe` if not found), detect portable mode, and print its version and commit
- Ask for the phone IP and username from step 3
- Ping the phone to confirm reachability
- Generate an SSH key pair at `%USERPROFILE%\.ssh\termux_key`
- Write or update `~/.ssh/config` (will not overwrite an existing termux-phone entry)
- Install the Remote-SSH extension
- Merge required settings into `settings.json` (backup saved as `settings.json.bak`). For portable VS Code, meaning a `data` folder next to `Code.exe`, the file is `data\user-data\User\settings.json`. Otherwise it is `%APPDATA%\Code\User\settings.json`.
- Print the SSH public key and a ready-to-paste command for step 5

Copy the printed command. Step 5 needs it.

If Python is not found (`where python`) or the file cannot be parsed, the script prints the required settings, including the clangd entry in `remote.SSH.defaultExtensions`, for manual addition.

### 5. Run the phone setup

In Termux, run the command printed at the end of step 4. It has this form:

    bash setup-termux.sh "e646868227c3e3a9e3f24277c8c7220be42c0be7" "ssh-rsa AAAA... user@host"

The first argument is the VS Code commit (40 hex characters). Use the commit rather than the version number whenever you can: the server must match the commit of the VS Code on your laptop exactly. `setup-windows.bat` prints it, or run `code --version` (second line), or open Help, About. A version number such as `1.143.1` is resolved to a commit through Microsoft's update API, and that mapping is not verified, so the script warns you to double-check it.

The script will back up `~/ssh-login.sh`, `~/.fakebin/` and `~/.ssh/authorized_keys` (not the VS Code server itself, which can be rebuilt), install packages, create `~/ssh-login.sh` and `~/.fakebin/ln`, write `~/.ssh/authorized_keys`, download and extract the VS Code server, fix shebangs, install a `getconf` shim if none exists, and verify that node runs under proot.

Running the script again with the same version does not re-download the server. It does regenerate `~/ssh-login.sh` and replaces `~/.ssh/authorized_keys` with the single key you pass in, so any other keys in that file are removed. The previous files are saved in `~/vscode-setup-backup-*.tar.gz`; delete old backups when you no longer need them.

If you do not know the commit, run the script without arguments; it will prompt for commit, version, or "latest", and then for the public key.

### 6. Start SSH

In Termux:

    sshd

`sshd` starts the SSH server. It must be re-run after every phone reboot; everything else persists.

Setting a password with `passwd` is optional. VS Code connects with the SSH key only (the config uses `PreferredAuthentications publickey`), and a password login would skip `ssh-login.sh`, so it cannot be used for development.

### 7. Enable VxKex NEXT on Code.exe (Windows 7, 8, 8.1 only)

Skip this step on Windows 10 and 11.

Right-click `Code.exe`, open Properties, go to the VxKex NEXT tab:

- Check "Enable VxKex for this program"
- Set "Report a different version of Windows" to Windows 10

Click OK. This only needs to be done once, and only for launching VS Code. The setup scripts do not require VxKex.

### 8. Connect

Open VS Code. Press Ctrl+Shift+P, choose "Remote-SSH: Connect to Host", select "termux-phone".

The VS Code server was already installed by `setup-termux.sh` in step 5. On first connection, VS Code detects the existing installation and starts it directly. No download is needed. Connection should complete in a few seconds.

All files, compilation, and execution happen on the phone. The laptop only renders the editor.

### Alternative: skip manual download

If you already have the public key from step 4, you can run the phone setup directly without saving the script first:

    bash <(curl -fsSL https://raw.githubusercontent.com/vahidrezaa/vscode-remote-ssh-termux/main/setup-termux.sh)

The script prompts for the VS Code commit and the public key interactively. Do not write `curl ... | bash` for this: with a pipe, the script's own text occupies standard input and the prompts cannot read your answers. A pipe only works if you pass both arguments, without prompts:

    curl -fsSL https://raw.githubusercontent.com/vahidrezaa/vscode-remote-ssh-termux/main/setup-termux.sh | bash -s -- "COMMIT" "PUBLIC_KEY"


Note: this approach bypasses step 2. It runs the script with your user permissions immediately, without a local copy to review first. If you prefer to inspect the script before running it, use the manual method in step 2.


## How it works

The setup uses four components. Two are only needed on legacy Windows.

1. VxKex NEXT (Windows 7, 8, 8.1 only). Shims Windows 10 APIs that modern VS Code needs. VxKex NEXT explicitly lists VS Code among supported applications. Without it, VS Code 1.143.1 will not launch on these versions. Repository: https://github.com/YuZhouRen86/VxKex-NEXT

2. Win32-OpenSSH (Windows 7, 8, 8.1 only). Version 7.7.2.0 is the most stable build confirmed on these systems. Later 8.x builds also work in practice; 9.x and newer may work depending on the build. Some newer builds reference VirtualAlloc2, which Windows 7, 8, and 8.1 do not provide; if that error appears, downgrade to 7.7.2.0.

3. proot plus glibc (all Windows versions). The VS Code server requires glibc. Android uses bionic. The script installs glibc alongside bionic and wraps the server in proot so the linker finds the right libc without patching binaries. A small `getconf` shim also reports glibc 2.35 to the server's requirements check. This is the core of the solution and is independent of the client's operating system.

4. fake ln (all Windows versions). Android filesystems reject hard links, which VS Code's installer uses for file locking. A small wrapper converts hard link attempts into symlinks. Also independent of the client OS.

The hard problems are on the phone side, not the laptop side. Any SSH-capable client on the same network will work, whether it runs Windows 7 or Windows 11.


## Important notes

- VxKex NEXT is the maintained fork. The older `i486/VxKex` repository is not the one referenced by this project. Use https://github.com/YuZhouRen86/VxKex-NEXT/releases.
- Version numbers in "Tested configuration" reflect the exact environment where end-to-end testing was done. They are not strict minimum or maximum requirements. If a newer OpenSSH build or VS Code version works on your system, use it.
- The VS Code server on the phone must be built from the same commit as the VS Code on the laptop. After updating VS Code on the laptop, re-run `setup-termux.sh` with the new commit.
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
- Cause: the OpenSSH build references VirtualAlloc2, which Windows 7, 8, and 8.1 do not provide.
- Fix: downgrade to Win32-OpenSSH 7.7.2.0. Newer 8.x builds often work; 9.x and later are more likely to trigger this error.

**SSH installation not found in VS Code**
- Cause: VS Code is using Git Bash's ssh.exe, which requires VirtualAlloc2.
- Fix: set `remote.SSH.path` to `C:\Program Files\OpenSSH\ssh.exe`.

**Cannot launch conpty**
- Cause: VS Code built-in terminal on Windows 7, 8, 8.1.
- Fix: use a separate PuTTY session for terminal commands. Remote-SSH is unaffected.

### All Windows versions

**ln: failed to create hard link**
- Cause: Android filesystem rejects hard links.
- Fix: verify that `~/.fakebin/ln` exists and is executable on the phone. `setup-termux.sh` creates it and `ssh-login.sh` recreates it at every login; if it is missing, re-run `setup-termux.sh`.

**Missing GLIBC >= 2.17**
- Cause: the server's requirements check could not read the glibc version, or an older `ssh-login.sh` still sets `VSCODE_SERVER_CUSTOM_GLIBC_LINKER`, `VSCODE_SERVER_CUSTOM_GLIBC_PATH` or `VSCODE_SERVER_PATCHELF_PATH`, which makes the server patch itself with patchelf.
- Fix: on the phone, `getconf GNU_LIBC_VERSION` must print `glibc 2.35`. If it does not, delete `$PREFIX/bin/getconf` and re-run `setup-termux.sh`. The script installs its `getconf` shim only when no `getconf` exists, and it regenerates `ssh-login.sh` without those variables.

**Segmentation fault when starting node**
- Cause: patchelf was applied to `node`.
- Fix: re-extract `node` from `~/vscode-server.tar.gz` and do not run patchelf.

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
- Cause: SSH key authentication did not succeed, so the `command=` prefix in `authorized_keys` was not triggered and `ssh-login.sh` did not run.
- Fix: verify `ssh -F ~/.ssh/config termux-phone echo OK` returns `OK` without asking for a password.

**Settings are not applied with portable VS Code**
- Cause: the settings were written to the wrong `settings.json`. Portable VS Code reads `data\user-data\User\settings.json` next to `Code.exe`, not the user profile.
- Fix: `setup-windows.bat` uses the portable path when a `data` folder exists next to `Code.exe`. If you created that folder after running the script, run the script again.

**Server does not start after updating VS Code**
- Cause: the server on the phone was built from a different commit than the VS Code on the laptop.
- Fix: run `code --version` on the laptop (second line is the commit) and re-run `setup-termux.sh` with that commit.


## What did not work

For reference, the following approaches were tested and rejected.

- VS Code 1.70.3 with glibc patch. Version 1.70.3 predates the `VSCODE_SERVER_CUSTOM_GLIBC` variables (added in 1.82). The 1.70.3 server tarball was also removed from Microsoft's CDN.
- `patchelf --set-interpreter` with `--set-rpath`. Causes SIGSEGV on Android.
- `patchelf` from the Termux repository. Broken due to a missing bionic symbol (`_ZNSt6__ndk113__hash_memoryEPKvm`).
- `plink.exe` as SSH. Does not accept OpenSSH flags such as `-F`, `-D`, `-T`.
- Git Bash `ssh.exe`. Requires VirtualAlloc2, unavailable on Windows 7, 8, 8.1.
- `code-server`. Works but runs in the browser, not as native VS Code. Kept as a fallback.


## Tested configuration

End-to-end tested:

- Windows 7 SP1 with KB4474419 and KB4490628
- VxKex NEXT from https://github.com/YuZhouRen86/VxKex-NEXT/releases
- VS Code 1.143.1, commit e646868227c3e3a9e3f24277c8c7220be42c0be7
- Remote-SSH 0.128.0
- Win32-OpenSSH 7.7.2.0p1-Beta
- Termux glibc 2.35
- Node on server v24.22.1
- Architecture: aarch64 (arm64)
- Android 13

Expected to work but not verified:

- Windows 8, 8.1, 10, 11
- VS Code versions other than 1.143.1
- OpenSSH 8.x and later, on Windows 7, 8, 8.1
- Termux on armhf and x64


## Tested by

- @vahidrezaa — Windows 7 SP1, VS Code 1.143.1, VxKex NEXT, Termux aarch64 (Android 13)


## License

MIT
