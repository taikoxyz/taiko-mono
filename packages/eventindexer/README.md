# NFT indexer

Indexes ERC721 and ERC1155 TransferSingle/TransferBatch logs and serves the NFT
holdings used by bridge-ui. The only business API is `GET /nftsByAddress`;
`/healthz` and `/` remain for probes, with metrics on the configured metrics port.
The query API needs a database connection and does not require RPC.

## Running

Copy `.default.env` to `.env` and configure the database and source-chain RPC.
Apply the existing SQL migrations before starting either process. From this
package directory, run `go run ./cmd api` for queries or `go run ./cmd indexer`
for NFT indexing. `EVENTINDEXER_ENV_FILE` selects a different env file.

The indexer requires `INDEX_NFTS=true`, a positive `BLOCK_BATCH_SIZE`, and
`SYNC_MODE=sync` or `resync`. Disabled NFT indexing fails before opening DB/RPC;
retire old L1 event-only deployments instead of upgrading them to this binary.
The `LAYER`, Inbox/Bridge, ERC20, subscription/backoff and transaction-manager
options are retired. Existing enabled L2 NFT deployment settings remain valid.

## Query API

`GET /nftsByAddress?address=0x...&chainID=167000&page=0&size=100` retains the
existing paginated JSON response and NFT fields. CORS/request logging remain
available. Set `--http.corsOrigins` when the default `*` is inappropriate.

Event/statistics, proposal/proof, ERC20, Galxe and chart endpoints are removed
and return 404. Swagger documents only the NFT query and probes; regenerate it
with `GOTOOLCHAIN=go1.26.0 sh scripts/swagger.sh`.

## Writer and replay behavior

NFT logs are applied sequentially by block, transaction index and log index.
A dedicated MySQL session holds a chain/database-scoped `GET_LOCK` and executes
the NFT balance transactions. A second guarded writer fails startup; session
loss prevents pooled fallback writes and returns a fatal CLI error after cleanup
so the supervisor can restart. Configure at least two open DB connections or an
unlimited pool, and stop older unguarded writers before upgrading.

Per-transfer claims remain atomic with balance updates and make restart replay
idempotent. Each successfully completed batch, including an empty batch, updates
one `NFTIndexerCheckpoint` marker per chain in the existing `events` table using
the same locked MySQL session. Startup resumes at the completed block plus one;
block zero is a valid checkpoint. If a batch or checkpoint write fails, the memory
cursor stays unchanged and retry uses transfer claims to avoid duplicate balances.
When no NFT marker exists, `sync` reads only historical business events and rewinds
one block once for compatibility; the first completed batch establishes the marker.

`resync` requires no retained NFT balances, NFT transfer claims or NFT checkpoint
for that chain. A rebuild must reconcile and clear these three together. `sync`
also rejects NFT claims without any balance rows: already claimed transfers are
skipped, so they cannot reconstruct balances that were deleted independently. It
refuses genesis replay when balances exist without either an NFT checkpoint or a
legacy events watermark, regardless of claims or `ALLOW_UNCLAIMED_BALANCE_REPLAY`.
The existing recency check remains for the narrow legacy bootstrap overlap: the
escape hatch accepts its possible single overcount, not an unsafe clean rebuild.
Malformed recognized ERC1155 logs warn and skip; valid later logs continue, while
repository and RPC errors fail the batch.

### Rebuilding one chain

Stop every indexer for the selected chain and back up/reconcile its NFT state.
Do not clear only balances or truncate shared tables. The following MySQL example
clears the three NFT state sets for Mainnet while preserving other chains and
historical business events; select the intended chain before executing it:

```sql
SET @nft_chain_id = 167000;
START TRANSACTION;
DELETE FROM nft_balances WHERE chain_id = @nft_chain_id;
DELETE FROM processed_transfer_logs
WHERE chain_id = @nft_chain_id AND kind = 'nft';
DELETE FROM events
WHERE chain_id = @nft_chain_id AND event = 'NFTIndexerCheckpoint';
COMMIT;
```

Start the empty state with `INDEX_NFTS=true` and `SYNC_MODE=resync`. As soon as
indexing begins, change the deployment environment to `SYNC_MODE=sync` before
its next restart. Continue from the saved checkpoint after an interruption;
do not clear state again merely because a retained `resync` environment is refused.

### Deliberately skipping a blocked range

Repair RPC/database failures before choosing to omit history. If an operator
decides to skip through block N, stop every writer and back up the selected
chain's state first. Confirm N exists on the selected chain and does not exceed
its current RPC head. With an existing checkpoint, this example advances Mainnet
through block 20000000; check that exactly one row changed:

```sql
UPDATE events
SET emitted_block_id = 20000000, transacted_at = NOW()
WHERE chain_id = 167000 AND event = 'NFTIndexerCheckpoint'
  AND emitted_block_id < 20000000;
SELECT ROW_COUNT();
```

If no checkpoint exists, do not treat an update affecting zero rows as success.
After reconciling the intended starting position, a stopped writer permits this
guarded initial marker insertion; expect one inserted row, and verify the marker:

```sql
INSERT INTO events
  (name, event, chain_id, data, emitted_block_id, transacted_at)
SELECT 'NFTIndexerCheckpoint', 'NFTIndexerCheckpoint', 167000, '{}', 20000000, NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM events
  WHERE chain_id = 167000 AND event = 'NFTIndexerCheckpoint'
);
SELECT ROW_COUNT();
SELECT emitted_block_id FROM events
WHERE chain_id = 167000 AND event = 'NFTIndexerCheckpoint';
```

Restart in
`SYNC_MODE=sync`: filtering begins at N+1, and the omitted range will not update
NFT balances. Those omissions require separate reconciliation. Moving a marker
backward does not rebuild balances while transfer claims remain.

The `eventindexer_nft_indexer_lag_blocks{chain_id="..."}` metric reports the last
observed RPC head minus the successfully checkpointed position, clamped at zero.
It stays positive when a batch fails; it is not a proof of current RPC health.

All historical migrations remain unchanged for installed database and Goose
version compatibility; no tables or existing data are dropped. Historical
incorrect balances/duplicates require separate reconciliation. Unused runtime
code and bindings are removed rather than kept as disabled features.
