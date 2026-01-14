#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Load config
source ./config.env

MINER_BIN="./cpuminer-opt/cpuminer"
LOG="logs/miner.log"
PID="run/miner.pid"
WDPID="run/watchdog.pid"

if [ ! -x "$MINER_BIN" ]; then
  echo "Miner binary not found/executable: $MINER_BIN"
  echo "Run: bash install.sh"
  exit 1
fi

# Build stratum user string: WALLET.WORKER
USER="${WALLET}"
if [ -n "${WORKER:-}" ]; then
  USER="${WALLET}.${WORKER}"
fi

URL="stratum+tcp://${POOL_HOST}:${POOL_PORT}"

echo "== Starting Handwarmer =="
echo "URL:    $URL"
echo "USER:   $USER"
echo "THREADS:${THREADS}"
echo "LOG:    $LOG"

# Stop any existing
bash ./stop.sh >/dev/null 2>&1 || true

# Start miner (nohup background)
nohup "$MINER_BIN" \
  -a sha256d \
  -o "$URL" \
  -u "$USER" \
  -p "${POOL_PASS}" \
  -t "${THREADS}" \
  ${EXTRA_FLAGS:-} \
  >> "$LOG" 2>&1 &

echo $! > "$PID"
sleep 1

# Watchdog (restarts miner if it dies or log shows stratum_recv_line failed)
echo "== Starting watchdog =="
nohup bash -c '
  set -e
  while true; do
    if [ ! -f run/miner.pid ]; then sleep '"${WATCHDOG_SLEEP}"'; continue; fi
    MPID="$(cat run/miner.pid 2>/dev/null || true)"
    if [ -z "$MPID" ] || ! kill -0 "$MPID" 2>/dev/null; then
      echo "[watchdog] miner not running -> restarting" >> logs/miner.log
      bash start.sh >/dev/null 2>&1
      exit 0
    fi

    # If last ~50 lines contain recv_line failed, restart
    if tail -n 80 logs/miner.log 2>/dev/null | grep -qi "stratum_recv_line failed"; then
      echo "[watchdog] detected stratum_recv_line failed -> restarting" >> logs/miner.log
      bash stop.sh >/dev/null 2>&1
      sleep 2
      bash start.sh >/dev/null 2>&1
      exit 0
    fi

    sleep '"${WATCHDOG_SLEEP}"'
  done
' >> "$LOG" 2>&1 &

echo $! > "$WDPID"

echo "✅ Miner started. LFG DeskNuts"
echo "   Tail logs: tail -f $LOG"

