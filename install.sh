#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "== bc2-termux-miner installer By Caint Hosting and ChatGPT sup =="

# Termux basics
pkg update -y
pkg upgrade -y

# Dependencies (binutils provides 'ar' -> fixes your build error)
pkg install -y \
  git clang make binutils \
  autoconf automake libtool pkg-config \
  openssl libcurl \
  openssh termux-services \
  coreutils findutils util-linux

# Keep device awake while mining (optional but recommended)
termux-wake-lock >/dev/null 2>&1 || true

# Enable sshd service
echo "== Setting up SSH Yup! =="
sv-enable sshd >/dev/null 2>&1 || true

# Ensure sshd config exists (Termux uses default; we set port via sshd_config if present)
SSHD_CFG="$PREFIX/etc/ssh/sshd_config"
if [ -f "$SSHD_CFG" ]; then
  if ! grep -q "^Port " "$SSHD_CFG"; then
    echo "Port 8022" >> "$SSHD_CFG"
  else
    sed -i 's/^Port .*/Port 8022/' "$SSHD_CFG"
  fi
fi

# Start sshd now
sv up sshd >/dev/null 2>&1 || true
echo "SSH should be up on port 8022. (Check with: ss -lntp | grep 8022)"

# Device naming (serial preferred)
echo "== Creating device name :) =="
SERIAL="$(getprop ro.serialno 2>/dev/null || true)"
if [ -z "${SERIAL}" ] || [ "${SERIAL}" = "unknown" ]; then
  SERIAL="$(settings get secure android_id 2>/dev/null || true)"
fi
if [ -z "${SERIAL}" ]; then
  SERIAL="phone$(date +%s)"
fi
SHORT="${SERIAL: -4}"
AUTO_WORKER="phone-${SHORT}"
echo "Auto worker name: ${AUTO_WORKER}"

# If user hasn't created config.env, create it from example
if [ ! -f "config.env" ]; then
  cp -f config.env.example config.env
fi

# If WORKER is blank in config.env, set it
if grep -q '^WORKER=""' config.env; then
  sed -i "s/^WORKER=\"\"/WORKER=\"${AUTO_WORKER}\"/" config.env
fi

# Build cpuminer-opt (JayDDee)
echo "== Cloning/building cpuminer-opt (JayDDee) Thx Brooo =="
if [ ! -d "cpuminer-opt" ]; then
  git clone https://github.com/JayDDee/cpuminer-opt
fi

cd cpuminer-opt

# Use repo build scripts if present (armv8)
if [ -f "./build-armv8.sh" ]; then
  bash ./build-armv8.sh
elif [ -f "./build.sh" ]; then
  bash ./build.sh
else
  ./autogen.sh
  ./configure CFLAGS="-O3"
  make -j"$(nproc)"
fi

cd ..

# Create runtime dirs
mkdir -p run logs boot

echo
echo "== Install complete LFG DeskNuts=="
echo "Next:"
echo "  1) Edit config:   nano config.env"
echo "  2) Start miner:   bash start.sh"
echo "  3) Status:        bash status.sh"
echo
