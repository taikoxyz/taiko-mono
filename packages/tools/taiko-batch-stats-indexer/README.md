# Taiko Batch Stats Indexer

This project indexes batch-level statistics for Taiko's Ethereum-based ZK rollup by scanning events from both L1 and L2, and stores the results into a Supabase database.

## Features

This indexer extracts data from `BatchProposed`, `BatchesProved`, `BondDebited`, and `BondCredited` events across both L1 and L2, and writes structured statistics to Supabase.

Table `batches_proposed`
Populated from the `BatchProposed` and `BatchesProved` events and correlated L2 data, this table contains:

- `batch_id`: unique batch identifier
- `timestamp`: proposal timestamp
- `last_block_id`, `anchor_block_id`: block range metadata
- `block_count`, `l2_tx_count`: number of L2 blocks and transactions in the batch
- `block_number`, `tx_hash`: L1 inclusion details
- `proposer`: address who proposed the batch
- `assigned_proposer`: intended prover specified at proposal time
- `debited_user`: actual user debited
- `bond_debited_amount`: actual debited bond amount
- `tx_l1_fee_eth`: L1 gas fee paid by proposer
- `l2_total_tips_eth`, `l2_total_base_fees_eth`: total L2 tips and base fee income
- Base fee configuration:
  - `l2_base_fee_gas_target`
  - `l2_base_fee_base_fee_max_change_denominator`
  - `l2_base_fee_min_base_fee`
  - `l2_base_fee_target_resource_limit`
  - `l2_base_fee_resource_limit_multiplier`

Table `batches_proved`
Populated from the `BatchesProved` and `BondCredited` events on L1, this table contains:

- `batch_id`: proved batch ID
- `tx_hash`: L1 transaction that proved the batch
- `tx_from`: address that submitted the proof
- `block_number`: block number of the proving transaction
- `tx_l1_fee_eth`: L1 gas fee paid by the prover
- `prover`: actual address that received the bond credit
- `bond_credited_amount`: bond reward (split across batches if applicable)

## Structure

- `batches-proposed-index.js` — handles `BatchProposed` and `BondDebited` events, and computes L2 tips/base fee info.
- `batches-proved-index.js` — handles `BatchesProved` and `BondCredited` events, and verifies the actual prover.
- `networks.js` — defines supported networks and block ranges.
- `utils.js` — includes helpers like fetching L1 tx fees.

## Output

All data is stored in the following Supabase tables:

- `batches_proposed`
- `batches_proved`

Each batch's stats are periodically upserted with `batch_id` + `tx_hash` as unique keys.

## Setup

### Prerequisites

- Node.js v18+
- Supabase project and key
- RPC access to both L1 and L2 Taiko endpoints

### Install dependencies

- Node.js v22+
- Install dependencies:

```bash
nvm use 22
npm install ethers
```

### Set environment variables

```bash
export SUPABASE_KEY=<your-supabase-service-role-key>
export SUPABASE_URL=<your-supabase-url>
```

### Run indexers

```bash
node batches-proposed-index.js
node batches-proved-index.js
```

### Example

THe example log of `batches-proposed-index.js`

```
BondDebited - user: 0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9, amount: 125000000000000000000
anchorBlockId: 22710658, batchId: 1207978, lastBlockId: 1207978, number of blocks: 1
Fetching L2 block 1207978, number of transations 457 for batch 1207978...
Tx Block 1207978 cumulative tips so far: 0.0003921037806939977 ETH, base fees: 0.0002230709500000006 ETH, l2TxCount: 457
```

THe example log of `batches-proved-index.js`

```
Inserting batchId 1272838, prover 0xa5cb34B75bD72f15290ef37A01F06183E8036875, tx 0x4dca69bc826a814b5ecc9eb3c0144554bef77266e67ad8330937740f70b518c8
```
