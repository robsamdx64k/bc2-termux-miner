#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "== bc2-termux-miner status =="

echo
echo "-- Device --"
echo "User: $(whoami)"
echo "IP(s):"
ip a | grep "inet " | grep -v "127.0.0.1" || true

echo
echo "-- Processes --"
if [ -f run/miner.pid ]; then
  MPID="$(cat run/miner.pid 2>/dev/null || true)"
  echo "Miner PID: $MPID"
  ps -o pid,cmd -p "$MPID" 2>/dev/null || echo "Miner not running"
else
  echo "Miner PID: (none)"
fi

if [ -f run/watchdog.pid ]; then
  WDPID="$(cat run/watchdog.pid 2>/dev/null || true)"
  echo "Watchdog PID: $WDPID"
  ps -o pid,cmd -p "$WDPID" 2>/dev/null || echo "Watchdog not running"
else
  echo "Watchdog PID: (none)"
fi

echo
echo "-- Ports --"
ss -lntp 2>/dev/null | grep -E "8022|ssh" || true

echo
echo "-- Log tail (last 40 lines) --"
tail -n 40 logs/miner.log 2>/dev/null || echo "No logs yet."
