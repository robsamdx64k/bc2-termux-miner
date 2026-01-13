# bc2-termux-miner 🔥
One-command onboarding for Android phones (Termux) to mine **BC2 (sha256d)** on your **local Miningcore**.

- Auto-installer
- Auto SSH setup
- Auto device naming from serial
- One-command phone onboarding
- Phone-friendly low-diff port (default :3333)
- Watchdog auto-restarts miner on disconnects

> Designed for BobFarms-style scaling (dozens → hundreds of phones).

---

## Your pool layout (recommended)

Miningcore ports (example):
- **ASICs:** `stratum+tcp://192.168.68.182:3334` (starting diff ~36420)
- **Phones:** `stratum+tcp://192.168.68.182:3333` (starting diff ~256, VarDiff enabled)

---

## Quick start (fresh Termux)

### 1) Install Termux
Install Termux from F-Droid (recommended) or Play store if that’s what you have.

### 2) One command
```bash
pkg update -y && pkg install -y git
git clone https://github.com/robsamdx64k/bc2-termux-miner
cd bc2-termux-miner
bash install.sh





Configure:
cp config.env.example config.env
nano config.env

Start mining:
bash start.sh

Check status:
bash status.sh

Stop:
bash stop.sh



Use the auto worker naming (bc1... .phone-XXXX) so your Miningcore UI stays clean.

Keep phones on the phone port (:3333) so shares aren’t 1/hour.

If you’re running hundreds of phones, consider:

A local stratum proxy per hub (optional future feature)

Staggered restarts


“ar: No such file or directory”

Fixed by installing binutils (installer does this). If you hit it manually:

pkg install -y binutils

Miner disconnects / stratum_recv_line failed

The watchdog will restart automatically. You can also:

Lower threads

Confirm your phone port VarDiff targetTime isn’t too aggressive

Ensure Wi-Fi power saving is disabled

Files

install.sh - installs deps, builds miner, sets up SSH

start.sh - starts miner + watchdog

stop.sh - stops miner

status.sh - shows status/log tail + quick stats

config.env.example - your settings template

boot/ - optional auto-start hooks
