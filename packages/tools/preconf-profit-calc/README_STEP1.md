# Step 1: Barebone Event Monitor

This is the first step of the incremental implementation - a basic event subscription program that monitors TaikoInbox events and prints them to console.

## Features

- Connects to Ethereum RPC endpoint
- Monitors BatchProposed, BatchesProved, and BatchesVerified events
- Prints raw event data to console
- Supports both historical and live monitoring
- Progress indicators for long-running processes

## Setup

1. Create and activate virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Configure environment:

```bash
cp .env.example .env
# Edit .env with your RPC URL and contract address
```

## Usage

### Basic usage (will prompt for options):

```bash
python step1_event_monitor.py
```

### Start from specific block:

```bash
python step1_event_monitor.py --start-block 19000000
```

### Process historical range:

```bash
python step1_event_monitor.py --start-block 19000000 --end-block 19001000
```

### Start from latest block:

```bash
python step1_event_monitor.py --latest
```

### Override configuration:

```bash
python step1_event_monitor.py \
    --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY \
    --inbox-address 0x1234...
```

## Example Output

```
=== Taiko L1 Event Monitor (Step 1: Barebone) ===
This version subscribes to events and prints raw data

Connected to Ethereum node: Geth/v1.13.0-stable/linux-amd64/go1.21.0
Monitoring TaikoInbox at: 0x1234567890123456789012345678901234567890
Current block: 19234567
--------------------------------------------------------------------------------

Starting event monitoring from block 19234567
Press Ctrl+C to stop

================================================================================
Found 1 event(s) in block 19234568
================================================================================

[2024-01-15 10:23:45] BatchProposed Event
  Block: 19234568
  Transaction: 0xabcd1234...
  Log Index: 42
  Topics:
    [0] 0x5e51a11eb3e8d3d27b9c6e9a39ad56b2b1af901f7fb3cb12c287f5fda9734ae8
    [1] 0x00000000000000000000000000000000000000000000000000000000000004d2
  Data: 0x0000000000000000000000001234567890abcdef...

Processed up to block 19234600 (latest: 19234650)
```

## What's Next

In Step 2, we will:

- Parse the raw event data into meaningful fields
- Calculate transaction costs
- Track transition IDs
- Display formatted batch and cost information

## Notes

- Event signatures are hardcoded for now (will use ABI in later steps)
- No data persistence - everything is printed to console
- Basic error handling with retry logic
- Progress updates every 100 blocks
