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
idempotent. On `sync`, startup still reads the historical `events` watermark;
`resync` and an empty watermark start from genesis. The service no longer writes
events, so that legacy marker does not advance and later restarts can rescan the
same historical range. A durable NFT checkpoint is outside this change. The existing
recency-based pre-claim bootstrap check remains; it does not detect every
historical or resync overcount. Historical balances may require an operator
reconciliation decision.

All historical migrations remain unchanged for installed database and Goose
version compatibility; no tables or existing data are dropped. Historical
incorrect balances/duplicates require separate reconciliation. Unused runtime
code and bindings are removed rather than kept as disabled features.
