#!/data/data/com.termux/files/usr/bin/bash
# setup-termux.sh - Configure Termux for VS Code Remote-SSH
#
# Usage:
#   bash setup-termux.sh                              # interactive
#   bash setup-termux.sh "1.143.1" "ssh-rsa AAAA..."  # version + key
#   bash setup-termux.sh "latest"   "ssh-rsa AAAA..."  # auto-detect version
#   bash setup-termux.sh "<commit>"  "ssh-rsa AAAA..."  # exact commit

set -u

TESTED_VERSION="1.143.1"
TESTED_COMMIT="e646868227c3e3a9e3f24277c8c7220be42c0be7"

info() { printf "[INFO] %s\n" "$*"; }
ok()   { printf "[ OK ] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
err()  { printf "[FAIL] %s\n" "$*"; }
step() { printf "\n== %s ==\n" "$*"; }
die()  { err "$@"; exit 1; }

prompt() {
    local msg="$1" default="${2:-}" val
    if [ -n "$default" ]; then
        read -rp "$msg [$default]: " val
        echo "${val:-$default}"
    else
        read -rp "$msg: " val
        echo "$val"
    fi
}

if [ "${PREFIX:-}" != "/data/data/com.termux/files/usr" ] || [ ! -d /data/data/com.termux ]; then
    echo "Error: must run in native Termux (not proot/chroot)." >&2
    exit 1
fi

RAW_ARCH=$(uname -m)
case "$RAW_ARCH" in
    aarch64|arm64) ARCH="arm64"  ;;
    armv7*|armhf)  ARCH="armhf"  ;;
    x86_64)        ARCH="x64"    ;;
    *)             die "Unsupported architecture: $RAW_ARCH" ;;
esac

echo
echo "============================================================"
echo "  VS Code Remote-SSH - Termux Setup"
echo "  Tested: VS Code $TESTED_VERSION on aarch64"
echo "  Detected architecture: $RAW_ARCH (-> $ARCH)"
echo "============================================================"
echo

VSCODE_INPUT="${1:-}"
PUBKEY="${2:-}"

if [ -z "$VSCODE_INPUT" ]; then
    echo "Which VS Code is on your laptop?"
    echo "  Open VS Code -> Help -> About"
    echo "  Copy 'Version' (e.g. 1.143.1) OR 'Commit' (40-char hex)"
    echo "  Or type 'latest' to auto-detect"
    echo
    VSCODE_INPUT=$(prompt "Version or commit")
fi

if [ -z "$PUBKEY" ]; then
    echo
    echo "Paste SSH public key from the Windows setup script."
    echo "Format: ssh-rsa AAAA... user@host"
    echo
    PUBKEY=$(prompt "Public key")
fi

if ! echo "$PUBKEY" | grep -qE '^(ssh-rsa|ssh-ed25519) AAAA[A-Za-z0-9+/=]+( .*)?$'; then
    die "Invalid SSH public key format."
fi
ok "Public key format OK."

step "Resolving VS Code commit"

VSCODE_COMMIT=""

if echo "$VSCODE_INPUT" | grep -qE '^[a-f0-9]{40}$'; then
    VSCODE_COMMIT="$VSCODE_INPUT"
    info "Input is a commit ID."

elif [ "$VSCODE_INPUT" = "latest" ]; then
    info "Querying latest from Microsoft API..."
    API_RESPONSE=$(wget -qO- "https://update.code.visualstudio.com/api/update/server-linux-$ARCH/stable/latest" 2>/dev/null || true)
    if [ -z "$API_RESPONSE" ]; then
        die "Could not reach Microsoft API."
    fi
    VSCODE_COMMIT=$(echo "$API_RESPONSE" | grep -oE '"version":"[a-f0-9]{40}"' | cut -d'"' -f4)
    [ -z "$VSCODE_COMMIT" ] && die "Could not parse commit from API."

else
    info "Querying version '$VSCODE_INPUT' from Microsoft API..."
    API_RESPONSE=$(wget -qO- "https://update.code.visualstudio.com/api/update/server-linux-$ARCH/stable/$VSCODE_INPUT" 2>/dev/null || true)
    if [ -n "$API_RESPONSE" ]; then
        VSCODE_COMMIT=$(echo "$API_RESPONSE" | grep -oE '"version":"[a-f0-9]{40}"' | cut -d'"' -f4)
    fi
    if [ -z "$VSCODE_COMMIT" ]; then
        warn "Version '$VSCODE_INPUT' not found via API."
        echo "Open VS Code -> Help -> About, copy the 'Commit' value."
        VSCODE_COMMIT=$(prompt "Commit ID")
        echo "$VSCODE_COMMIT" | grep -qE '^[a-f0-9]{40}$' || die "Invalid commit ID."
    fi
fi

ok "Commit: $VSCODE_COMMIT"

if [ "$VSCODE_COMMIT" != "$TESTED_COMMIT" ]; then
    warn "This commit differs from tested version ($TESTED_COMMIT)."
    warn "May work, but is not verified."
fi

step "Checking network"
ping -c 1 -W 5 update.code.visualstudio.com >/dev/null 2>&1 \
    || die "Cannot reach update.code.visualstudio.com"
ok "Network reachable."

step "Checking disk space"
AVAIL_KB=$(df "$HOME" | awk 'NR==2 {print $4}')
NEED_KB=$((600 * 1024))
[ "$AVAIL_KB" -lt "$NEED_KB" ] && die "Need 600 MB free, have $((AVAIL_KB/1024)) MB."
ok "Available: $((AVAIL_KB/1024)) MB."

step "Installing required packages"
for pkg in openssh glibc-repo proot termux-tools wget coreutils; do
    dpkg -s "$pkg" >/dev/null 2>&1 || pkg install -y "$pkg" >/dev/null 2>&1 || die "Failed: $pkg"
done
dpkg -s glibc >/dev/null 2>&1 || pkg install -y glibc >/dev/null 2>&1 || die "Failed: glibc"
ok "Packages installed."

step "Backing up existing setup"
NEEDS_BACKUP=0
[ -f "$HOME/ssh-login.sh" ] && NEEDS_BACKUP=1
[ -d "$HOME/.fakebin" ] && NEEDS_BACKUP=1
[ -f "$HOME/.ssh/authorized_keys" ] && NEEDS_BACKUP=1
[ -d "$HOME/.vscode-server" ] && NEEDS_BACKUP=1

BACKUP_PATH=""
if [ "$NEEDS_BACKUP" = "1" ]; then
    BACKUP_PATH="$HOME/vscode-setup-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_PATH" -C "$HOME" \
        ssh-login.sh .fakebin .ssh/authorized_keys .vscode-server 2>/dev/null || true
    ok "Backup: $BACKUP_PATH"
else
    info "Fresh install, nothing to back up."
fi

step "Creating ~/ssh-login.sh"
cat > "$HOME/ssh-login.sh" << 'LOGIN_EOF'
#!/data/data/com.termux/files/usr/bin/sh
mkdir -p $HOME/.fakebin
cat > $HOME/.fakebin/ln << 'FAKEEOF'
#!/data/data/com.termux/files/usr/bin/bash
for a in "$@"; do
    if [ "$a" = "-s" ] || [ "$a" = "-sf" ]; then
        exec /data/data/com.termux/files/usr/bin/ln "$@"
    fi
done
exec /data/data/com.termux/files/usr/bin/ln -s "$@"
FAKEEOF
chmod +x $HOME/.fakebin/ln
export PATH="$HOME/.fakebin:$PATH"

PROOT_CMD="proot -b /data/data/com.termux/files/usr/glibc/lib:/lib -b /data/data/com.termux/files/usr/glibc/lib:/usr/lib /data/data/com.termux/files/usr/bin/bash"

if [ -z "$1" ]; then
    if [ -t 0 ]; then
        exec $SHELL -l
    else
        export XDG_RUNTIME_DIR=$TMPDIR
        unset LD_PRELOAD
        exec $PROOT_CMD
    fi
else
    if [ ! -t 0 ] && ([ "$1" = "sh" ] || [ "$1" = "bash" ]); then
        export XDG_RUNTIME_DIR=$TMPDIR
        unset LD_PRELOAD
        exec $PROOT_CMD
    fi
    eval "$1"
fi
LOGIN_EOF
chmod +x "$HOME/ssh-login.sh"
ok "ssh-login.sh created."

step "Writing ~/.ssh/authorized_keys"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
cat > "$HOME/.ssh/authorized_keys" << AUTH_EOF
command="\$HOME/ssh-login.sh \"\$SSH_ORIGINAL_COMMAND\"" $PUBKEY
AUTH_EOF
chmod 600 "$HOME/.ssh/authorized_keys"
ok "authorized_keys written."

step "Downloading VS Code server"
TARBALL="$HOME/vscode-server.tar.gz"
SERVER_DIR="$HOME/.vscode-server/bin/$VSCODE_COMMIT"

if [ -f "$SERVER_DIR/node" ] && [ -d "$SERVER_DIR/bin" ]; then
    info "Server already installed, skipping download."
else
    if [ -f "$TARBALL" ] && [ "$(stat -c%s "$TARBALL" 2>/dev/null || echo 0)" -gt 100000000 ]; then
        info "Using existing tarball."
    else
        URL="https://update.code.visualstudio.com/commit:$VSCODE_COMMIT/server-linux-$ARCH/stable"
        info "Downloading: $URL"
        wget -O "$TARBALL" "$URL" || die "Download failed."
    fi

    SIZE_MB=$(($(stat -c%s "$TARBALL" 2>/dev/null || echo 0) / 1024 / 1024))
    [ "$SIZE_MB" -lt 50 ] && { rm -f "$TARBALL"; die "Downloaded file too small (${SIZE_MB}MB)."; }
    ok "Downloaded ${SIZE_MB}MB."
fi

step "Extracting server"
if [ -d "$SERVER_DIR" ] && [ ! -f "$SERVER_DIR/node" ]; then
    rm -rf "$SERVER_DIR"
fi
if [ ! -f "$SERVER_DIR/node" ]; then
    mkdir -p "$SERVER_DIR"
    tar -xzf "$TARBALL" -C "$SERVER_DIR" --strip-components=1 || die "Extraction failed."
    ok "Extracted to $SERVER_DIR"
else
    info "Already extracted."
fi

step "Fixing shebangs"
termux-fix-shebang "$SERVER_DIR/bin/code-server"     2>/dev/null || true
termux-fix-shebang "$SERVER_DIR/bin/remote-cli/code" 2>/dev/null || true
for f in "$SERVER_DIR/bin/code-server" "$SERVER_DIR/bin/remote-cli/code"; do
    grep -q "^unset LD_PRELOAD" "$f" 2>/dev/null || sed -i '1a unset LD_PRELOAD' "$f" 2>/dev/null || true
done
ok "Shebangs fixed."

step "Installing getconf shim"
if ! command -v getconf >/dev/null 2>&1; then
    cat > "$PREFIX/bin/getconf" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
case "$1" in
    GNU_LIBC_VERSION) echo "glibc 2.35" ;;
    *) echo "0" ;;
esac
EOF
    chmod +x "$PREFIX/bin/getconf"
    ok "getconf shim installed."
else
    info "getconf already present."
fi

step "Testing node under proot"
unset LD_PRELOAD
NODE_OUT=$(proot -b /data/data/com.termux/files/usr/glibc/lib:/lib \
                 -b /data/data/com.termux/files/usr/glibc/lib:/usr/lib \
                 "$SERVER_DIR/node" --version 2>&1 || true)
echo "  node --version -> $NODE_OUT"

if echo "$NODE_OUT" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+'; then
    ok "node works."
else
    err "node failed. Output: $NODE_OUT"
    exit 1
fi

step "Verifying setup"
FAIL=0
[ -x "$HOME/ssh-login.sh" ] || { err "ssh-login.sh not executable"; FAIL=1; }
[ -x "$HOME/.fakebin/ln" ] || { err ".fakebin/ln missing"; FAIL=1; }
grep -q '^command="' "$HOME/.ssh/authorized_keys" || { err "authorized_keys missing command="; FAIL=1; }
[ -f "$SERVER_DIR/node" ] || { err "server node missing"; FAIL=1; }
[ "$FAIL" = "0" ] && ok "All checks passed."

step "Setup complete"
echo
echo "Commit:  $VSCODE_COMMIT"
echo "Server:  $SERVER_DIR"
echo "Backup:  ${BACKUP_PATH:-none}"
echo
echo "Next steps on phone:"
echo "  1. Set SSH password:  passwd"
echo "  2. Start SSH server:  sshd"
echo "  3. Phone IP:          getprop dhcp.wlan0.ipaddress"
echo "  4. Username:          whoami"
echo
echo "Then from VS Code: Ctrl+Shift+P -> Remote-SSH: Connect to Host -> termux-phone"
echo
