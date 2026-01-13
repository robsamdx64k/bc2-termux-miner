#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

kill_pidfile () {
  local f="$1"
  if [ -f "$f" ]; then
    local p
    p="$(cat "$f" 2>/dev/null || true)"
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
      kill "$p" 2>/dev/null || true
    fi
    rm -f "$f"
  fi
}

kill_pidfile "run/watchdog.pid"
kill_pidfile "run/miner.pid"

# Also kill any stray cpuminer processes
pkill -f "/cpuminer" 2>/dev/null || true

echo "🛑 Stopped. Get a Gatoraid and LFG"
