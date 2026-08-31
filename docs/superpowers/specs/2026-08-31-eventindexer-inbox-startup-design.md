# Eventindexer Inbox Startup Regression Fix

## Context

Taiko monorepo issue #22076 reports that eventindexer images containing commit
`a78580e5c` cannot start reliably as indexers. That commit was intended to
remove legacy pre-Shasta L1 fork indexing. Its pull request explicitly said
that `l1TaikoAddress` would be removed, while Shasta inbox event indexing would
remain.

The merged code did the opposite at the configuration boundary:

- it removed `shastaInboxAddress` / `SHASTA_INBOX_ADDRESS`;
- it retained `l1TaikoAddress` / `L1_TAIKO_ADDRESS` and made it required;
- it used that address as the Shasta Inbox binding; and
- it queried `activationTimestamp()` before considering the indexer's layer or
  an existing database checkpoint.

This breaks every L2 indexer because its `RPC_URL` points to L2, where the L1
Inbox does not exist. It also breaks L1 deployments whose
`L1_TAIKO_ADDRESS` still identifies a pre-Shasta contract. Existing deployment
charts already provide the correct Shasta Inbox through
`SHASTA_INBOX_ADDRESS`.

## Goals

- Restore the configuration contract already used by current deployments.
- Allow L2 indexers to start without any L1 contract configuration.
- Avoid an unnecessary Inbox RPC call when `sync` can resume from a database
  checkpoint.
- Preserve L1 Shasta `Proposed` and `Proved` event indexing.
- Preserve the existing one-block rewind (`latest - 1`) during checkpointed
  sync.
- Add regression tests for the L1/L2 and sync/resync startup matrix.
- Keep the change limited to eventindexer configuration, startup selection,
  examples, and tests.

## Non-goals

- Adding a separate L1 RPC connection to L2 indexers.
- Changing the timestamp-to-block search algorithm.
- Changing event filtering, persistence, replay, or reorg behavior.
- Changing Kubernetes charts in `k8s-configs`.
- Restoring any legacy Ontake or Pacaya contract bindings or filter paths.

## Considered Approaches

### 1. Restore the dedicated Shasta Inbox configuration

Restore optional `shastaInboxAddress` / `SHASTA_INBOX_ADDRESS`, remove the
erroneously retained `l1TaikoAddress`, and make startup selection layer-aware.
This is the selected approach because it matches the intent of #21697 and the
configuration already rendered by current deployments.

### 2. Keep `L1_TAIKO_ADDRESS` and make it conditionally required

This would make the smallest flag-level diff, but the variable would continue
to have the wrong meaning and every L1 deployment would need to migrate from
its correctly configured `SHASTA_INBOX_ADDRESS`.

### 3. Give L2 indexers a separate L1 RPC client

This would allow an L2 process to call the L1 Inbox, but the result is not
needed for L2 indexing. It would add another endpoint, client lifecycle, and
failure mode without improving the required L2 behavior.

## Selected Design

### Configuration

The indexer flag set and `Config` restore
`ShastaInboxAddress common.Address`, populated by the optional
`shastaInboxAddress` flag and `SHASTA_INBOX_ADDRESS` environment variable.
`L1TaikoAddress` and its flag are removed from eventindexer.

Configuration validation runs before `InitFromConfig` opens the database or
dials an RPC endpoint:

- `syncMode` must be `sync` or `resync`, otherwise validation returns
  `eventindexer.ErrInvalidMode`;
- an L1 indexer must have a non-zero Shasta Inbox address, otherwise validation
  returns a new, explicit validation error; and
- an L2 indexer does not require or use a Shasta Inbox address.

`InitFromConfig` creates the generated Inbox binding only for L1. The binding
uses the existing source-chain `RPC_URL`, which is an L1 endpoint for an L1
indexer. No additional client is introduced.

The L1 Inbox binding remains available after startup because the normal filter
loop uses it to retrieve Shasta `Proposed` and `Proved` events. Skipping an
activation timestamp lookup on checkpointed sync does not mean skipping Inbox
event filtering.

### Initial Block Selection

`setInitialIndexingBlockByMode` validates its mode defensively before invoking
the repository or Inbox resolver. It then follows this decision table:

| Layer | Mode     | Database checkpoint | Initial block      | Inbox activation call |
| ----- | -------- | ------------------- | ------------------ | --------------------- |
| L1    | `sync`   | non-zero `latest`   | `latest - 1`       | No                    |
| L1    | `sync`   | zero                | first Shasta block | Yes                   |
| L1    | `resync` | ignored             | first Shasta block | Yes                   |
| L2    | `sync`   | non-zero `latest`   | `latest - 1`       | No                    |
| L2    | `sync`   | zero                | `0`                | No                    |
| L2    | `resync` | ignored             | `0`                | No                    |

For `sync`, the repository checkpoint is queried before calculating a fallback
start block. A non-zero checkpoint returns immediately after applying the
existing one-block rewind. This removes the discarded Inbox call that caused
checkpointed L1 startup to depend unnecessarily on `activationTimestamp()`.

When there is no checkpoint, L2 starts from block zero. Only the L1 fallback
path calls `getFirstShastaBlockHeight`, which retains the existing
`activationTimestamp()` and timestamp-to-block behavior.

The production method will delegate the decision to a small unexported helper
whose first-Shasta-block resolver is an explicit function argument. This keeps
the production behavior simple while allowing tests to prove whether the
Inbox path was or was not called without introducing another runtime
interface, RPC client, or mutable test hook.

### Error Handling

- Invalid modes return `ErrInvalidMode` before database or contract work.
- Missing L1 Shasta configuration returns a stable, explicit validation error
  before external resources are opened.
- Repository errors retain `FindLatestBlockID` context.
- Inbox activation and timestamp-to-block errors retain their existing wrapped
  context.
- L2 startup never turns missing L1 configuration into an error.

No fallback silently converts an L1 configuration or RPC failure into block
zero, because that could omit Shasta events while making the process appear
healthy.

### Example Configuration and Documentation

The tracked eventindexer environment examples are corrected as follows:

- `.default.env` and `.l1.env` remove `L1_TAIKO_ADDRESS` and retain
  `SHASTA_INBOX_ADDRESS` as the L1 Inbox setting;
- `.l2.env` remains free of L1 Inbox configuration; and
- the README documents that `SHASTA_INBOX_ADDRESS` is required for the `l1`
  indexer and unused for the `l2` indexer.

This restores compatibility with existing charts, so no chart migration is
required for this fix.

## Test Strategy

Table-driven unit tests cover:

- parsing `SHASTA_INBOX_ADDRESS` into the indexer config;
- L2 configuration succeeding without a Shasta Inbox address;
- L1 configuration failing before DB/RPC setup when the address is absent;
- invalid sync mode failing before DB/RPC setup;
- checkpointed `sync` returning `latest - 1` without invoking the Inbox
  resolver;
- L2 empty-database `sync` starting at block zero;
- L2 `resync` starting at block zero;
- L1 empty-database `sync` invoking the first-Shasta-block resolver;
- L1 `resync` invoking the first-Shasta-block resolver;
- repository and first-Shasta-block errors retaining useful context; and
- direct defensive use of an invalid mode avoiding repository and Inbox calls.

Verification commands will include:

```bash
go test ./packages/eventindexer/indexer
go test ./packages/eventindexer/... -run '^$'
git diff --check
```

The eventindexer package lint will also run when the repository's configured
lint tool is available locally. Full integration tests that require Docker are
not necessary to validate this startup-routing regression, but any unrelated
local Docker limitation will be reported separately from the targeted test
results.

## Planned Change Scope

Expected production and test changes are limited to:

- `packages/eventindexer/cmd/flags/indexer.go`;
- `packages/eventindexer/errors.go` for the explicit missing-Inbox validation
  error;
- `packages/eventindexer/indexer/config.go` and its tests;
- `packages/eventindexer/indexer/indexer.go`;
- `packages/eventindexer/indexer/set_initial_processing_block_height.go` and a
  focused test file;
- `packages/eventindexer/.default.env` and `.l1.env`, while `.l2.env` is
  verified to remain free of Inbox configuration; and
- `packages/eventindexer/README.md`.

The pull request will explain the regression, include the startup decision
matrix, state that current charts require no migration, and close issue #22076.

## Acceptance Criteria

- An L2 indexer can initialize and select a starting block without any Inbox
  address or L1 RPC call.
- A checkpointed `sync` does not call `activationTimestamp()`.
- A fresh or resyncing L1 indexer starts from the block corresponding to the
  configured Shasta Inbox activation timestamp.
- An L1 indexer cannot silently start without the Inbox binding required for
  Shasta event filtering.
- The tracked examples describe the same environment-variable contract as the
  binary.
- Targeted tests, compile checks, and diff checks pass before the PR is opened.
