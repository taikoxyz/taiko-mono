# Taiko Batch L1 Cost Calculator - Final Technical Specification

## Executive Summary

A Python-based script that calculates L1 costs (proposing + proving) for verified Taiko batches by monitoring Ethereum mainnet events and contract state. The script maintains a MySQL database tracking all batch costs and proving attempts, with support for reorg handling and continuous monitoring.

## Core Algorithm

### Cost Calculation Formula

```
For each verified batch:
  final_cost = proposing_cost + verifying_transition_cost

Where:
  proposing_cost = tx_fee / number_of_BatchProposed_events_in_tx
  verifying_transition_cost = tx_fee / number_of_batches_in_BatchesProved_event
  tx_fee = gasUsed * effectiveGasPrice (in ETH, rounded down to 0.0000001)
```

## System Architecture

### Processing Pipeline

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Ethereum Node  │────▶│  Event Processor │────▶│  MySQL Database │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │ Contract Reader  │
                        │(v4GetBatchVerifying│
                        │    Transition)    │
                        └──────────────────┘
```

### Event Processing State Machine

```
1. BatchProposed → Create batch record with proposing cost
2. BatchesProved → Create transition records (increment ID per batch)
3. BatchesVerified → Query verifying transition → Update final cost
```

## Database Design

### Schema with Reorg Support

```sql
-- Main batches table
CREATE TABLE batches (
    batch_id BIGINT PRIMARY KEY,
    proposer_address VARCHAR(42) NOT NULL,  -- Checksummed format
    proposing_tx_hash VARCHAR(66) NOT NULL,
    proposing_cost DOUBLE NOT NULL,
    proposing_block_number BIGINT NOT NULL,
    first_l2_block_id BIGINT NOT NULL,
    last_l2_block_id BIGINT NOT NULL,
    metadata_hash VARCHAR(66) NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    verifying_transition_id INT DEFAULT NULL,
    verified_at_block BIGINT DEFAULT NULL,
    final_cost DOUBLE DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_proposer (proposer_address),
    INDEX idx_block (proposing_block_number),
    INDEX idx_verified (is_verified)
);

-- Transitions (proving attempts) table
CREATE TABLE transitions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    batch_id BIGINT NOT NULL,
    transition_id INT NOT NULL,
    prover_address VARCHAR(42) NOT NULL,  -- Checksummed format
    proving_tx_hash VARCHAR(66) NOT NULL,
    proving_cost DOUBLE NOT NULL,
    proving_block_number BIGINT NOT NULL,
    is_verifying BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_batch_transition (batch_id, transition_id),
    INDEX idx_prover (prover_address),
    INDEX idx_block (proving_block_number),
    FOREIGN KEY (batch_id) REFERENCES batches(batch_id) ON DELETE CASCADE
);

-- Processing state table
CREATE TABLE processing_state (
    id INT PRIMARY KEY DEFAULT 1,
    last_processed_block BIGINT NOT NULL,
    last_verified_batch_id BIGINT DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (id = 1)
);

-- Transition ID tracking per batch
CREATE TABLE batch_transition_counters (
    batch_id BIGINT PRIMARY KEY,
    next_transition_id INT NOT NULL DEFAULT 1,
    FOREIGN KEY (batch_id) REFERENCES batches(batch_id) ON DELETE CASCADE
);

-- Summary tables with history for reorg support
CREATE TABLE proposer_summary_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    block_number BIGINT NOT NULL,
    proposer_address VARCHAR(42) NOT NULL,
    total_batches INT NOT NULL,
    total_cost DOUBLE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_block_proposer (block_number, proposer_address)
);

CREATE TABLE prover_summary_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    block_number BIGINT NOT NULL,
    prover_address VARCHAR(42) NOT NULL,
    total_transitions INT NOT NULL,
    total_verified_transitions INT NOT NULL,
    total_cost DOUBLE NOT NULL,
    total_verified_cost DOUBLE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_block_prover (block_number, prover_address)
);

-- Current summaries (materialized views)
CREATE TABLE proposer_summary (
    proposer_address VARCHAR(42) PRIMARY KEY,
    total_batches INT NOT NULL,
    total_cost DOUBLE NOT NULL,
    last_updated_block BIGINT NOT NULL
);

CREATE TABLE prover_summary (
    prover_address VARCHAR(42) PRIMARY KEY,
    total_transitions INT NOT NULL,
    total_verified_transitions INT NOT NULL,
    total_cost DOUBLE NOT NULL,
    total_verified_cost DOUBLE NOT NULL,
    last_updated_block BIGINT NOT NULL
);
```

## Implementation Details

### 1. Event Processing Logic

#### BatchProposed Processing

```python
def process_batch_proposed(event, tx_receipt, block_number):
    # Count events in same transaction
    event_count = count_events_in_tx(tx_receipt, "BatchProposed")

    # Calculate cost
    total_cost = (tx_receipt.gasUsed * tx_receipt.effectiveGasPrice) / 10**18
    cost_per_batch = floor(total_cost * 10**7) / 10**7 / event_count

    # Extract batch data
    batch_data = {
        'batch_id': event.info.id,
        'proposer_address': Web3.toChecksumAddress(event.info.proposer),
        'first_l2_block_id': event.info.firstBlockId,
        'last_l2_block_id': event.info.lastBlockId,
        'metadata_hash': event.meta.metadataHash,
        'proposing_cost': cost_per_batch,
        'proposing_tx_hash': tx_receipt.transactionHash.hex(),
        'proposing_block_number': block_number
    }

    # Store in database
    db.insert_batch(batch_data)
    db.insert_batch_transition_counter(event.info.id)
```

#### BatchesProved Processing

```python
def process_batches_proved(event, tx_receipt, block_number):
    batch_count = len(event.batchIds)
    total_cost = (tx_receipt.gasUsed * tx_receipt.effectiveGasPrice) / 10**18
    cost_per_batch = floor(total_cost * 10**7) / 10**7 / batch_count

    for i, batch_id in enumerate(event.batchIds):
        # Get and increment transition ID
        transition_id = db.get_and_increment_transition_id(batch_id)

        transition_data = {
            'batch_id': batch_id,
            'transition_id': transition_id,
            'prover_address': Web3.toChecksumAddress(event.verifier),
            'proving_cost': cost_per_batch,
            'proving_tx_hash': tx_receipt.transactionHash.hex(),
            'proving_block_number': block_number
        }

        db.insert_transition(transition_data)
```

#### BatchesVerified Processing

```python
def process_batches_verified(event, block_number):
    batch_id = event.batchId

    # Query contract for verifying transition
    verifying_transition_id = contract.functions.v4GetBatchVerifyingTransition(batch_id).call()

    # Update batch as verified
    db.update_batch_verified(batch_id, verifying_transition_id, block_number)

    # Mark the verifying transition
    db.mark_transition_as_verifying(batch_id, verifying_transition_id)

    # Calculate and update final cost
    proposing_cost = db.get_batch_proposing_cost(batch_id)
    proving_cost = db.get_transition_cost(batch_id, verifying_transition_id)
    final_cost = proposing_cost + proving_cost

    db.update_batch_final_cost(batch_id, final_cost)
```

### 2. Reorg Handling

```python
def process_block(block_number):
    # Start transaction for atomic processing
    with db.transaction():
        # Delete all data from this block (reorg protection)
        db.delete_block_data(block_number)

        # Get block and filter events
        block = w3.eth.get_block(block_number)

        # Process all events in the block
        for tx_hash in block.transactions:
            receipt = w3.eth.get_transaction_receipt(tx_hash)
            process_transaction_events(receipt, block_number)

        # Update processing state
        db.update_last_processed_block(block_number)

        # Update summaries
        update_summaries(block_number)
```

### 3. Summary Update Logic

```python
def update_summaries(block_number):
    # Save current state to history
    db.save_proposer_summary_to_history(block_number)
    db.save_prover_summary_to_history(block_number)

    # Recalculate current summaries from scratch
    db.recalculate_proposer_summary()
    db.recalculate_prover_summary()
```

### 4. CLI Implementation

```python
def main():
    print("=== Taiko L1 Cost Calculator ===\n")

    # Check database state
    state = db.get_processing_state()

    if state:
        print(f"Last processed block: {state['last_processed_block']}")
        print(f"Last verified batch ID: {state['last_verified_batch_id']}\n")

        print("Choose an option:")
        print(f"1. Resume from last processed block ({state['last_processed_block'] + 1})")
        print("2. Start from a specific block")
        print("3. Purge database and start fresh")

        choice = input("\nYour choice: ")

        if choice == "1":
            start_block = state['last_processed_block'] + 1
        elif choice == "2":
            start_block = int(input("Enter starting block number: "))
            if start_block <= state['last_processed_block']:
                confirm = input(f"\nWARNING: This will delete all data for blocks >= {start_block}\nContinue? (y/n): ")
                if confirm.lower() != 'y':
                    return
                db.delete_blocks_from(start_block)
        elif choice == "3":
            confirm = input("\nWARNING: This will delete ALL data\nContinue? (y/n): ")
            if confirm.lower() != 'y':
                return
            db.purge_all_data()
            start_block = int(input("Enter starting block number: "))
    else:
        start_block = int(input("Enter starting block number: "))

    print(f"\nStarting processing from block {start_block}...")
    process_blocks_from(start_block)
```

### 5. Continuous Monitoring

```python
def process_blocks_from(start_block):
    current_block = start_block

    while True:
        try:
            latest_block = w3.eth.block_number

            # Process all blocks up to latest
            while current_block <= latest_block:
                process_block(current_block)

                if current_block % 100 == 0:
                    logger.info(f"Processed 100 blocks, current: {current_block}")

                current_block += 1

            # Wait for new blocks
            logger.info("Caught up to chain tip, waiting for new blocks...")
            time.sleep(12)  # Ethereum block time

        except Exception as e:
            logger.error(f"Error processing block {current_block}: {e}")
            time.sleep(5)  # Brief pause before retry
```

## Configuration

### Command Line Arguments

```bash
python taiko_l1_cost_calculator.py \
    --rpc-url <ETHEREUM_RPC_URL> \
    --inbox-address <TAIKO_INBOX_ADDRESS> \
    --db-host localhost \
    --db-port 3306 \
    --db-user root \
    --db-password <PASSWORD> \
    --db-name taiko_costs \
    --log-level info
```

### Environment Variables

```bash
export RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
export INBOX_ADDRESS="0x..."  # To be provided
export DB_HOST="localhost"
export DB_PORT="3306"
export DB_USER="root"
export DB_PASSWORD="password"
export DB_NAME="taiko_costs"
export LOG_LEVEL="info"
```

## Python Implementation Stack

### Dependencies

```python
# requirements.txt
web3>=6.0.0
mysql-connector-python>=8.0.0
click>=8.0.0  # For CLI
python-dotenv>=1.0.0  # For env vars
tenacity>=8.0.0  # For retry logic
```

### Project Structure

```
taiko-l1-cost-calculator/
├── src/
│   ├── __init__.py
│   ├── main.py              # CLI entry point
│   ├── config.py            # Configuration management
│   ├── database.py          # Database operations
│   ├── ethereum.py          # Web3 and contract interactions
│   ├── processor.py         # Event processing logic
│   ├── models.py            # Data models
│   └── utils.py             # Helper functions
├── migrations/
│   ├── 001_initial_schema.sql
│   └── 002_summary_tables.sql
├── tests/
│   ├── test_processor.py
│   ├── test_database.py
│   └── test_utils.py
├── requirements.txt
├── setup.py
├── README.md
└── .env.example
```

## Validation and Error Handling

### Validation Rules

1. **Batch IDs**: Must be sequential, log warning on gaps
2. **Transition IDs**: Must start at 1 and be sequential per batch
3. **Addresses**: Must be valid Ethereum addresses, stored as checksummed
4. **Costs**: Must be non-negative, rounded down to 7 decimal places

### Error Recovery

1. **RPC Errors**: Retry with exponential backoff (1s, 2s, 4s, 8s, 16s)
2. **Database Errors**: Log and exit, let process manager restart
3. **Contract Call Errors**: Retry 3 times, then skip and log
4. **Graceful Shutdown**: Catch SIGINT/SIGTERM, complete current block

## Performance Considerations

### Database Optimizations

1. Use batch inserts where possible
2. Indexes on frequently queried columns
3. Connection pooling with sensible defaults:
   ```python
   pool_size=5
   max_overflow=10
   pool_timeout=30
   pool_recycle=3600
   ```

### Processing Optimizations

1. Cache contract ABI
2. Reuse Web3 filter instances
3. Process events in batches within transactions
4. Use prepared statements for repeated queries

## Logging Format

```
2024-01-15 10:23:45,123 - INFO - Starting Taiko L1 Cost Calculator
2024-01-15 10:23:45,234 - INFO - Connected to database at localhost:3306
2024-01-15 10:23:45,345 - INFO - Starting from block 19230000
2024-01-15 10:23:46,456 - INFO - Processing block 19230000
2024-01-15 10:23:46,567 - DEBUG - Found 2 BatchProposed events in tx 0xabc...
2024-01-15 10:23:46,678 - DEBUG - Proposing cost per batch: 0.0123456 ETH
2024-01-15 10:23:46,789 - INFO - Stored batch 1234 (proposer: 0x123...ABC)
2024-01-15 10:23:47,890 - INFO - Processing block 19230001
2024-01-15 10:23:48,012 - DEBUG - Found BatchesProved event with 3 batches
2024-01-15 10:23:48,123 - INFO - Stored transition 1 for batch 1234 (cost: 0.0234567 ETH)
2024-01-15 10:23:49,234 - INFO - Found BatchesVerified event for batch 1234
2024-01-15 10:23:49,345 - INFO - Batch 1234 verified with transition 1 (final cost: 0.0358023 ETH)
2024-01-15 10:23:59,456 - INFO - Processed 100 blocks, current: 19230100
```

## Testing Strategy

### Unit Tests

- Cost calculation precision
- Event parsing logic
- Database operations
- Reorg handling

### Integration Tests

- End-to-end event processing
- Summary calculation accuracy
- CLI interaction flow

### Test Data

- Mock events with edge cases
- Multiple batches in single transaction
- Multiple transitions per batch
- Reorg scenarios

## Deployment Considerations

### System Requirements

- Python 3.8+
- MySQL 8.0+
- Stable Ethereum RPC endpoint
- Minimum 2GB RAM
- 50GB+ disk space for database growth

### Monitoring

- Log rotation configuration
- Database backup strategy
- Process supervision (systemd/supervisor)
- Disk space monitoring

This specification provides a complete blueprint for implementing the Taiko L1 cost calculator with all necessary details for development.
