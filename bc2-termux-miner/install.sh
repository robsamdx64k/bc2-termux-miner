#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# --- settings ---
REPO_DIR="$HOME/bc2-termux-miner"
CPUMINER_DIR="$HOME/cpuminer-opt"

say(){ echo -e "\n\033[1;32m==>\033[0m $*"; }
warn(){ echo -e "\033[1;33m[warn]\033[0m $*"; }

# 0) Termux basics
say "Updating Termux + installing dependencies..."
pkg update -y && pkg upgrade -y
pkg install -y git clang make automake autoconf libtool pkg-config \
  openssl openssl-tool zlib wget curl jq nano \
  openssh termux-tools coreutils

# 1) Storage permission (optional but nice)
say "Requesting storage permission (optional)..."
termux-setup-storage || true

# 2) SSH setup
say "Setting up SSH..."
if ! command -v sshd >/dev/null 2>&1; then
  pkg install -y openssh
fi

# Ensure ssh config directory exists
mkdir -p "$PREFIX/etc/ssh"

# Create host keys if missing
if [ ! -f "$PREFIX/etc/ssh/ssh_host_rsa_key" ]; then
  say "Generating SSH host keys..."
  ssh-keygen -A
fi

# Start sshd now
say "Starting sshd..."
sshd || true

# Password: prefer argument, else prompt
SSH_PW="${1:-}"
if [ -z "$SSH_PW" ]; then
  echo
  warn "Set a password for the 'u0_aXXX' Termux user (used for SSH login)."
  warn "If you prefer key-only auth, you can still set a strong password here."
  read -rsp "Enter new password: " SSH_PW
  echo
fi

say "Setting Termux user password..."
echo -e "${SSH_PW}\n${SSH_PW}" | passwd

# Optional: show how to connect
USER_NAME="$(whoami)"
IP_ADDR="$(ip -o -4 addr show | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
say "SSH ready. Connect from LAN:"
echo "  ssh ${USER_NAME}@${IP_ADDR} -p 8022"

# 3) Worker auto-name
say "Detecting device serial for worker name..."
SERIAL="$(getprop ro.serialno 2>/dev/null | tr -d '\r' || true)"
if [ -z "$SERIAL" ] || [ "$SERIAL" = "unknown" ]; then
  SERIAL="$(getprop ro.boot.serialno 2>/dev/null | tr -d '\r' || true)"
fi
if [ -z "$SERIAL" ] || [ "$SERIAL" = "unknown" ]; then
  SERIAL="$(getprop ro.product.model 2>/dev/null | tr ' ' '_' || true)"
fi
if [ -z "$SERIAL" ]; then SERIAL="termux"; fi

# 4) Config file
say "Creating config.env..."
if [ ! -f "$REPO_DIR/config.env" ]; then
  cp -f "$REPO_DIR/config.env.example" "$REPO_DIR/config.env" 2>/dev/null || true
fi

# If repo not in place (user cloned elsewhere), fallback:
if [ ! -f "$HOME/bc2-termux-miner/config.env.example" ]; then
  warn "Run this script from inside your cloned repo folder."
fi

# Ensure config exists even if example missing
touch "$HOME/bc2-termux-miner/config.env"
# Append SERIAL export if not present
grep -q '^DEVICE_SERIAL=' "$HOME/bc2-termux-miner/config.env" 2>/dev/null || \
  echo "DEVICE_SERIAL=\"$SERIAL\"" >> "$HOME/bc2-termux-miner/config.env"

# 5) Build cpuminer-opt
say "Cloning/building JayDDee/cpuminer-opt..."
if [ ! -d "$CPUMINER_DIR" ]; then
  git clone --depth 1 https://github.com/JayDDee/cpuminer-opt "$CPUMINER_DIR"
else
  (cd "$CPUMINER_DIR" && git pull --ff-only) || true
fi

cd "$CPUMINER_DIR"

# Termux sometimes lacks 'ar' if binutils isn't installed:
say "Ensuring binutils (ar) is installed..."
pkg install -y binutils

# Build script: armv8
if [ -x "./build-armv8.sh" ]; then
  bash ./build-armv8.sh
else
  # fallback standard build
  ./autogen.sh
  ./configure CFLAGS="-O3" --with-crypto
  make -j"$(nproc)"
fi

say "Build complete."

# 6) Create start/stop helpers
say "Creating helper scripts..."
cat > "$HOME/bc2-termux-miner/start.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/bc2-termux-miner"
source ./config.env

# Required vars
: "${POOL_HOST:?set POOL_HOST in config.env}"
: "${POOL_PORT:?set POOL_PORT in config.env}"
: "${WALLET:?set WALLET in config.env}"

SERIAL="${DEVICE_SERIAL:-termux}"
WORKER="${WORKER_PREFIX:-phone}-${SERIAL}"
USER="${WALLET}.${WORKER}"
PASS="${PASSWORD:-x}"
ALGO="${ALGO:-sha256d}"
THREADS="${THREADS:-4}"

MINER="$HOME/cpuminer-opt/cpuminer"

if [ ! -x "$MINER" ]; then
  echo "cpuminer not found at $MINER"
  echo "Run: bash install.sh"
  exit 1
fi

POOL="stratum+tcp://${POOL_HOST}:${POOL_PORT}"

echo "Starting miner:"
echo "  POOL=$POOL"
echo "  USER=$USER"
echo "  THREADS=$THREADS"
echo

# Run in foreground; use 'nohup ./start.sh &' if you want background
exec "$MINER" -a "$ALGO" -o "$POOL" -u "$USER" -p "$PASS" -t "$THREADS" ${EXTRA_FLAGS:-}
EOF
chmod +x "$HOME/bc2-termux-miner/start.sh"

cat > "$HOME/bc2-termux-miner/stop.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -f "$HOME/cpuminer-opt/cpuminer" || true
echo "Stopped."
EOF
chmod +x "$HOME/bc2-termux-miner/stop.sh"

cat > "$HOME/bc2-termux-miner/status.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pgrep -af "$HOME/cpuminer-opt/cpuminer" || echo "Not running."
EOF
chmod +x "$HOME/bc2-termux-miner/status.sh"

# 7) Optional: auto-start on boot (requires Termux:Boot app)
say "Optional: set up auto-start on boot (Termux:Boot)..."
pkg install -y termux-services || true

mkdir -p "$HOME/.termux/boot"
cat > "$HOME/.termux/boot/start-miner.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Give network time to come up
sleep 20
cd "$HOME/bc2-termux-miner"
nohup ./start.sh > "$HOME/bc2-termux-miner/miner.log" 2>&1 &
EOF
chmod +x "$HOME/.termux/boot/start-miner.sh"

say "DONE ✅"
echo
echo "Next:"
echo "  1) Edit: nano \$HOME/bc2-termux-miner/config.env"
echo "  2) Start: \$HOME/bc2-termux-miner/start.sh"
echo "  3) Logs:  tail -f \$HOME/bc2-termux-miner/miner.log (if boot/nohup)"
EOF
