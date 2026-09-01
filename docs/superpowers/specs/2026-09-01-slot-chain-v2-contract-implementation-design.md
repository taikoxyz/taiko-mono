# Slot Chain V2 Additive Contract Implementation Design

**Status:** Approved implementation architecture

**Design baseline:** `365737104c69559d73c78b170dcf7a1512fa66b5`

**Target branch:** `codex/slot-chain-v2-contracts`

**Stacked base:** `claude/chain-liveness-builder-roles-cda13y` / PR #22064

## 1. Objective

Implement and test the complete on-chain Slot Chain V2 protocol described by the frozen LaTeX,
PDF, executable models, and commitment vectors at the design baseline. The implementation is an
additive, deployable V2 suite under `packages/protocol`; it must exercise real Solidity storage,
authority, accounting, bounded-gas, migration, settlement, bridge, and reclamation behavior.

The implementation PR must not select the V2 suite for production, modify the behavior of the
currently selected Inbox, Bridge, vault, Resolver, or deployment path, or treat a passing test
suite as deployment authorization. Production cutover remains a separately reviewed operation.

## 2. Normative Precedence

The implementation consumes, in descending precedence:

1. `packages/protocol/docs/preconfirmation-v2/tex/main.tex` at the design baseline;
2. the executable Python models and commitment vectors in the same directory;
3. this implementation architecture; and
4. repository Solidity conventions in `packages/protocol/CLAUDE.md`.

The older August 29 contract-suite specification and 45-round plan are historical inputs. They may
be reused only where they agree with the final design baseline. In particular, no older
Bridge-facade, shared-cap, migration-callback, route-authority, retirement, or reclamation rule may
override the final VMC1, RAV2, DRV2, DSV2, ICV2, BRX1, or related fixed-width protocols.

If Solidity exposes a contradiction between normative sources, the current implementation round
stops. A failing regression is added, the model and LaTeX/PDF are corrected in an isolated design
commit, and implementation resumes only after that correction is reviewed.

## 3. Selected Architecture

The suite is dependency-layered and isolated from the live protocol:

```text
packages/protocol/contracts/
  shared/slotchain/
    iface/     chain-neutral interfaces and exact external boundaries
    libs/      encodings, trees, signatures, proofs, checked calls
    impl/      chain-neutral custody and frozen facade implementations
  layer1/slotchain/
    iface/     L1 component interfaces with full NatSpec
    libs/      authenticated history and pure L1 transition helpers
    impl/      market, registry, queue, settlement, migration, source bridge
  layer2/slotchain/
    iface/     L2 component interfaces with full NatSpec
    libs/      route, credit, execution-context, terminal helpers
    impl/      activation, apply router, stores, destination bridge, pool, terminal plane

packages/protocol/test/
  shared/slotchain/
  layer1/slotchain/
  layer2/slotchain/

packages/protocol/integration/slotchain/
  two-chain deployment, relay, migration, bridge, and restart tests
```

Production components are non-proxy unless the frozen legacy-compatibility profile explicitly
requires a final storage-compatible facade or the authenticated AnchorV4 topology. Dependencies
are constructor immutables, deterministic precomputed addresses, or narrowly scoped one-shot seals.
There is no generic Resolver dependency, arbitrary setter, delegate target, root setter, or
governance pause on canonical progress or claims.

Shared, L1, and L2 artifacts are compiled under their owning Foundry profiles. Cross-profile users
load the already compiled artifact; they do not source-import and recompile it under another EVM or
optimizer configuration.

## 4. Component Boundaries

### 4.1 Shared primitives

Shared libraries implement byte-exact commitments, fixed-domain Merkle trees, the bounded MMR,
canonical RLP/MPT verification, low-`s` signatures, checked arithmetic, and exact-length checked
external calls. A caller cannot choose a hashing domain, silently narrow an integer, accept trailing
return data, or substitute an uncommitted code/configuration hash.

Interfaces own full NatSpec. Implementations use `@inheritdoc`, named imports, repository naming
conventions, custom errors, and the required security contact.

### 4.2 L1 availability and economic plane

The L1 data plane contains the immutable economic profile, builder registry and liability
generations, schedule/lookahead oracle, bounded data sessions, permanent forced queue, and the
continuous reverse-ask `AggregatorSeatMarket`.

The seat is an availability service obligation, never consensus or proof authority. The market
owns offers, tranches, premium reserves, pull credits, staged handovers, release requests, and
asynchronous enforcement. Settlement owns the current roster and duties. Every cross-contract
mutation uses the exact fixed-width interface and exact target defined by the baseline.

### 4.3 L1 settlement and migration plane

Settlement owns candidate validation, normal settlement, recovery episodes, canonical history,
reward receipts, roster duties, successor selection, and bounded reclamation. Proof submission,
forced recovery, sync, and canonical progress remain permissionless and do not call the market or
an operator-controlled address.

`ActiveSettlementRouter`, `ProtocolVersionManagerV1`, the migration gate, and deployment factories
implement proof-first activation and abort. VMC1 is the sole post-QMIG mutating external call, is
made with its exact 100-byte calldata, zero value, exact caller, and 200,000 requested gas, and is
the final external call inside the outer atomic activation revert domain.

No component may select a historical Settlement, route, Bridge, generation, or source bundle by a
caller-supplied witness. Authority is derived through the Router/registry fixed-width reads and
manifest-pinned code/configuration.

### 4.4 Source and destination bridge planes

The source side uses fresh V2 custody: immutable SourceBridge, BridgeCreditRegistry, quota/domain
registry, queue adapter, and terminal-proof finalization. It never reuses the existing V1 Bridge
account and never mutates V1 selectors or storage.

The destination side uses `InboxApplyRouterV2`, immutable endpoint credit stores,
`DestinationBridgeV2`, `NativeLiquidityPoolV2`, release authority, terminal registrar, and
depth-64 terminal accumulator. ICV2 supplies the exact O(1) credit/fee read. RAV2 authenticates
retirement. DRV2/DSV2 preserve direct-successor and multi-hop reclamation independently of the
latest tip.

Recipient calls, liquidity callbacks, Store writes, Bridge lifecycle changes, terminal appends,
and source liability changes are separately bounded and joined only in the normative revert
domains. A failed target or callback restores the exact parent state; no partial credit, ticket,
liability, quota, queue, or terminal mutation survives.

### 4.5 Deterministic deployment and profiles

Address cycles are solved by manifest-pinned deterministic factories or a fixed deployment nonce
sequence, never by general setters. The implementation produces reproducible runtime hashes,
configuration hashes, storage layouts, creation artifacts, component DAGs, and root deployment
transcripts.

The production profile generator rejects test verifiers, null or uncalibrated economic fields,
unknown artifacts, profile-dependent recompile drift, legacy endpoint reuse, mutable trust-map
wrappers, and incomplete authority burning.

## 5. Core State and Boundary Invariants

The following invariants are release-blocking:

- canonical safety never depends on an honest, present, or distinct builder or seat holder;
- every canonical transition is monotone, authenticated, replay-protected, and bounded;
- the last builder of one window and first builder of the next may be the same key, but the global
  same-key run is at most two slots and a new primary duty is created at APPLY;
- a malicious boundary builder can withhold only its own service; it cannot forge execution,
  inherit an expired duty, suppress forced recovery, or prevent later permissionless progress;
- equality at a deadline follows the frozen inclusive/exclusive rule; subtraction cannot underflow
  and a zero sentinel cannot become accidentally due;
- all history, frontier, queue, duty, tranche, offer, journal, and scan work has a fixed capacity or
  O(1) reverse index;
- ETH and token liabilities are conserved across deposits, reservations, credits, slashes,
  refunds, target failures, migration, retirement, and reclamation;
- terminal or released state never resurrects, and direct-successor receipts remain sufficient
  after arbitrary later hops;
- migration success, abort, expiry, reorg, callback failure, and restart leave one fully specified
  authority owner and no ambiguous lease or generation; and
- bootstrap authority is either unused in the initial state or irreversibly consumed/burned.

## 6. Data Flow and Failure Isolation

Normal and recovery proofs authenticate their prestate, statement, verifier, bounded data, and
expected output before canonical state is published. State publication precedes only the explicitly
allowed final migration callback. Any verification, return-length, magic, code-hash, gas, or join
failure reverts the entire canonical transition.

Economic maintenance is deliberately outside canonical progress. Market, premium, bond, reward,
and operator payout failures can revert only their maintenance or claim transaction. Payouts use
pull credits and checks-effects-interactions.

Bridge and Pool entry points use explicit reentrancy state and complete transient authorization
tuples. Only the exact child callback is permitted while entered. Direct calls, stale routes,
historical Bridges, alternate Stores, malformed return data, duplicate consumption, excessive gas,
and callback reentry revert without effect.

External faults use custom typed errors. Tests assert both the selector and unchanged state, not
merely that a call reverted.

## 7. Implementation and Commit Strategy

The work remains one stacked PR but is implemented as dependency-ordered TDD commits. Each slice
contains its interfaces, minimum implementation, focused tests, adversarial boundary tests, and any
generated artifacts. A slice is not committed until its owning profile builds, focused and profile
tests pass, touched Solidity formats cleanly, storage layout is recorded, and critical/high review
findings are resolved.

The detailed implementation plan will replace the stale 45-round plan with independently testable
milestones. It will preserve fine-grained commits but group work around coherent deployable
capabilities rather than arbitrary file counts.

## 8. Verification Strategy

Verification includes:

- unit tests for every public transition and custom error;
- golden-vector and differential tests against all Python commitment/state models;
- fuzz tests for widths, deadlines, malformed ABI/returndata, ordering and replay;
- invariant/handler tests for solvency, monotonicity, terminality, bounded work and authority;
- explicit first/last builder and cross-window traces, including same-key two-slot runs, handover,
  late cure, failover, slash, release, migration, retirement and restart at each boundary;
- target revert, out-of-gas, reentrancy, callback rollback and EIP-150 envelope tests;
- two-Anvil-chain integration for normal/recovery settlement, DIRECT ETH ingress, LP funding,
  DONE/FAILED/cancel/refund, proof-first activation, abort and multi-hop reclamation;
- storage-layout compatibility tests only for explicitly supported legacy facades;
- deterministic artifact/profile/deployment transcript regeneration; and
- gas and runtime/initcode size checks at every normative maximum with the specified safety margin.

Coverage must exceed 95% for the new suite, but line coverage is not acceptance by itself. Every
normative transition, error branch, boundary equality, maximum-capacity state, external-call fault,
and rollback domain must have semantic assertions.

## 9. Completion Criteria

The implementation PR is complete when every normative on-chain component and interface exists,
the final models and Solidity agree on commitments and transitions, all test classes above pass,
runtime/config/layout artifacts are reproducible, the full deployment can be created on two local
chains, and no reviewed Critical or High finding remains.

Completion of this PR does not make the protocol production-ready. Real circuits and verifier
keys, measured production economic parameters, client/fork support, cross-language conformance,
testnet migration rehearsal and soak, operational monitoring, and independent proof-system,
Solidity, Bridge, and economic audits remain external release gates. The PR must report these
honestly and must not include a production cutover.

## 10. Stop Conditions

Implementation stops and returns to design review if any slice requires:

- a caller-controlled trust assumption or historical target selector;
- unbounded protocol work or an unindexed hot-path scan;
- a canonical dependency on seat/market/operator availability;
- partial state survival outside a normative failure domain;
- reuse of live V1 custody or mutation of production-path behavior;
- a generic mutable authority not committed by the release manifest; or
- weakening a normative invariant, test, gas bound, or security check merely to compile or pass.
