#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "🔥 bc2-termux-miner installer"
echo "By BobFarms / DeskNuts / ChatGPT"
echo "================================"

REPO_URL="https://github.com/robsamdx64k/bc2-termux-miner.git"
REPO_DIR="$HOME/bc2-termux-miner"

echo "== Updating Termux =="
pkg update -y && pkg upgrade -y

echo "== Installing dependencies =="
pkg install -y \
  git clang make binutils \
  autoconf automake libtool pkg-config \
  openssl libcurl \
  openssh termux-services \
  coreutils findutils util-linux

termux-wake-lock || true

# ---------------- SSH ----------------
echo "== Enabling SSH (port 8022) =="
sv-enable sshd || true
sv up sshd || true

echo
echo "== Set SSH Password =="
if [ -z "${BC2_SSH_PASSWORD:-}" ]; then
  echo "No BC2_SSH_PASSWORD env set — asking user"
  read -s -p "Enter SSH password for this phone: " 123
  echo
fi

echo -e "$BC2_SSH_PASSWORD\n$BC2_SSH_PASSWORD" | passwd
echo "SSH password set"

SSHD_CFG="$PREFIX/etc/ssh/sshd_config"
if [ -f "$SSHD_CFG" ]; then
  sed -i 's/^#\?Port .*/Port 8022/' "$SSHD_CFG" || true
  grep -q "^Port" "$SSHD_CFG" || echo "Port 8022" >> "$SSHD_CFG"
fi

echo "SSH is running on port 8022"

# ---------------- Repo ----------------
if [ ! -d "$REPO_DIR" ]; then
  echo "== Cloning bc2-termux-miner =="
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# ---------------- Device ID ----------------
SERIAL="$(getprop ro.serialno 2>/dev/null)"
[ -z "$SERIAL" ] || [ "$SERIAL" = "unknown" ] && SERIAL="$(settings get secure android_id 2>/dev/null)"
[ -z "$SERIAL" ] && SERIAL="$(date +%s)"

WORKER="phone-${SERIAL: -4}"
echo "Auto worker: $WORKER"

# ---------------- Config ----------------
if [ ! -f config.env.example ]; then
cat > config.env.example <<EOF
WALLET=bc1q8daepl4txsz3n325rafdddwf9drhynjpt3tekt
POOL=100.67.218.96
PORT=3333
THREADS=8
WORKER=""
EOF
fi

[ ! -f config.env ] && cp config.env.example config.env

grep -q '^WORKER=' config.env || echo 'WORKER=""' >> config.env
sed -i "s/^WORKER=\"\"/WORKER=\"$WORKER\"/" config.env

# ---------------- Miner ----------------
echo "== Installing cpuminer-opt (JayDDee) =="

if [ ! -d cpuminer-opt ]; then
  git clone https://github.com/JayDDee/cpuminer-opt.git
fi

cd cpuminer-opt

if [ -f build-armv8.sh ]; then
  bash build-armv8.sh
else
  ./autogen.sh
  ./configure CFLAGS="-O3"
  make -j$(nproc)
fi

cd ..

# ---------------- Scripts ----------------
cat > start.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
source config.env
./cpuminer-opt/cpuminer \
  -a sha256d \
  -o stratum+tcp://$POOL:$PORT \
  -u $WALLET.$WORKER \
  -t $THREADS
EOF

cat > status.sh <<'EOF'
ps aux | grep cpuminer | grep -v grep
EOF

chmod +x start.sh status.sh

echo ""
echo "🔥 INSTALL COMPLETE 🔥"
echo "======================"
echo "Worker: $WORKER"
echo ""
echo "To start mining:"
echo "   cd ~/bc2-termux-miner"
echo "   bash start.sh"
echo ""
echo "To SSH in:"
echo "   ssh -p 8022 u0_aXXX@PHONE_IP"
