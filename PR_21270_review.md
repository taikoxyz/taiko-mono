# PR #21270 Comment Responses

## 1) [P1] Compare fork timestamp against chain time, not local wall clock

Status: Fixed.
Details: `packages/bridge-ui/src/libs/protocol/protocolVersion.ts` now compares `shastaForkTimestamp` with the destination chain's latest block timestamp (via `getPublicClient().getBlock()`), not `Date.now()`.

## 2) [P1] Do not cache PACAYA fallback after read errors

Status: Fixed.
Details: `packages/bridge-ui/src/libs/protocol/protocolVersion.ts` now skips caching when the fork timestamp or chain time read fails, so transient RPC errors do not pin PACAYA for 5 minutes.

## 3) [P1] Multi-hop proof queries wrong chain for block and proof

Status: Fixed.
Details: `packages/bridge-ui/src/libs/proof/BridgeProver.ts` now queries blocks and `eth_getProof` on the source chain for each hop. Added a unit test to verify source-chain clients are used.

## 4) [High] Multi-hop proof uses next hop's signal service address incorrectly

Status: Fixed.
Details: `packages/bridge-ui/src/libs/proof/BridgeProver.ts` now resolves the signal service address from the source chain for the current hop (with a safe fallback to hop config). Added a unit test to assert the correct address is passed to `eth_getProof`.

## 5) [Low] Pre-flight verification uses wrong encoding for function call

Status: Fixed.
Details: `packages/bridge-ui/src/libs/proof/BridgeProver.ts` now uses `encodeFunctionData` with `signalServiceAbi` for `verifySignalReceived`.

## 6) [Low] Protocol version cache causes incorrect routing during fork transition

Status: Fixed.
Details: `packages/bridge-ui/src/libs/protocol/protocolVersion.ts` now bounds cache expiry to the fork timestamp (based on chain time), preventing stale PACAYA results from persisting past the fork.

## 7) [Medium] Duplicated sync block helper functions across files

Status: Not addressed (defer).
Details: The duplication is a maintainability concern but not a functional bug. Consolidating would change error-handling behavior between `BridgeProver` and `isTransactionProcessable`, so I recommend a follow-up refactor to avoid scope and risk in this PR.

## 8) [Low] Duplicated constant and ABI definitions

Status: Not addressed (defer).
Details: Similar to #7, this is stylistic. Moving the constant and ABI into shared modules or `$abi` is better handled in a focused refactor PR.
