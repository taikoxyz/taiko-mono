# Etna behavioral conformance vectors

These files say what the Etna Lean model (`formal/etna`) decides on concrete inputs. Unlike
`../etna_vectors/vectors.json`, which pins encodings byte for byte, they check rule-level
decisions that do not depend on hash values. They live outside `../etna_vectors/` because the
client's lander pins that directory's exact file list and hashes
(`packages/taiko-client-rs/crates/lander/src/test_utils/artifacts.rs`). There are two kinds:

- **Inbox families** (schema `etna-conformance-2`): concrete call sequences, whether each call is
  accepted or reverts, what it returns and the state a contract exposes afterwards. The Etna
  contracts must do the same.
- **Client-rule families** (schema `etna-client-conformance-1`): the whole input of one pure node
  rule and the model's decision on it. The Rust client (`packages/taiko-client-rs`) must decide the
  same; see [Client-rule families](#client-rule-families-etna-client-conformance-1).

The current authority is `SPEC.md` and `ACCEPTANCE.md` at commit
`39ebefbf33a2702b750e0fb0db7d2a40ff8e8480`, independently byte-pinned in
`formal/etna/spec-coverage.json`. Schema 2 vectors require downstream harness adoption;
regenerating these model outputs does not establish current contract or client conformance.

The files record only what the model decides. Neither implementation reads this directory: each
keeps its own copy next to its harness, stamped with `"provenance": {"formalCommit": "<sha>"}`,
and its own list of known divergences (vector id, spec lines, reason and the implementation's
recorded behaviour). A listed vector is checked against the recorded behaviour; an entry must
name a vector of its family and must differ from the model's decision, so a fixed divergence
fails the harness until its entry is removed. An implementation fix therefore needs no change
here.

| File               | Family        | Covered                                                                                                                                           |
| ------------------ | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `forced.json`      | `forced`      | `saveForcedInclusion` (fee formula and doubling threshold, size limit, refund, queue indices), `sweepProtocolFees`                                |
| `registry.json`    | `registry`    | `register`, delayed `topUp`/`activateTopUp`, `requestExit`, `confirmExit`, total-principal `withdraw`/`slashDoubleSign`, responsibility `forfeit` |
| `land.json`        | `land`        | `land` with a verifier that accepts every proof                                                                                                   |
| `recover.json`     | `recover`     | nonce/expiry-bound `recover`, `invalidateRecoveryNonce`, decoded verifier-replacement rollback                                                    |
| `forced_step.json` | `forced_step` | one block's forced-inclusion decision (`Forced.step`, 7.2)                                                                                        |
| `schedule.json`    | `schedule`    | the committee active at a height and its election (`Consensus.activeAt`, `ElectionValid`, 4.2-4.3), and the switch blocks (`WitnessValid`)        |
| `block_rules.json` | `block_rules` | the hash-independent block-validity rules of 3.2-3.4 (`HeaderValid`, `AnchorValid`)                                                               |
| `block_size.json`  | `block_size`  | the 124,000-byte block size bound of 3.4 (the `blockBytes` conjunct of `HeaderValid`)                                                             |

## Generating and running

The files are generated, never edited. In `formal/etna`:

```sh
lake exe etna-vectors --write ../../testdata/etna_conformance
```

`--families <family>,…` writes only the named families, byte for byte as in a full run.

`formal/etna/tests/test_vectors.py` checks that two runs are byte-identical and that the committed
files equal a fresh run; the formal CI checks freshness after the build. The generator
(`formal/etna/EtnaVectors/`) runs the model's executable transitions (`ProtocolState.land`,
`Forced.enqueue`, `Forced.sweep`, `Forced.extraETH`, `ProtocolState.recover`,
`RegistryHistory.register`, `RegistryHistory.edit`) and the model's executable rules
(`Forced.step`, `Consensus.activeAt`, `Consensus.ElectionValid`, `BlockValidity.WitnessValid`,
`BlockValidity.HeaderValid`, `BlockValidity.AnchorValid`) and writes what they return. It imports
only the model.

**Contracts.** The Foundry harness of the Etna contracts PR (#22286),
`packages/protocol/test/layer1/etna/conformance/EtnaConformance.t.sol`, reads its copy at
`packages/protocol/test/layer1/etna/conformance/vectors/*.json` and lists its known divergences
in `_knownDivergences`. Refresh the copy from `formal/etna` with

```sh
lake exe etna-vectors --write <contracts checkout>/packages/protocol/test/layer1/etna/conformance/vectors \
  --families forced,land,recover,registry --provenance "$(git rev-parse HEAD)"
```

and run every vector in that checkout with

```sh
cd packages/protocol
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/etna/conformance/*'
```

The contracts copy holds only the four Inbox files (`forced`, `land`, `recover`, `registry`),
hence `--families`.

**Rust client.** The harness of the Etna client PR (#22280),
`packages/taiko-client-rs/crates/abci/tests/etna_conformance.rs`, reads its copy of the four
client-rule files at `packages/taiko-client-rs/crates/abci/tests/fixtures/etna_conformance/` and
lists its known divergences in `known_divergences`. Refresh the copy from `formal/etna` with

```sh
lake exe etna-vectors --write <client checkout>/packages/taiko-client-rs/crates/abci/tests/fixtures/etna_conformance \
  --families forced_step,schedule,block_rules,block_size --provenance "$(git rev-parse HEAD)"
```

and run it (also part of `just unit`) with

```sh
cd packages/taiko-client-rs
cargo test -p abci --test etna_conformance
```

Both copies are stamped with the formal commit they were generated at, so the stamp must name a
pushed commit: refresh a copy from a pushed formal commit whenever these files change (a copy
made from a local commit is refreshed again when that commit is pushed). The harnesses check
that the stamp is a 40-digit commit, not which commit it is; that a copy equals this directory
at its stamp is checked by the refresh itself, not by CI.

## Schema (`etna-conformance-2`)

Each file is one object: `schema`, `family`, `generator`, `provenance` (the copies only),
`constants` (the fixed deployment below), `vectorCount` and `vectors`. A vector:

```json
{
  "id": "registry.hw.slashed-slot-released-by-anyone",
  "family": "registry",
  "source": "handwritten",
  "spec": "spec L152",
  "setup": {"deployment": {...}, "callCount": 3, "calls": [<call>, ...]},
  "call": <call>,
  "expect": {"revert": false, "result": {"paid": 0}, "observable": {"registry": {...}}}
}
```

- `source` is `generated` (an enumerated grid) or `handwritten` (an edge case taken from the spec
  text). Only hand-written vectors have `spec`, a line of
  `packages/protocol/docs/etna-pos-zk/SPEC.md` at the revision `formal/etna` pins.
- `setup.deployment` sets the immutables a vector varies: `initialized` (false leaves the Inbox
  proxy on its bootstrap implementation), `maxBatchBlocks`, `feeGwei`, `threshold`,
  `recipientAccepts` (false makes `protocolFeeRecipient` a contract that rejects ETH),
  `minStake`, `activationDelay`, `exitDelay`, `withdrawalDelay`, `bountyBps`, `forfeitBps` and
  `unsettled` (U). Two explicit bootstrap fixtures are separate from protocol deployment inputs:
  `recoveryNonce` defaults to 0, with a persistent-state override for uint256 boundary tests;
  `registrySize` defaults to 1, or bootstraps keys/owners 1 through N as same-block registrations
  at block 10 (N≤4096), each with `minStake` and activation block `10 + activationDelay`. The capacity case uses
  N=4096. A harness must establish these states before replay; the nonce override is not a
  claim that a short public trace reaches 2^256−1.
- Every setup call succeeded in the model and must succeed in the contract. Then `call` runs.
- A call is `{"block", "timestamp", "fn", "args"}`: roll L1 to `block`, set the timestamp and
  call `fn`. The functions and their `args`:
  - `land`: the eight `LandInput` fields; `leaves` (each `{comet, cut, el, head, height, word}`:
    a cut leaf `keccak256(abi.encode(height, el, comet, head))` when `cut`, else `bytes32(word)`);
    `refAvailable` (the reference block's hash is readable; false makes `blockhash` return 0
    within 256 blocks, and no EIP-2935 contract serves older blocks); `blobs` (the blob count);
    `proofsOK` (false: the verifier rejects).
  - `saveForcedInclusion`: `caller`, `rawBytes` (the length of the submitted bytes), `paid`
    (msg.value in wei), `refundOK` (false: the caller is a contract that rejects the refund).
  - `sweepProtocolFees`: `caller`. `forceETH`: `amount` wei forced into the Inbox.
  - `recover`: `owner` (false: a non-owner calls), `expectedGeneration`, `expectedC`,
    `expectedRecoveryNonce`, `validUntil` (absolute L1 Unix seconds), `exclusions` (`{bondId, key}`: `entryKey` of registry key `key`, the released-slot key for 0),
    `fiToClear`.
  - `invalidateRecoveryNonce`: `owner`, `expectedRecoveryNonce`.
    `verifierFailureRollback` is an explicit upgrade fixture, not a contract function: restore
    the trusted initialization checkpoint and snapshot through the decoded checked rollback,
    retaining registry principal/flags and incrementing the current nonce. The actual upgrade,
    verifier replacement and trusted-target authentication remain external obligations.
  - `topUp`: `caller`, `bondId`, `amount`, `transferOK` (the authenticated token-transfer result).
    `activateTopUp`: `caller`, `bondId` (any caller).
    `forfeit`: `owner` (registry-owner authentication), `bondId`, `entryKey`, `incidentId`,
    `validUntil` (L1 Unix seconds), `externalOK` (authenticated effect success). These adapter
    booleans exercise atomic failure decisions, not ERC20 callbacks or actual DAO attribution.
  - `register`: `caller`, `key`, `amount`. `requestExit`, `confirmExit`: `caller`, `bondId`.
    `withdraw`: `caller`, `bondId`, `to`.
  - `slashDoubleSign`: `caller`, `bondId`, `voteA`, `voteB`, each
    `{blockId, foreign, generation, height, kind, round, signer}`: vote type `kind`, block hash
    `bytes32(blockId)` with a one-part part set (all zero for 0), signed by private key `signer`
    under this deployment's chain id for `generation`, or another deployment's if `foreign`.
- `expect.revert` is the model's verdict. On success `expect.result` holds what the call
  returns or moves: `bondId`, `feeWei` (kept by the Inbox), `refund`, `swept`, `paid` (to `to`),
  `bounty` (to the caller) and `toSink`. `expect.observable` is the state after the call (the
  state before it when it reverts):
  - `inbox`: `checkpointHeight`, `checkpointHash`, `generation`, `recoveryNonce`, FI `head` and `tail`,
    `snapshot` (slot 284), `ethBalance`, `swept` (the recipient's balance), `feeGwei` (the next
    fee), `records` (slot 285 by height), `signals` (SignalService checkpoints), `origins`
    (slot 290 by generation) and `queue` (`blank` means `txHash == keccak256("")`).
  - `registry`: `entryCount`, `freeCount`, `stakeHeld` (effective plus pending principal held by the registry),
    `checkpointCount`, `lastCheckpointBlock`, `lastCheckpointCount`, full `checkpoints`
    (newest first, election entries contain effective stake only), lifetime `forfeitedKeys`
    (newest first) and `bonds` (`stake`, `pendingTopUp`, `topUpReadyAtL1` plus identity/exit metadata;
    `exitAt` 2^48 - 1 is no exit; `confirmedAt` 0 is unconfirmed; a released slot is all zero).
- Objects inside arrays list their keys alphabetically, so a forge harness decodes each array
  into a struct array in one read. JSON numbers are below 2^53. Schema 2 encodes larger uint256
  amounts, balances, results, nonces and deadlines as canonical unsigned decimal strings;
  consumers must parse both exact numbers and decimal strings without a floating-point step.
  There is no negative, fractional, exponent or leading-zero form. Calls, keys and array shapes
  remain explicit; old labels are retained for unchanged cases.

The new registry cases exercise pre-initialization deposits and activation, one pending
amount, exact readiness and overflow, deposits with all 4096 slots allocated, checkpoints only
on activation, total-principal withdrawal/slashing, pending-only balances, ceiling forfeiture,
expiry equality, owner/key guards, transfer failure, release/reuse and ordering with exits,
withdrawal, double-sign evidence, landing, nonce invalidation, recovery and rollback. Recovery
cases exercise expiry equality, initialization, exact/replayed/stale nonces, last-successful and
overflow increments, unchanged landing nonce and rollback non-revival. The authenticated
owner/effect adapters leave DAO execution paths, attribution and callback/reentrancy execution
for downstream acceptance; they do not establish those implementation properties.

## Mapping model values to contract values

- The model's hashes are atoms (`Hash = Nat`). Atom `n` is `bytes32(n)`. A generation `g` chain
  has EL hash `100000 g + 10000 + x` at height `x`, Comet hash `100000 g + 20000 + x` (0 at
  genesis) and state root `100000 g + 30000 + x`; genesis is `bytes32(10000)` and
  `bytes32(30000)`.
- Registry key `k` is the compressed secp256k1 key of private key `k`; key 0 is a released slot.
- Account `n` is the address `0x10000 + n`; account 0 is the zero address. The Inbox owner (the
  harness) recovers when `owner` is true.
- The registry's signature adapter accepts a vote's signature exactly when `signer` is the bond's
  key, which is what a real signature by private key `signer` does.

## Fixed deployment (`constants`)

K = 6 (the contract's `GRID_INTERVAL`). The genesis validator (key 1, account 1, `minStake`)
registers at L1 block 10, the registry's first checkpoint and the genesis cutoff; the Inbox is
initialized at block 11 with L = 10, a one-hour forced inclusion delay, maxAnchorAge 7,200 s and
committee configuration (vp_unit, s_min, n_max, U) = (10^9, 10^9, 128, `unsettled`). The call at
block `b` runs at timestamp `1700000000 + 12 b` unless the vector says otherwise. An available
reference block hashes to `bytes32(7)`.

## Inputs the generator chooses

The model leaves some values to its environment; the generator fixes them the way the contract
sees them:

- A landing's proofs are two successful subproofs (SGX and SP1) whose certificate is the
  statement the Inbox builds: a verifier that accepts every proof.
- A sweep's transfer succeeds when the recipient accepts ETH or the balance is zero (the
  contract sends nothing then).
- An empty submission's `txHash` is the atom of `keccak256("")`, the value recovery writes over a
  blanked entry, so an empty submission reads as blanked.
- An enqueue needs the block and the timestamp below 2^48, the ranges of
  `ProtocolState.Step.enqueue`.

## Not covered by the Inbox families

ABI and storage encodings, events, ERC-7201 namespace byte layouts, actual ERC20 transfers,
consensus-key and signature formats (`../etna_vectors/vectors.json`), committee election, and real guests
remain separate conformance obligations. Logical fields and decoded atomic-effect adapters do
not prove those implementations. The client-rule families below cover only their listed pure
rules. Actual verifier-replacement upgrades, trusted rollback-target provenance, deployment
initialization validation, DAO standard/emergency execution, and callback/reentrancy execution
remain external. Initialization guards for recover/invalidation and the registry calls are
covered, rather than every Inbox function. Available EIP-2935 hashes at ages 257–8191 are not
covered (an unavailable hash at age 257 and age 8192 are).

## Client-rule families (`etna-client-conformance-1`)

Each file is one object: `schema`, `family`, `generator`, `provenance` (the copy only), the
family's shared tables, `vectorCount` and `vectors`. A vector:

```json
{
  "id": "forced_step.hw.blanked-entry-due-skips-without-el",
  "family": "forced_step",
  "source": "handwritten",
  "spec": "spec L432",
  "input": {...},
  "expect": {...}
}
```

`source` and `spec` are as above; a hand-written id contains `.hw.`. A known divergence in the
client harness records the client's decision on a subset of the `expect` keys, and the harness
requires exactly that. The harness lists every mismatch of a family before failing.

### `forced_step`

- `txKinds` (shared): the transaction bytes a vector names, each with the length and canonicity
  the model sees. `empty` (zero bytes; its hash is `keccak256("")`, a blanked entry's), `txA` and
  `txB` (canonical), `junk` (32 bytes), `junkMax` (8,192 bytes), `junkOver` (8,193 bytes) and
  `txBig` (a canonical transaction above 8,192 bytes). The harness builds concrete bytes and
  checks them against this table.
- `input`: `cursor` (the parent's), `tail` (the anchor's queue tail), `anchorTimestamp`, `delay`,
  `witness` (`null`, or `{index, authenticated, entry, entryTimestamp, entryBlock, tx}`: the index
  it names, whether its proof verifies under the anchor, the entry's transaction kind and L1
  timestamp, and the raw bytes it carries), `firstTx` (the block's transaction 0, or `null`) and
  `singleton` (the given-list build of `[tx]`: `completedEmpty`, `completedRetained`,
  `inconsistent`, i.e. built for another context, or `unavailable`, no result yet).
- `expect`: `{"result": "accepted", "cursor": n}`, `{"result": "waiting"}` or
  `{"result": "rejected"}`.
- Client mapping: the kinds become concrete, really signed transactions, and the model's
  canonicity is the client's `decode_eligible`. `forced::check` runs on a real EIP-1186 proof of
  the entry (an unauthenticated one verifies under another root), then
  `engine::forced::verify_forced` with an engine that returns the `singleton` result. A retryable
  build error is `waiting`: ProcessProposal and FinalizeBlock both wait and retry it.

### `schedule`

- `contexts` (shared), generation 0: `epochLen` (L), `originBlock` (`L1_0`), `genesisCutoff`,
  `unit` (vp_unit), `minimum` (s_min), `nMax`, `snapshots` (registry checkpoints, oldest first,
  each `{block, entries}` with entries by bond id: `{key, stake, activeFrom, exitAt,
staleHeartbeat}`; `exitAt` 2^48 - 1 is no exit, a released slot is all zero) and `archive`
  (element x is the anchor of L2 block x).
- `input`: `context` and `height`.
- `expect`: `targetEpoch`, `cutoff`, `valid` (the election succeeds), `members` (`{key, stake,
power}` in key order; compared only when valid) and `switchTarget` (the epoch t a switch block
  S(t) derives, or `null` when the height is no switch block).
- Client mapping: `Schedule::epoch_of`, `derivation_parent_height` and `switch_target`, the cutoff
  at the derivation parent's anchor (`genesisCutoff` for epoch 0), the latest checkpoint at the
  cutoff and `committee::derive`. Key atoms map to valid secp256k1 consensus keys in ascending
  set-key order; key 0 is a released slot's all-zero entry. `staleHeartbeat` is client-only input
  the model ignores (the spec has no heartbeat rule); a client with such a rule would diverge on
  the vectors that set it.

### `block_rules`

- `input`: `rule` (the rule the vector varies; its other inputs stay valid), `chainGeneration`,
  `epochLen`, `origin` (`L1_0`), `maxAnchorAge`, `unsettled` (U), `parent` (`height`,
  `timestamp`, `anchor`, `anchorTimestamp`), `block` (`height`, `bftTime`, `timestamp` (the
  header's), `feeShare` (`extraData[0]`), `generation` (the `extraData` generation)) and
  `anchor` (`number`, `timestamp`, `checkpointHeight` (its `lastCheckpoint.height`),
  `generation` (its Inbox generation)).
- `expect`: `{"valid": bool}`, the model's `HeaderValid ∧ AnchorValid`. Every other field the
  two predicates read (hashes, witness presence, the committee-hash adapter, the reference block
  number, set to 2^48 so only the anchor's 48-bit range binds) takes the value its conjunct
  requires.
- Client mapping: `check_anchor_progress`, `check_generation` and `check_back_pressure` (as
  `validate_block` runs them), `rules::expected_header` (height linkage, the derived timestamp,
  the `extraData` and its uint48 ranges), `check_anchor_freshness`, and the header's timestamp
  and whole `extraData` (base-fee sharing byte, generation, anchor number) against the derived
  ones.

### `block_size`

- `input`: `blockBytes` (the length of the envelope's block item, the RLP of
  `[header, transactions]` with its list header) and `content` (`incompressible` or `zeros`:
  client-only input the model ignores, which would matter to a bound on compressed bytes).
- `expect`: `{"valid": bool}`, `HeaderValid ∧ AnchorValid` with every other input valid, i.e.
  `blockBytes ≤ 124,000`.
- Client mapping: a block whose RLP item has exactly `blockBytes` bytes (one opaque transaction
  of filler), judged by `app::check_execution_size`, the bound `validate_block` checks first.

### Not covered and historical divergences

Not covered by the client families: the lander's landing grid and cut leaves, hash-dependent
rules (parent hash, `chain_id`, witnesses, MPT binding), recovery generations (the schedule
family is generation 0 only) and the application's request handlers (`validate_block`,
ProcessProposal, FinalizeBlock), which need a committed app state and an execution engine; the
harness composes the public rules in `validate_block`'s order instead.

The table below preserves the **historical schema-1** divergence record from formal head
`c9708e76159bb8da701f8bc20c07ff2e46537642`, against the old exported source revision
2026-10-28. Its Inbox inventory was 334 cases (114 forced, 98 land, 48 recover, 74 registry)
and its client inventory was 340 cases (151 forced_step, 83 schedule, 92 block_rules, 14
block_size). Source line numbers in this historical table belong to old `sources/spec.md`.
These recorded implementation behaviours are not new results for schema 2 or the current
specification. No production harness was run by this regeneration; consumers must adopt the
new fields/operations, refresh a pushed-commit copy and rerun their complete acceptance.

Historical divergences, as listed in the earlier harnesses:

| Implementation | Vector                                        | Spec            | Model                                         | Implementation                      | Kind                        |
| -------------- | --------------------------------------------- | --------------- | --------------------------------------------- | ----------------------------------- | --------------------------- |
| contracts      | `registry.hw.free-slot-reuse-order`           | spec L139       | reuses the oldest freed slot (bond 1)         | reuses the most recent (bond 2)     | spec ambiguity, reachable   |
| contracts      | `registry.hw.withdraw-to-zero-address`        | spec L142       | accepts (no recipient)                        | reverts `ZERO_ADDRESS`              | spec ambiguity, reachable   |
| contracts      | `registry.hw.withdraw-at-block-2pow48-minus1` | spec L751, L753 | accepts                                       | reverts `InvalidEventBlock`         | unreachable block           |
| contracts      | `registry.hw.slash-at-block-2pow48-minus1`    | spec L151, L751 | accepts; the entry keeps no exit              | reverts `InvalidEventBlock`         | unreachable block           |
| contracts      | `recover.hw.exclusion-at-block-2pow48-minus1` | spec L460, L751 | accepts; the entry stays eligible             | reverts (`forceExit`)               | unreachable block           |
| contracts      | `recover.hw.origin-timestamp-2pow48`          | spec L744       | accepts (word bound 2^256)                    | reverts `ValueOverflow` (2^48)      | spec ambiguity, unreachable |
| client         | `block_rules.hw.height-2pow48`                | spec L266       | rejects: `HeaderValid` requires height < 2^48 | accepts: 3.4 states no height bound | spec ambiguity, unreachable |
