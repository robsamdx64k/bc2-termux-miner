#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "== 🔥💰🖨️ BC2 Miner armv8 Installer 🔥🔥🔥 =="
#!/data/data/com.termux/files/usr/bin/bash
set -eu
(set -o pipefail) 2>/dev/null && set -o pipefail || true

REPO_URL="https://github.com/robsamdx64k/bc2-termux-miner"
REPO_DIR="$HOME/bc2-termux-miner"

POOL_URL_DEFAULT='stratum+tcp://bobfarm.ddns.net:3333'
WALLET_DEFAULT='bc1q8daepl4txsz3n325rafdddwf9drhynjpt3tekt'
THREADS_DEFAULT='8'
SSH_PASS_DEFAULT='bf123'

echo "== bc2-termux-miner installer By Caint Hosting and ChatGPT sup =="

echo "== Updating Termux packages =="
pkg update -y
pkg upgrade -y

echo "== Installing deps =="
pkg install -y \
  git clang make binutils \
  autoconf automake libtool pkg-config \
  openssl libcurl \
  openssh termux-services \
  coreutils findutils util-linux \
  iproute2 dos2unix netcat-openbsd

termux-wake-lock >/dev/null 2>&1 || true

echo "== Enabling SSH (port 8022) =="
sv-enable sshd >/dev/null 2>&1 || true

SSHD_CFG="$PREFIX/etc/ssh/sshd_config"
mkdir -p "$PREFIX/etc/ssh"
if [ -f "$SSHD_CFG" ]; then
  if grep -q "^Port " "$SSHD_CFG"; then
    sed -i 's/^Port .*/Port 8022/' "$SSHD_CFG"
  else
    echo "Port 8022" >> "$SSHD_CFG"
  fi
else
  cat > "$SSHD_CFG" <<'EOF'
Port 8022
PasswordAuthentication yes
PermitRootLogin no
Subsystem sftp /data/data/com.termux/files/usr/libexec/sftp-server
EOF
fi

echo "== Setting SSH password (${SSH_PASS_DEFAULT}) =="
echo -e "${SSH_PASS_DEFAULT}\n${SSH_PASS_DEFAULT}" | passwd >/dev/null
sv up sshd >/dev/null 2>&1 || true
echo "SSH is running on port 8022"

echo "== Cloning bc2-termux-miner =="
rm -rf "$REPO_DIR"
git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

# normalize line endings (fixes ^M + bash interpreter issues)
dos2unix *.sh >/dev/null 2>&1 || true

echo "== Creating device name =="
SERIAL="$(getprop ro.serialno 2>/dev/null || true)"
if [ -z "${SERIAL}" ] || [ "${SERIAL}" = "unknown" ]; then
  SERIAL="$(settings get secure android_id 2>/dev/null || true)"
fi
[ -n "${SERIAL}" ] || SERIAL="phone$(date +%s)"
SHORT="${SERIAL: -4}"
AUTO_WORKER="phone-${SHORT}"
echo "Auto worker name: ${AUTO_WORKER}"

echo "== Creating config.env =="
[ -f "config.env" ] || cp -f config.env.example config.env

# Fill defaults (safe replace or append)
grep -q '^POOL_URL=' config.env && sed -i "s|^POOL_URL=.*|POOL_URL=\"${POOL_URL_DEFAULT}\"|" config.env || echo "POOL_URL=\"${POOL_URL_DEFAULT}\"" >> config.env
grep -q '^WALLET='   config.env && sed -i "s|^WALLET=.*|WALLET=\"${WALLET_DEFAULT}\"|"     config.env || echo "WALLET=\"${WALLET_DEFAULT}\"" >> config.env
grep -q '^THREADS='  config.env && sed -i "s|^THREADS=.*|THREADS=\"${THREADS_DEFAULT}\"|"  config.env || echo "THREADS=\"${THREADS_DEFAULT}\"" >> config.env
grep -q '^POOL_PASS=' config.env || echo 'POOL_PASS="x"' >> config.env
grep -q '^WATCHDOG_SLEEP=' config.env || echo 'WATCHDOG_SLEEP="10"' >> config.env

# Set WORKER only if blank/missing
if grep -q '^WORKER=""' config.env 2>/dev/null; then
  sed -i "s/^WORKER=\"\"/WORKER=\"${AUTO_WORKER}\"/" config.env
elif ! grep -q '^WORKER=' config.env 2>/dev/null; then
  echo "WORKER=\"${AUTO_WORKER}\"" >> config.env
fi

echo "== Building cpuminer-opt (JayDDee) =="
cd "$HOME"
if [ ! -d "cpuminer-opt" ]; then
  git clone https://github.com/JayDDee/cpuminer-opt
fi
cd cpuminer-opt
dos2unix *.sh >/dev/null 2>&1 || true

if [ -f "./build-armv8.sh" ]; then
  bash ./build-armv8.sh
elif [ -f "./build.sh" ]; then
  bash ./build.sh
else
  ./autogen.sh
  ./configure CFLAGS="-O3"
  make -j"$(nproc)"
fi

cd "$REPO_DIR"

echo "== Wiring miner path + runtime dirs =="
mkdir -p run logs boot
chmod +x *.sh

# Force start.sh to use the cpuminer we built
sed -i 's|^MINER_BIN=.*|MINER_BIN="$HOME/cpuminer-opt/cpuminer"|' start.sh

echo "== Auto-starting miner =="
bash start.sh || true

echo
echo "== Install complete. LFG DeskNuts 🔥 =="
echo "Repo: $REPO_DIR"
echo "Start:  bash $REPO_DIR/start.sh"
echo "Status: bash $REPO_DIR/status.sh"
echo "Stop:   bash $REPO_DIR/stop.sh"
echo "SSH:    ssh -p 8022 \$(whoami)@<phone-ip>   (pw: ${SSH_PASS_DEFAULT})"

# -------------------- SETTINGS (edit if you want) --------------------
DEFAULT_SSH_PASSWORD="bf123"

# Your pool (Miningcore on LAN)
DEFAULT_POOL_HOST="192.168.68.182"
DEFAULT_POOL_PORT="3333"   # phones port (low diff)
DEFAULT_ALGO="sha256d"

# Your payout wallet
DEFAULT_WALLET="bc1q8daepl4txsz3n325rafdddwf9drhynjpt3tekt"

# Phone threads (you said 8)
DEFAULT_THREADS="8"

# Repo to clone (this repo)
REPO_URL="https://github.com/robsamdx64k/bc2-termux-miner"
REPO_DIR="$HOME/bc2-termux-miner"

# Miner repo
MINER_URL="https://github.com/JayDDee/cpuminer-opt"
MINER_DIR="$HOME/cpuminer-opt"
# --------------------------------------------------------------------

# -------------------- Termux basics --------------------
pkg update -y
pkg upgrade -y

pkg install -y \
  git clang make binutils \
  autoconf automake libtool pkg-config \
  openssl libcurl \
  openssh termux-services \
  coreutils findutils util-linux

termux-wake-lock >/dev/null 2>&1 || true

# -------------------- SSH setup --------------------
echo "== Enabling SSH (port 8022) =="

# enable sshd service
sv-enable sshd >/dev/null 2>&1 || true

# ensure port 8022 in sshd_config if the file exists
SSHD_CFG="$PREFIX/etc/ssh/sshd_config"
if [ -f "$SSHD_CFG" ]; then
  if grep -q '^Port ' "$SSHD_CFG"; then
    sed -i 's/^Port .*/Port 8022/' "$SSHD_CFG"
  else
    echo "Port 8022" >> "$SSHD_CFG"
  fi
fi

# set password (Termux uses passwd for user u0_aNNN)
echo "== Setting SSH password (${DEFAULT_SSH_PASSWORD}) =="
printf "%s\n%s\n" "$DEFAULT_SSH_PASSWORD" "$DEFAULT_SSH_PASSWORD" | passwd >/dev/null

# start sshd now
sv up sshd >/dev/null 2>&1 || true
echo "SSH is running on port 8022 (user is your Termux user)."
echo "Test from LAN: ssh -p 8022 <phone-ip>"

# -------------------- Clone / update this repo --------------------
echo "== Cloning/updating bc2-termux-miner repo =="

if [ ! -d "$REPO_DIR/.git" ]; then
  rm -rf "$REPO_DIR" >/dev/null 2>&1 || true
  git clone "$REPO_URL" "$REPO_DIR"
else
  (cd "$REPO_DIR" && git pull --rebase || true)
fi

cd "$REPO_DIR"

# -------------------- Auto worker name --------------------
echo "== Creating device name =="
SERIAL="$(getprop ro.serialno 2>/dev/null || true)"
if [ -z "${SERIAL}" ] || [ "${SERIAL}" = "unknown" ]; then
  SERIAL="$(settings get secure android_id 2>/dev/null || true)"
fi
if [ -z "${SERIAL}" ] || [ "${SERIAL}" = "null" ]; then
  SERIAL="phone$(date +%s)"
fi
SHORT="${SERIAL: -4}"
AUTO_WORKER="phone-${SHORT}"
echo "Auto worker: ${AUTO_WORKER}"

# -------------------- Config env --------------------
echo "== Creating config.env =="

if [ ! -f "config.env.example" ]; then
  echo "ERROR: config.env.example missing in repo. Add it, commit, re-run."
  exit 1
fi

if [ ! -f "config.env" ]; then
  cp -f config.env.example config.env
fi

# ensure keys exist (append if missing)
ensure_kv () {
  local key="$1"
  local val="$2"
  if grep -q "^${key}=" config.env; then
    # replace
    sed -i "s|^${key}=.*|${key}=\"${val}\"|g" config.env
  else
    echo "${key}=\"${val}\"" >> config.env
  fi
}

ensure_kv "WALLET"   "$DEFAULT_WALLET"
ensure_kv "POOL_URL" "stratum+tcp://${DEFAULT_POOL_HOST}:${DEFAULT_POOL_PORT}"
ensure_kv "ALGO"     "$DEFAULT_ALGO"
ensure_kv "THREADS"  "$DEFAULT_THREADS"
ensure_kv "WORKER"   "$AUTO_WORKER"

echo "Wrote config.env:"
grep -E '^(WALLET|POOL_URL|ALGO|THREADS|WORKER)=' config.env || true

# -------------------- Build cpuminer-opt --------------------
echo "== Cloning/building cpuminer-opt =="

if [ ! -d "$MINER_DIR/.git" ]; then
  rm -rf "$MINER_DIR" >/dev/null 2>&1 || true
  git clone "$MINER_URL" "$MINER_DIR"
else
  (cd "$MINER_DIR" && git pull --rebase || true)
fi

cd "$MINER_DIR"

# preferred: armv8 script if present
if [ -f "./build-armv8.sh" ]; then
  bash ./build-armv8.sh
elif [ -f "./build.sh" ]; then
  bash ./build.sh
else
  ./autogen.sh
  ./configure CFLAGS="-O3"
  make -j"$(nproc)"
fi

cd "$REPO_DIR"

# -------------------- Done --------------------
echo
echo "== Install complete =="
echo "Next:"
echo "  cd ~/bc2-termux-miner"
echo "  nano config.env        # optional edits"
echo "  bash start.sh"
echo "  bash status.sh"
