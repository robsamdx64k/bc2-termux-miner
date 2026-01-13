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
