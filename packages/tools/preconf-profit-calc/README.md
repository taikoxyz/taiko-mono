# Taiko L1 Event Monitor

A high-performance Rust implementation for monitoring TaikoInbox events on Ethereum mainnet.

## Features

- Fast batch processing of historical blocks
- Real-time event monitoring
- Automatic contract deployment block detection
- Configurable batch sizes for optimal performance
- Rate limit handling with automatic retries

## Installation

```bash
# Build the project
cargo build --release

# The binary will be at: target/release/preconf-profit-calc
```

## Configuration

Create a `.env` file with your settings:

```env
# Ethereum RPC URL (required)
RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY

# TaikoInbox contract address
INBOX_ADDRESS=0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a

# Optional: Starting block (defaults to interactive mode)
START_BLOCK=22980000

# Optional: Log level
LOG_LEVEL=info
```

## Usage

### Interactive Mode

```bash
./target/release/preconf-profit-calc
```

### Start from Latest Block

```bash
./target/release/preconf-profit-calc --latest
```

### Find and Start from Contract Deployment

```bash
./target/release/preconf-profit-calc --find-deployment
```

### Process Specific Block Range

```bash
./target/release/preconf-profit-calc --start-block 22980000 --end-block 22990000
```

### Custom Batch Size (for faster processing)

```bash
./target/release/preconf-profit-calc --start-block 22980000 --batch-size 1000
```

## Event Types Monitored

- **BatchProposed**: New batch proposals submitted to TaikoInbox
- **BatchesProved**: Proof submissions for batches
- **BatchesVerified**: Batch verification completions

## Performance Tips

1. Use larger batch sizes (up to 5000) for historical data processing
2. Reduce batch size if you encounter rate limits
3. The tool automatically switches to live monitoring after catching up

### Custom Poll Interval for Live Mode

```bash
./target/release/preconf-profit-calc --poll-interval 5  # Check every 5 seconds instead of default 12
```

## Event Types Monitored

The monitor tracks these TaikoInbox events:

- **BatchProposed**: New batch proposals with proposer address
- **BatchesProved**: Proof submissions with verifier address and batch IDs
- **BatchesVerified**: Batch verification with batch ID
- **StatsUpdated**: Protocol statistics updates

## Example Output

```
=== Taiko L1 Event Monitor (Rust Implementation) ===
High-performance event monitoring with batch processing

Connected to Ethereum node: Geth/v1.15.11
Monitoring TaikoInbox at: 0x06a9ab27c7e2255df1815e6cc0168d7755feb19a
Current block: 22982753

[2025-07-23 13:15:47] BatchProposed Event
  Block: 22982105
  Transaction: 0xc0a5a353bbc096bc6e1833e5b5de5942447bd1ac1b361adcd10700d6bfa5cd07
  Log Index: 0x302
  Decoded Data:
    Batch ID: 999999
    Proposer: 0x68d30f47f19c07bccef4ac7fae2dc12fca3e0dc9
    Proposed At: 0

[2025-07-23 13:15:47] BatchesProved Event
  Block: 22982105
  Transaction: 0xc0a5a353bbc096bc6e1833e5b5de5942447bd1ac1b361adcd10700d6bfa5cd07
  Log Index: 0x303
  Decoded Data:
    Verifier: 0xcf269a8aa0b5aba28eb994dee7d1e1c5cc7cda5f

[2025-07-23 13:15:47] BatchesVerified Event
  Block: 22982105
  Transaction: 0xc0a5a353bbc096bc6e1833e5b5de5942447bd1ac1b361adcd10700d6bfa5cd07
  Log Index: 0x304
  Decoded Data:
    Batch ID: 1276310
    Block Hash: 0x0000000000000000000000000000000000000000000000000000000000000000

=== L1 Cost Tracking Summary ===
Total batches tracked: 1
Verified batches: 0

By Proposer:
  0x68d30f47f19c07bccef4ac7fae2dc12fca3e0dc9: 1 batches
```

## Architecture

The implementation is modular with comprehensive documentation:

- `config.rs` - Command-line argument parsing
- `cost.rs` - L1 cost tracking (revenue is on L2)
- `decoder.rs` - Event data decoding
- `events.rs` - Event signature definitions
- `monitor.rs` - Core monitoring logic
- `rpc.rs` - Ethereum RPC client
- `types.rs` - Common data structures

## Development

Current implementation includes:

- ✅ Event monitoring and batch processing
- ✅ Basic event decoding
- ✅ Cost tracking structure
- ✅ Configurable poll intervals

Future improvements:

- Full ABI decoding for complete event data
- Transaction receipt fetching for gas costs
- Database storage for historical analysis
- Analytics and reporting features
