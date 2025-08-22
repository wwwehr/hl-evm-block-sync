# 🚀 Hyperliquid DEX – S3Sync Runner

Fastest way to pull down evm block files from s3

This script automates syncing **massive S3 object stores** in a **safe, resumable, and time-tracked way**. The traditional `s3 sync` is just wayy to slow.

## Features

- ✅ Auto-installs [nidor1998/s3sync](https://github.com/nidor1998/s3sync) (latest release) into `~/.local/bin`  
- ✅ Sequential per-prefix syncs (e.g., `21000000/`, `22000000/`, …)  
- ✅ Per-prefix timing: `22000000 took 12 minutes!`  
- ✅ Total runtime summary at the end  
- ✅ Designed for **tiny files at scale** (EVM block archives)  
- ✅ Zero-config bootstrap — just run the script  

## Quick Start

Instead of cloning a full repo, you can just download the runner script directly:

```bash
curl -L -o s3sync-runner.sh https://raw.githubusercontent.com/wwwehr/hl-evm-block-sync/refs/heads/master/sync.sh
chmod +x s3sync-runner.sh
./s3sync-runner.sh
```

> Skipping to relevant block section
```bash
./s3sync-runner.sh --start-at 30000000
```

The script will:
* Install or update s3sync into ~/.local/bin
* Discover top-level prefixes in your S3 bucket
* Sync them one at a time, printing elapsed minutes

## Configuration

Edit the top of s3sync-runner.sh if needed:
```bash
BUCKET="hl-testnet-evm-blocks"   # could be hl-mainnet-evm-blocks
REGION="ap-northeast-1"          # hardcoded bucket region
DEST="$HOME/evm-blocks-testnet"  # local target directory (this is what nanoreth will look at)
WORKERS=512                      # worker threads per sync (lotsa workers needs lotsa RAM)
```

## Example Output
```bash
[2025-08-20 20:01:02] START  21000000
[2025-08-20 20:13:15] 21000000 took 12 minutes!
[2025-08-20 20:13:15] START  22000000
[2025-08-20 20:26:40] 22000000 took 13 minutes!
[2025-08-20 20:26:40] ALL DONE in 25 minutes.
```

## Hackathon Context

This runner was built as part of the Hyperliquid DEX Hackathon to accelerate:
* ⛓️ Blockchain archive node ingestion
* 📂 EVM block dataset replication
* 🧩 DEX ecosystem data pipelines
