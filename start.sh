#!/data/data/com.termux/files/usr/bin/bash
set -eu
(set -o pipefail) 2>/dev/null && set -o pipefail || true

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Ensure dirs exist
mkdir -p logs run

# Load config
if [ ! -f "./config.env" ]; then
  echo "Missing ./config.env"
  echo "Fix: cp config.env.example config.env && nano config.env"
  exit 1
fi
. ./config.env

# Defaults (prevents 'unbound variable' crashes)
: "${POOL_PASS:=x}"
: "${THREADS:=8}"
: "${WATCHDOG_SLEEP:=15}"
: "${EXTRA_FLAGS:=}"

# Prefer global build in ~/cpuminer-opt; fallback to repo-local cpuminer-opt
MINER_BIN="${MINER_BIN:-$HOME/cpuminer-opt/cpuminer}"
if [ ! -x "$MINER_BIN" ] && [ -x "$DIR/cpuminer-opt/cpuminer" ]; then
  MINER_BIN="$DIR/cpuminer-opt/cpuminer"
fi

LOG="logs/miner.log"
PID="run/miner.pid"
WDPID="run/watchdog.pid"

if [ ! -x "$MINER_BIN" ]; then
  echo "Miner binary not found/executable: $MINER_BIN"
  echo "Build it first (one-time): cd ~/cpuminer-opt && make -j\$(nproc)"
  exit 1
fi

# Build stratum user string: WALLET.WORKER
USER="${WALLET}"
if [ -n "${WORKER:-}" ]; then
  USER="${WALLET}.${WORKER}"
fi

# Support either POOL_URL or POOL_HOST/POOL_PORT
if [ -n "${POOL_URL:-}" ]; then
  URL="$POOL_URL"
else
  URL="stratum+tcp://${POOL_HOST}:${POOL_PORT}"
fi

echo "== Starting Handwarmer =="
echo "BIN:    $MINER_BIN"
echo "URL:    $URL"
echo "USER:   $USER"
echo "THREADS:${THREADS}"
echo "LOG:    $LOG"

# Stop any existing miner/watchdog
bash ./stop.sh >/dev/null 2>&1 || true

# Start miner (nohup background)
nohup "$MINER_BIN" \
  -a sha256d \
  -o "$URL" \
  -u "$USER" \
  -p "$POOL_PASS" \
  -t "$THREADS" \
  $EXTRA_FLAGS \
  >> "$LOG" 2>&1 &

echo $! > "$PID"
sleep 1

# Watchdog: restarts MINER only (does NOT call start.sh to avoid recursion)
echo "== Starting watchdog =="
nohup bash -c '
  cd "'"$DIR"'"
  LOG="logs/miner.log"
  PID="run/miner.pid"

  restart_miner() {
    # kill old
    if [ -f "$PID" ]; then
      MPID="$(cat "$PID" 2>/dev/null || true)"
      if [ -n "$MPID" ]; then kill "$MPID" 2>/dev/null || true; fi
      rm -f "$PID"
    fi

    # start fresh
    nohup "'"$MINER_BIN"'" \
      -a sha256d \
      -o "'"$URL"'" \
      -u "'"$USER"'" \
      -p "'"$POOL_PASS"'" \
      -t "'"$THREADS"'" \
      '"$EXTRA_FLAGS"' \
      >> "$LOG" 2>&1 &

    echo $! > "$PID"
    echo "[watchdog] restarted miner pid=$(cat "$PID")" >> "$LOG"
  }

  while true; do
    MPID=""
    [ -f "$PID" ] && MPID="$(cat "$PID" 2>/dev/null || true)"

    if [ -z "$MPID" ] || ! kill -0 "$MPID" 2>/dev/null; then
      echo "[watchdog] miner not running -> restarting" >> "$LOG"
      restart_miner
    fi

    # if last ~120 lines contain recv_line failed or connection failed, restart
    if tail -n 120 "$LOG" 2>/dev/null | grep -Eqi "stratum_recv_line failed|Stratum connection failed"; then
      echo "[watchdog] detected stratum error -> restarting" >> "$LOG"
      restart_miner
    fi

    sleep "'"$WATCHDOG_SLEEP"'"
  done
' >> "$LOG" 2>&1 &

echo $! > "$WDPID"

echo "✅ Miner started."
echo "   Tail logs: tail -f $LOG"
