# Etna TLA+/TLC models

This directory is the home for incremental Etna models. The first model checks
**ordering between L1 landing, recovery authorization and recovery execution**.
It does not verify CometBFT, the implementation of a contract, or deployment
readiness. The normative source is
[`SPEC.md`](../../packages/protocol/docs/etna/SPEC.md), pinned for this model at
[`d18357214fab30ea512ae9858a11699806d72ba1`](https://github.com/taikoxyz/taiko-mono/blob/d18357214fab30ea512ae9858a11699806d72ba1/packages/protocol/docs/etna/SPEC.md).
Later specification changes require a correspondence review before reusing the
results.

## Run

Use Java 17+ and `tla2tools.jar` from the official
[TLA+ tools release](https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4).
The recorded runs use release 1.7.4 (its banner says TLC2 Version 2.19).
The runner uses only Python's standard library and does not download tools.

```sh
python3 formal/etna/check.py \
  --java java \
  --tlc-jar "$TLA2TOOLS_JAR" \
  --output-dir "$TLC_OUTPUT_DIR"
```

Set the two paths to an existing jar and an output directory outside Git. Each
case has a bounded timeout and heap. A passing suite includes intentionally
failing TLC runs: negative controls and reachability checks must violate their
**named** invariant, not fail to parse or crash. See [REPORT.md](REPORT.md) for
actual commands, tool hashes, bounds and results. On a sandboxed host TLC's
local management socket may need permission even though the model makes no
external network requests.

## What the model contains

[`EtnaSettlement.tla`](EtnaSettlement.tla) has a single canonical L1 contract
state, one authorized recovery request and one delayed valid proof. TLC chooses
when each is prepared and which transaction executes next. Authorizations and
proofs remain available after execution; an attempt cannot regain validity by
silently deleting its history.

| State                         | Meaning                                                                        |
| ----------------------------- | ------------------------------------------------------------------------------ |
| `c`                           | Latest settled checkpoint height                                               |
| `generation`, `recoveryNonce` | Current recovery domain and authorization nonce                                |
| `startHeight`                 | Fixed checkpoint from which this generation started                            |
| `now`                         | Abstract, bounded L1 timestamp                                                 |
| `authorization`               | Captured generation, checkpoint, nonce and inclusive deadline                  |
| `pendingProof`                | Otherwise-valid proof captured with generation, origin and terminal height     |
| `landings`                    | Retained landing records, including each record's generation and actual parent |
| `lastLanding`, `audit`        | Observation-only state for checking outcomes and reachability                  |

`Authorize` and `PrepareProof` stand for offchain work; they do not freeze
onchain state. `LandFresh` permits a competing valid landing. `Land(pendingProof)`
then exercises delayed submission, including valid overlap `p < c < h`.
`Recover`, `InvalidateNonce` and `Tick` represent recovery execution, explicit
authorization invalidation and elapsed time.

## Source-to-model correspondence

| Model behavior                                                                                                                                           | Normative source                                                                                                    |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Land reads actual `c`, requires `startHeight <= p <= c < h`, retains the record at `p`, accepts that record's old generation only when `p = startHeight` | LAND-6.1-2/3/9/10, normative reference steps 1 and 2                                                                |
| Proof must verify under the current generation                                                                                                           | Normative `land` step 6 (`statement(recoveryGeneration, ...)`, generation-bound `cutHash`); PROOF-6.2-9/10/14/17/45 |
| A valid delayed proof can settle only the new suffix and records actual `c` as parent                                                                    | LAND-6.1-3/4/9; normative reference step 7                                                                          |
| Authorization does not freeze land                                                                                                                       | RECOV-8.3-7; RECOV-8.1-4                                                                                            |
| Recovery matches captured generation, `c`, nonce and `now <= deadline`                                                                                   | RECOV-8.3-3/4                                                                                                       |
| Successful recovery increments generation/nonce and preserves settled checkpoint                                                                         | RECOV-8-47/48/56/58; RECOV-8.3-8                                                                                    |
| Recovery takes current `c` as the new fixed origin                                                                                                       | RECOV-8.4-2/3/7                                                                                                     |
| Explicit invalidation advances the nonce without changing the checkpoint                                                                                 | RECOV-8.3-9/11                                                                                                      |
| Transactions are atomic and failed calls leave no partial state                                                                                          | LAND-6.1-9/11; RECOV-8.3-16/19, assumed atomic action boundary                                                      |

`pendingProof.generation` is an abstraction of the immutable public input a
proof authenticates. The Solidity interface has no caller-supplied generation
field whose value the contract merely trusts. Turning off
`CheckProofGeneration` deliberately models loss of that verifier/input binding.

## Checks and negative controls

Every normal configuration checks types, no successful stale-generation,
stale-checkpoint, stale-nonce or expired recovery, no old-generation landing,
no retained landing record above `c`, preservation of `c` through ordinary recovery,
and actual checkpoint parent recording. `NoFutureLandingRecords` checks only
height ordering; block-hash integrity and full prefix preservation are outside
this model. Audit flags accumulate observations
from successful actions, never enable actions, and never consult the optional
guard constants.

| Configuration                           | Expected result                                                                                                 |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `baseline.cfg`, `baseline-extended.cfg` | Complete exploration with all invariants satisfied                                                              |
| `missing-checkpoint.cfg`                | `NoStaleCheckpointRecovery` violation                                                                           |
| `missing-nonce.cfg`                     | `NoStaleNonceRecovery` violation                                                                                |
| `missing-deadline.cfg`                  | `NoExpiredRecovery` violation                                                                                   |
| `missing-proof-generation.cfg`          | `NoOldGenerationLanding` violation                                                                              |
| `reach-recovery.cfg`                    | `RecoveryNotReached` violation: successful recovery exists                                                      |
| `reach-overlap.cfg`                     | `OverlapNotReached` violation: successful overlapping landing exists                                            |
| `reach-invalidation.cfg`                | `InvalidationNotReached` violation: otherwise-current authorization is nonce-stale                              |
| `reach-expiry.cfg`                      | `ExpiryNotReached` violation: an authorization can expire                                                       |
| `reach-deadline-equality.cfg`           | `DeadlineEqualityNotReached` violation: recovery succeeds at a positive timestamp exactly equal to its deadline |
| `reach-old-proof.cfg`                   | `OldProofAfterRecoveryNotReached` violation: an old proof remains queued at the reused recovery origin          |

A reachability run intentionally asserts that an interesting state is absent;
its counterexample certifies **existence**, not eventual progress. Finite bounds
also impose terminal states, so deadlock checking is disabled explicitly. The
model has no fairness assumptions or liveness claim.

The small bound is `MaxHeight=2`, `MaxGeneration=1`, `MaxNonce=2`, `MaxTime=1`;
the extended bound uses height 3, generation 2 and nonce 3 with the same time
bound. Heights count normalized grid points, with `S=0`, `K=1`; these are not
production deployment parameters. No state constraint silently discards states;
finite bounds appear in the state domains and action enabling conditions.

## Assumptions and exclusions

- A transaction is one atomic action. Reentrancy, partial writes, contract code
  and failure/revert implementations are not verified.
- A single canonical L1 state is modeled. RPC lag, forks, per-node views,
  finality failure, crashes and signer persistence are not modeled yet.
- DAO authority, initialization, start setup and recovery list validity hold.
  Invalid authorizations are created by delay or invalidation, not by forgery.
- Fresh proofs are available as abstract valid inputs. All proof origins are
  captured from checkpoints; retained origin records are checked at execution.
- Proofs share one abstract block history, authenticate their complete range,
  and have cuts matching the current checkpoint. EL/Comet/validator-state hashes,
  FI cursors, blobs, cryptography, proof completeness and proving latency are
  outside this model. In particular, this does not establish fork-safe overlap
  merely by comparing heights.
- Ordinary recovery preserves settled history. Verifier-failure rollback is
  excluded; adding it requires revising checkpoint properties and modeling nonce
  preservation/invalidation and derived authorizations explicitly.
- These runs explore particular finite configurations using TLC fingerprints;
  they are not unbounded machine-checked theorems or proof of client conformance.

## Extending this directory

Keep the small configurations as regression checks. Add coherent modules for
L1 observations, committee schedules, signer state or consensus here, and use
`EXTENDS`/`INSTANCE` plus an explicit top-level `Init`/`Next` when composition is
useful. Define ownership of shared variables and `UNCHANGED` obligations, then
review source mapping, assumptions and properties again. Combining modules does
not automatically preserve their individual guarantees. New observations may
also require revisiting which information the present abstraction discards.
