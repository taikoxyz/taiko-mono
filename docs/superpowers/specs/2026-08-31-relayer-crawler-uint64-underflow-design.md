# Relayer crawler uint64 underflow fix

## Context

The relayer crawler calculates the beginning of its historical scan window by
subtracting `numLatestBlocksStartWhenCrawling` from the current source-chain
head. The default lookback is 50,400 blocks. On a fresh or reset chain whose
head is below that value, unsigned subtraction wraps to a value near
`math.MaxUint64`.

This was observed on internal-devnet with a source-chain head near 33,000. The
`relayer-crawler-l1-to-l2` Pod remained Running and Ready, but repeatedly logged
a `latestIndexedBlockNumber` near `2^64` and did not crawl the available chain
history.

## Goal

Make `CrawlPastBlocks` treat a lookback larger than the current chain height as
a valid request to crawl all available history from the configured Shasta
genesis block, or block zero when no Shasta inbox is configured.

## Non-goals

- Change the configured 50,400-block lookback or end exclusion window.
- Change `targetBlockNumber` behavior.
- Change other watch modes, RPC timeout behavior, event processing, metrics, or
  persistence.
- Modify Kubernetes configuration or roll out a relayer image.
- Address existing RabbitMQ backlog independently of fixing the crawler range.

## Current behavior and root cause

For non-targeted crawl iterations, the indexer first resets
`latestIndexedBlockNumber` to the Shasta genesis block or zero. It then raises
that starting point when the requested lookback covers only a suffix of the
available chain:

```go
if i.latestIndexedBlockNumber < endBlockID-i.numLatestBlocksStartWhenCrawling {
    i.latestIndexedBlockNumber = endBlockID - i.numLatestBlocksStartWhenCrawling
}
```

Both operands are `uint64`. When `endBlockID` is smaller than the lookback, the
subtraction wraps before the comparison. The wrapped value wins the comparison,
so the subsequent batch loop starts beyond the real head and performs no useful
work.

## Chosen behavior

Saturate the lookback subtraction at zero:

```go
crawlStartBlockID := endBlockID - min(
    endBlockID,
    i.numLatestBlocksStartWhenCrawling,
)
```

The existing comparison then applies the greater of:

- the Shasta genesis block or zero; and
- the safely calculated suffix-window start.

Examples with an end exclusion window of 300 blocks:

|   Head | Start lookback | Effective crawl start | Effective crawl end |
| -----: | -------------: | --------------------: | ------------------: |
| 33,335 |         50,400 |   Shasta genesis or 0 |              33,035 |
| 50,400 |         50,400 |   Shasta genesis or 0 |              50,100 |
| 60,000 |         50,400 |                 9,600 |              59,700 |

Low chain height is valid and does not produce a new error or warning. Existing
validation that the start lookback is not smaller than the end exclusion window
remains unchanged.

## Components and data flow

Only `packages/relayer/indexer/indexer.go` changes in production code:

1. `filter` obtains the latest source-chain header using the existing bounded
   HTTP RPC request.
2. In `CrawlPastBlocks` mode without `targetBlockNumber`, it restores the
   genesis-based initial cursor.
3. It computes a saturated historical-window start and raises the cursor only
   when that start is above genesis.
4. It applies the existing end exclusion window.
5. The unchanged batch loop filters events through the effective range.

No new component, exported API, configuration field, database migration, or
metric is introduced.

## Error handling

- RPC and initial-cursor errors continue to propagate unchanged.
- Invalid crawler window configuration continues to return the existing error.
- A head below the lookback is handled as a normal boundary condition.
- `targetBlockNumber == 0` continues to return the existing validation error.

## Testing

Add a regression test in `packages/relayer/indexer/indexer_test.go` that exercises
the real `Indexer.filter` path with:

- `Resync` and `CrawlPastBlocks`;
- the existing mock source-chain head of 10;
- a start lookback of 50,400 and an end exclusion window of 3; and
- a test-only unhandled event name so the production batch loop advances its
  cursor without entering generated event iterator code.

The test asserts that:

- `filter` returns no error;
- `latestIndexedBlockNumber` never exceeds the source-chain head; and
- the completed scan cursor is 7, equal to the head minus the end exclusion.

The test must fail against unmodified `origin/main` by observing the wrapped
cursor, then pass after the production change.

Verification commands:

```bash
go test ./packages/relayer/indexer -run TestFilterCrawlPastBlocks
cd packages/relayer
go test $(go list ./... | grep -v ./contracts | grep -v ./mock | grep -v ./cmd) \
  -timeout=20m
golangci-lint run --config=.golangci.yml --timeout=4m
```

Run `gofmt` on every modified Go file before these checks. If the CI-pinned
lint runner is unavailable locally, record that fact in the Draft PR rather
than representing lint as locally verified.

## Delivery

Implement in an isolated worktree based on fresh `origin/main`, on branch
`codex/fix-relayer-crawler-underflow`. Use three commits during development:

1. this approved design document;
2. the regression test and production fix; and
3. removal of `docs/superpowers` before Draft PR creation.

Before opening the Draft PR, remove the branch-created `docs/superpowers`
directory as explicitly requested. The final PR diff must contain only the
relayer code and test changes. Target `main` with title:

`fix(relayer): prevent crawler block range underflow`

The PR description will include the internal-devnet symptom, root cause, chosen
low-height semantics, red/green regression evidence, and full relayer test
results. Creating the PR does not authorize a Kubernetes rollout.

## Risks and mitigations

- **Scanning more history on a fresh chain:** This is intentional. The crawler
  scans all history available within the requested lookback instead of skipping
  work due to wraparound.
- **Changing mature-chain behavior:** Heads at or above the lookback retain the
  exact existing subtraction result because `min(head, lookback)` equals the
  lookback in that range.
- **A test coupled to event filtering:** The regression uses the production
  `filter` control flow while isolating event iteration, keeping the test focused
  on cursor and block-range behavior.
