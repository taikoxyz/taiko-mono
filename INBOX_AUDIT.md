# Inbox.sol Security Assessment (OpenZeppelin-Style)

Date: 2025-12-30
Target: `packages/protocol/contracts/layer1/core/impl/Inbox.sol`
Commit (worktree): `f02be64bcfea1d2f82fa9526731b3445628d6d10`

This report is a manual, best-effort security assessment of `Inbox.sol` and
its direct and transitive dependencies. It does not audit proof circuits,
prover software, offchain clients, or other contracts beyond their public
interfaces.

## Summary

- Medium: 0
- Low: 3
- Informational: 4

## Scope and Methodology

### In scope

- Core contract:
  - `packages/protocol/contracts/layer1/core/impl/Inbox.sol`
- Direct libraries used by Inbox:
  - `packages/protocol/contracts/layer1/core/libs/LibBlobs.sol`
  - `packages/protocol/contracts/layer1/core/libs/LibCodec.sol`
  - `packages/protocol/contracts/layer1/core/libs/LibForcedInclusion.sol`
  - `packages/protocol/contracts/layer1/core/libs/LibHashOptimized.sol`
  - `packages/protocol/contracts/layer1/core/libs/LibInboxSetup.sol`
  - `packages/protocol/contracts/shared/libs/LibAddress.sol`
  - `packages/protocol/contracts/shared/libs/LibMath.sol`
- Transitive dependencies used by Inbox through libraries:
  - `packages/protocol/contracts/layer1/core/libs/LibPackUnpack.sol`
  - `packages/protocol/contracts/shared/common/EssentialContract.sol`
  - `openzeppelin-contracts-upgradeable` (UUPS, Ownable2Step)
  - `solady` (EfficientHashLib)
- Interfaces used by Inbox:
  - `packages/protocol/contracts/layer1/core/iface/IInbox.sol`
  - `packages/protocol/contracts/layer1/core/iface/ICodec.sol`
  - `packages/protocol/contracts/layer1/core/iface/IForcedInclusionStore.sol`
  - `packages/protocol/contracts/layer1/core/iface/IProposerChecker.sol`
  - `packages/protocol/contracts/layer1/core/iface/IProverAuction.sol`
  - `packages/protocol/contracts/layer1/verifiers/IProofVerifier.sol`
  - `packages/protocol/contracts/shared/signal/ICheckpointStore.sol`
  - `packages/protocol/contracts/shared/signal/ISignalService.sol`

### Out of scope

- Proof system correctness and circuit constraints
- L1/L2 clients, sequencers, relayers, or DA enforcement
- Consensus assumptions and blob availability

### Methodology

- Manual review of Solidity source and transitive dependencies
- Threat modeling for adversarial mainnet conditions and trust boundaries
- Findings informed by prior local audit notes in `audit/inbox-audit.md`
- Findings prioritized by patterns commonly highlighted in public audit
  reports (access control, input validation, reentrancy, economic design)

### Public audit pattern lens (applied)

- Data validation and access control are the most common root causes across
  public audit summaries, so inputs and authorization gates were prioritized.
- Timing and numerics are frequently represented in high-severity findings,
  so timestamp and deadline logic were reviewed in `propose` and `prove`.
- OpenZeppelin public summaries highlight fraud-proof verification,
  cross-domain interactions, fee mismanagement, and reward abuses. These map
  to proof binding, checkpoint calls, and proposer/prover incentives in Inbox.
- OpenZeppelin audit lessons also emphasize reentrancy, unprotected external
  calls, and input validation, which informed review of `prove()` ordering
  and `LibPackUnpack` usage.

## 1. Threat Model

### Assets

- L2 proposal ordering and finalization correctness
- Prover auction incentives, slashing, and fee distribution
- Forced inclusion queue integrity and liveness
- Checkpoint correctness and rate limiting

### Actors

- Permissionless users calling `propose`, `prove`, `saveForcedInclusion`
- Proposers authorized by `IProposerChecker` or permissionless conditions
- Provers (auction-selected or self-provers)
- Owner (activation, pause, upgrades)
- Trusted system contracts (auction, signal service, verifier)

### Trust Boundaries

- `IProofVerifier`, `IProverAuction`, `ISignalService`, and
  `IProposerChecker` are trusted system components
- Blob data availability is assumed from L1 (`blobhash`)
- Offchain systems must interpret events and state transitions correctly

### Privileged Roles

- Owner can `activate`, pause/unpause, and upgrade (UUPS)
- Initializer sets critical config and external dependency addresses

### Upgradeability and Proxy Assumptions

- `Inbox` is UUPS-upgradeable via `EssentialContract`
- Owner is assumed to upgrade safely and maintain trusted dependencies

## 2. Findings

Severity ratings follow typical OpenZeppelin practice. Likelihood is relative
to mainnet conditions, given the stated trust assumptions.

### I-01: Transition metadata is verified in the proof system

**Severity:** Informational

Impact: `prove()` relies on the proof system to bind Transition metadata
(timestamp, designated prover, proposer, block hash) to the L1 proposal data.
Given the confirmed proof guarantees, no onchain re-verification is required.

Likelihood: Low, based on the stated proof-system behavior.

Notes:

- The `prove()` NatSpec documents this trust boundary explicitly.

### L-01: Reentrancy exposure in `prove()` via trusted external calls

**Severity:** Low

Impact: If a trusted dependency is compromised or upgraded maliciously,
reentrancy into `Inbox` can occur before `prove()` updates `_coreState`, which
can lead to state rollback or inconsistent finalization.

Likelihood: Low, as it requires a malicious or compromised trusted dependency.

Exploit path:

1. `prove()` calls `_proverAuction.slashProver` or
   `_signalService.saveCheckpoint`.
2. The external contract reenters `prove()` with a different proof.
3. The outer call resumes and writes a stale `_coreState` snapshot.

PoC sketch (pseudo):

```solidity
contract MaliciousSignalService {
    Inbox inbox;
    function saveCheckpoint(...) external {
        inbox.prove(data2, proof2);
    }
}
```

### I-02: Pause mechanism is intentionally unused for Inbox

**Severity:** Informational

Impact: `pause()` is not used as an emergency stop for Inbox by design. The
protocol uses other mechanisms for emergency handling.

Likelihood: Certain, per project guidance.

### L-02: Reactivation preserves forced inclusion queue across epochs

**Severity:** Low (design risk)

Impact: Forced inclusions queued before reactivation remain valid after
proposal history is cleared. This can mix data across activation epochs and
complicate offchain assumptions during resets or reorg handling.

Likelihood: Low to Medium, as reactivation is owner-only but can be used
operationally.

Exploit path:

1. Owner reactivates `Inbox` to handle a reset.
2. Old forced inclusions remain queued and can be included under the new
   activation epoch.

### L-03: Forced inclusion queue is unbounded

**Severity:** Low

Impact: The forced inclusion queue can grow without a cap, increasing storage
usage and proposer burden. The fee curve may be insufficient to deter queue
growth during stress.

Likelihood: Medium under heavy spam or griefing conditions.

Exploit path:

1. Attacker repeatedly pays forced inclusion fees, growing the queue.
2. Proposers face high processing requirements or operational overhead.

### I-03: Trust-the-caller decoding with no length checks

**Severity:** Informational

Impact: `LibPackUnpack` performs no bounds checks. `Inbox.propose/prove` decode
user-supplied bytes without size validation. Malformed input can trigger
garbage reads or unintended decoding behavior.

Likelihood: Medium for malformed input attempts, low for exploitability.

### I-04: Genesis proposal is a sentinel with zeroed fields

**Severity:** Informational

Impact: `activate()` emits `Proposed` for a zeroed genesis proposal. Offchain
systems that treat it as a normal proposal may derive incorrect state.

Likelihood: Medium for indexer mistakes.

## 3. Fixes

Minimal-change patches are shown first, followed by safer redesign options.

### L-01: Add reentrancy guard or reorder effects

#### L-01 minimal patch

```solidity
function prove(bytes calldata _data, bytes calldata _proof)
    external
    nonReentrant
{
    ...
}
```

#### L-01 safer redesign

Adopt strict checks-effects-interactions. Update `_coreState` and emit events
before external calls, and make external calls last. This requires careful
analysis to preserve revert semantics.

### L-02: Epoch forced inclusions on activation

#### L-02 minimal patch

```solidity
require(inclusion.epoch == currentEpoch, StaleInclusion());
```

#### L-02 safer redesign

Maintain per-activation queues or clear the queue on reactivation. Document
the chosen behavior in offchain systems and runbooks.

### L-03: Bound forced inclusion queue growth

#### L-03 minimal patch

Add a maximum queue length (recommended 2048) or increase the fee curve
steepness when the queue exceeds a threshold.

#### L-03 safer redesign

Introduce a queue cap (recommended 2048) with eviction or epoch rollover, and
publish operational limits for offchain systems.

### I-03: Validate decode input sizes

#### I-03 minimal patch

Add length checks before decode in `propose` and `prove`, or validate expected
length in `LibCodec` before unpacking.

#### I-03 safer redesign

Switch to length-prefixed or ABI-encoded inputs for safety, with a migration
path for external tooling.

### I-04: Document genesis proposal sentinel

#### I-04 minimal patch

Document in `activate()` and in offchain indexer guides that proposal id 0 is
not a normal proposal and should be treated as a sentinel.

#### I-04 safer redesign

Emit a dedicated `GenesisProposed` event or add a flag in the proposal to
avoid ambiguity for indexers.

## 4. Invariants and Edge Cases

- **Reentrancy:** `propose()` is `nonReentrant`; `prove()` is not. External
  calls inside `prove()` are assumed trusted.
- **Pause semantics:** `pause()` is intentionally unused for Inbox; emergency
  handling is managed via other protocol mechanisms.
- **AuthZ/AuthN:** `activate()` is owner-only. `propose()` authorization is
  enforced by `IProposerChecker` and forced-inclusion rules.
- **Replay/state machine:** Proposal IDs must be strictly increasing and
  capacity checks must prevent overwriting unfinalized proposals.
- **DoS/griefing:** Forced inclusion queue growth can increase proposer cost.
- **Front-running/MEV:** Proposers can be front-run to capture fees or alter
  inclusion order. This is a known economic risk, not a correctness break.
- **Timestamp assumptions:** `block.timestamp` drives deadlines and
  permissionless windows. Miner skew affects incentive timing.
- **Cross-contract call safety:** `_proverAuction` and `_signalService` are
  trusted. Any deviation can impact liveness or consistency.
- **Event correctness:** `Proposed` is emitted on activation and reactivation
  (proposal id 0). Offchain consumers must handle multiple activations.
- **State machine correctness:** `_getAvailableCapacity` must only run when
  `nextProposalId > lastFinalizedProposalId`, otherwise it reverts to avoid
  underflow.

## 5. Tests (Foundry)

### Unit Tests

- Reentrancy guard (if added): malicious `ISignalService` reentry into
  `prove()` should revert.
- Reactivation epoching (if added): stale forced inclusions revert on dequeue.

### Fuzz and Invariant Tests

- **Invariant:** `nextProposalId > lastFinalizedProposalId` whenever
  `_getAvailableCapacity` is called; otherwise revert with `InvalidCoreState`.
- **Invariant:** capacity never underflows and `NotEnoughCapacity` is thrown
  when capacity is 0.
- **Invariant:** `getProposalHash(id)` matches stored proposals for
  unfinalized IDs and is cleared on reactivation except for genesis.
- **Invariant:** forced inclusion queue length does not exceed the configured
  cap (recommended 2048) if a cap is introduced.

### Edge Cases

- Forced inclusion queue empty or full, oldest inclusion due vs not due.
- `propose()` with deadlines at boundary values and min/max inclusions.
- `prove()` single- and multi-proposal batches across checkpoint delays.
- `activate()` called twice at activation window boundary.

## Conclusion

`Inbox.sol` is structurally robust with clear checks around proposal ordering,
forced inclusion, and proof verification. The transition-metadata binding risk
is resolved by the proof system guarantees, leaving primarily low-severity
design and operational considerations typical of modular rollup
architectures.

## References

- Internal notes: `audit/inbox-audit.md`
- Public audit pattern sources (see project notes and citations in delivery)
