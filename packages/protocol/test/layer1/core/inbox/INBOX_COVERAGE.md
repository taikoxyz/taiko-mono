# Inbox.sol Branch Coverage Analysis

This document tracks the branch coverage of `Inbox.sol` and its associated libraries by the test suite in `test/layer1/core/inbox/`.

## Forge Coverage Report

Coverage verified via `FOUNDRY_PROFILE=layer1 forge coverage`:

| File                   | Lines             | Statements        | Branches        | Functions       |
| ---------------------- | ----------------- | ----------------- | --------------- | --------------- |
| Inbox.sol              | 100.00% (137/137) | 100.00% (149/149) | 96.55% (28/29)  | 100.00% (20/20) |
| LibBlobs.sol           | 100.00% (7/7)     | 100.00% (9/9)     | 100.00% (4/4)   | 100.00% (1/1)   |
| LibForcedInclusion.sol | 100.00% (32/32)   | 100.00% (41/41)   | 85.71% (6/7)    | 100.00% (5/5)   |
| LibHashOptimized.sol   | 100.00% (47/47)   | 100.00% (59/59)   | 100.00% (0/0)   | 100.00% (3/3)   |
| LibInboxSetup.sol      | 100.00% (27/27)   | 100.00% (25/25)   | 100.00% (34/34) | 100.00% (2/2)   |
| LibBonds.sol           | 100.00% (2/2)     | 100.00% (2/2)     | 100.00% (0/0)   | 100.00% (1/1)   |

### Uncovered Branches

1. **Inbox.sol branch (96.55%)**: The 1 uncovered branch is defensive code that is not reachable through normal flow.

2. **LibForcedInclusion.sol branch (85.71%)**: The uncovered branch at L86 checks `_feeDoubleThreshold == 0`, which is a defensive guard that can never be triggered because `LibInboxSetup.validateConfig()` requires `forcedInclusionFeeDoubleThreshold != 0`.

## Summary

| Category               | Total Branches | Covered | Coverage  |
| ---------------------- | -------------- | ------- | --------- |
| Inbox.sol              | 29             | 28      | 96.55%    |
| LibBondInstruction.sol | 3              | 3       | 100%      |
| LibForcedInclusion.sol | 7              | 6       | 85.71%    |
| LibBlobs.sol           | 4              | 4       | 100%      |
| LibInboxSetup.sol      | 34             | 34      | 100%      |
| **Total**              | **77**         | **75**  | **97.4%** |

---

## Detailed Analysis: propose() Function

The `propose()` function (L202-221) orchestrates proposal submission. It calls several internal functions, each with their own branches.

### Flow Diagram

```
propose()
├── onlyWhenActivated modifier (L202)
│   └── BRANCH: _state.nextProposalId != 0
├── _validateProposeInput() (L205)
│   └── BRANCH: deadline == 0 OR timestamp <= deadline
└── _buildProposal() (L211-213)
    ├── BRANCH: block.number > _lastProposalBlockId (L454)
    ├── BRANCH: _getAvailableCapacity() > 0 (L456)
    ├── _consumeForcedInclusions()
    │   ├── BRANCH: _numForcedInclusionsRequested > available (L526-528)
    │   ├── _dequeueAndProcessForcedInclusions()
    │   │   ├── BRANCH: _toProcess > 0 (L562)
    │   │   └── BRANCH: totalFees > 0 (L572)
    │   ├── BRANCH: numRequested < minCount && available > toProcess (L537)
    │   │   └── BRANCH: !isOldestInclusionDue (L541)
    │   └── BRANCH: timestamp > permissionlessTimestamp (L546)
    ├── LibBlobs.validateBlobReference() (L464)
    │   ├── BRANCH: numBlobs > 0 (LibBlobs L53)
    │   └── BRANCH: blobHashes[i] != 0 (LibBlobs L58)
    └── BRANCH: allowsPermissionless ? 0 : checkProposer() (L469-471)
```

### propose() Branch Coverage Table

| #   | Location        | Condition                                       | True Branch                   | False Branch                             | Tests                                                                                                                                   |
| --- | --------------- | ----------------------------------------------- | ----------------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | L202 (modifier) | `_state.nextProposalId != 0`                    | Continue execution            | Revert `ActivationRequired`              | `test_propose_RevertWhen_NotActivated` ✅                                                                                               |
| 2   | L623            | `deadline == 0`                                 | Skip timestamp check          | Check timestamp                          | `test_propose` (deadline=0) ✅                                                                                                          |
| 3   | L623            | `block.timestamp <= deadline`                   | Continue                      | Revert `DeadlineExceeded`                | `test_propose_RevertWhen_DeadlinePassed`, `test_propose_succeedsWhen_DeadlineExact`, `test_propose_RevertWhen_OneSecondPastDeadline` ✅ |
| 4   | L454            | `block.number > _lastProposalBlockId`           | Continue                      | Revert `CannotProposeInCurrentBlock`     | `test_propose_RevertWhen_SameBlock`, `test_propose_succeedsWhen_NextBlock` ✅                                                           |
| 5   | L456            | `_getAvailableCapacity() > 0`                   | Continue                      | Revert `NotEnoughCapacity`               | `test_propose_RevertWhen_CapacityExceeded`, `test_propose_succeedsWhen_CapacityExactlyOne` ✅                                           |
| 6   | L526-528        | `requested > available`                         | `toProcess = available`       | `toProcess = requested`                  | `test_propose_processesForcedInclusion` ✅                                                                                              |
| 7   | L562            | `_toProcess > 0`                                | Process inclusions            | Return max timestamp                     | `test_propose` (no FI), `test_propose_processesForcedInclusion` ✅                                                                      |
| 8   | L572            | `totalFees > 0`                                 | Send ETH to recipient         | Skip ETH transfer                        | `test_propose_processesForcedInclusion` ✅                                                                                              |
| 9   | L537            | `requested < minCount && available > toProcess` | Check if due                  | Skip check                               | `test_propose_RevertWhen_ForcedInclusionDueNotProcessed` ✅                                                                             |
| 10  | L541            | `!isOldestInclusionDue`                         | Continue                      | Revert `UnprocessedForcedInclusionIsDue` | `test_propose_RevertWhen_ForcedInclusionDueNotProcessed` ✅                                                                             |
| 11  | L546            | `timestamp > permissionlessTimestamp`           | `allowsPermissionless = true` | `allowsPermissionless = false`           | `test_propose_allowsPermissionlessWhen_ForcedInclusionTooOld`, `test_propose_notPermissionlessWhen_AtExactPermissionlessTimestamp` ✅   |
| 12  | L469            | `allowsPermissionless`                          | `endOfSubmissionWindow = 0`   | Call `checkProposer()`                   | `test_propose_allowsPermissionlessWhen_ForcedInclusionTooOld`, `test_propose` ✅                                                        |
| 13  | LibBlobs L53    | `numBlobs > 0`                                  | Continue                      | Revert `NoBlobs`                         | `test_propose_RevertWhen_NoBlobsProvided` ✅                                                                                            |
| 14  | LibBlobs L58    | `blobHashes[i] != 0`                            | Continue                      | Revert `BlobNotFound`                    | `test_propose_RevertWhen_BlobNotFound` ✅                                                                                               |

### propose() Boundary Tests

Tests for exact boundary conditions (==) on `<=`, `>=`, `<`, `>` comparisons:

| Condition                             | Boundary Test                                                       | Description                                                     |
| ------------------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------- |
| `block.number > lastProposalBlockId`  | `test_propose_succeedsWhen_NextBlock`                               | Tests block.number == lastProposalBlockId + 1                   |
| `block.number > lastProposalBlockId`  | `test_propose_RevertWhen_SameBlock`                                 | Tests block.number == lastProposalBlockId (fails)               |
| `block.timestamp <= deadline`         | `test_propose_succeedsWhen_DeadlineExact`                           | Tests timestamp == deadline (succeeds)                          |
| `block.timestamp <= deadline`         | `test_propose_RevertWhen_OneSecondPastDeadline`                     | Tests timestamp == deadline + 1 (fails)                         |
| `capacity > 0`                        | `test_propose_succeedsWhen_CapacityExactlyOne`                      | Tests capacity == 1 (succeeds)                                  |
| `capacity > 0`                        | `test_propose_RevertWhen_CapacityExceeded`                          | Tests capacity == 0 (fails)                                     |
| `timestamp > permissionlessTimestamp` | `test_propose_notPermissionlessWhen_AtExactPermissionlessTimestamp` | Tests timestamp == permissionlessTimestamp (not permissionless) |
| `timestamp > permissionlessTimestamp` | `test_propose_allowsPermissionlessWhen_ForcedInclusionTooOld`       | Tests timestamp > permissionlessTimestamp (permissionless)      |

---

## Detailed Analysis: prove() Function

The `prove()` function (L249-339) handles batch proof verification and finalization.

### Flow Diagram

```
prove()
├── onlyWhenActivated modifier (L249)
│   └── BRANCH: _state.nextProposalId != 0
├── Batch Validation
│   ├── BRANCH: numProposals > 0 (L258)
│   ├── BRANCH: firstProposalId <= lastFinalizedProposalId + 1 (L259-261)
│   ├── BRANCH: lastProposalId < nextProposalId (L265)
│   └── BRANCH: lastProposalId >= lastFinalizedId + minProposalsToFinalize (L266-268)
├── Block Hash Continuity
│   ├── BRANCH: offset == 0 (L282-284)
│   │   ├── True: use input.firstProposalParentBlockHash
│   │   └── False: use proposalStates[offset-1].blockHash
│   └── BRANCH: lastFinalizedBlockHash == expectedParentHash (L285)
├── Bond Instruction
│   └── LibBondInstruction.calculateBondInstruction()
│       ├── BRANCH: proposalAge <= provingWindow (L41)
│       ├── BRANCH: proposalAge <= extendedProvingWindow (L45)
│       └── BRANCH: payer == actualProver (L49)
├── BRANCH: bondType != NONE (L304)
│   └── Send signal & emit event
└── BRANCH: timestamp >= lastCheckpoint + minDelay (L312)
    └── Sync checkpoint
```

### prove() Branch Coverage Table

| #   | Location        | Condition                                          | True Branch                        | False Branch                             | Tests                                                                                                                                                                                                                      |
| --- | --------------- | -------------------------------------------------- | ---------------------------------- | ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | L249 (modifier) | `_state.nextProposalId != 0`                       | Continue execution                 | Revert `ActivationRequired`              | `test_prove_RevertWhen_NotActivated` ✅                                                                                                                                                                                    |
| 2   | L258            | `numProposals > 0`                                 | Continue                           | Revert `EmptyBatch`                      | `test_prove_RevertWhen_EmptyBatch` ✅                                                                                                                                                                                      |
| 3   | L259-261        | `firstProposalId <= lastFinalizedId + 1`           | Continue                           | Revert `FirstProposalIdTooLarge`         | `test_prove_RevertWhen_FirstProposalIdTooLarge`, `test_prove_succeedsWhen_FirstProposalIdAtExactBoundary` ✅                                                                                                               |
| 4   | L265            | `lastProposalId < nextProposalId`                  | Continue                           | Revert `LastProposalIdTooLarge`          | `test_prove_RevertWhen_LastProposalIdTooLarge`, `test_prove_RevertWhen_LastProposalIdEqualsNextProposalId`, `test_prove_succeedsWhen_LastProposalIdAtExactBoundary` ✅                                                     |
| 5   | L266-268        | `lastProposalId >= lastFinalizedId + minProposals` | Continue                           | Revert `LastProposalIdTooSmall`          | `test_prove_RevertWhen_LastProposalIdTooSmall`, `test_prove_succeedsWhen_MinProposalsFinalized` ✅                                                                                                                         |
| 6   | L282            | `offset == 0`                                      | Use `firstProposalParentBlockHash` | Use `proposalStates[offset-1].blockHash` | `test_prove_single` (offset=0), `test_prove_acceptsProofWithFinalizedPrefix` (offset>0) ✅                                                                                                                                 |
| 7   | L285            | `lastFinalizedBlockHash == expectedParentHash`     | Continue                           | Revert `ParentBlockHashMismatch`         | `test_prove_RevertWhen_ParentBlockHashMismatch`, `test_prove_RevertWhen_FinalizedPrefixHashMismatch` ✅                                                                                                                    |
| 8   | LibBond L41     | `proposalAge <= provingWindow`                     | Return NONE (on-time)              | Check extended window                    | `test_prove_noBondSignal_withinProvingWindow`, `test_prove_noBondSignal_atExactProvingWindowBoundary`, `test_prove_livenessBond_oneSecondPastProvingWindow` ✅                                                             |
| 9   | LibBond L45     | `proposalAge <= extendedWindow`                    | LIVENESS bond                      | PROVABILITY bond                         | `test_prove_emitsLivenessBond_withinExtendedWindow`, `test_prove_emitsBondSignal_afterProvingWindow`, `test_prove_livenessBond_atExactExtendedWindowBoundary`, `test_prove_provabilityBond_oneSecondPastExtendedWindow` ✅ |
| 10  | LibBond L49     | `payer == actualProver`                            | Return NONE (no transfer)          | Return bond instruction                  | `test_prove_noBondSignal_whenPayerEqualsPayee` ✅                                                                                                                                                                          |
| 11  | L304            | `bondType != NONE`                                 | Send signal & emit                 | Skip signal                              | `test_prove_emitsBondSignal_afterProvingWindow`, `test_prove_noBondSignal_withinProvingWindow` ✅                                                                                                                          |
| 12  | L312            | `timestamp >= lastCheckpoint + minDelay`           | Sync checkpoint                    | Skip checkpoint                          | `test_finalize_checkpointSyncsAfterDelay`, `test_finalize_noCheckpointSync_beforeDelay` ✅                                                                                                                                 |

### prove() Boundary Tests

Tests for exact boundary conditions (==) on `<=`, `>=`, `<` comparisons:

| Condition                                          | Boundary Test                                              | Description                                            |
| -------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------ |
| `firstProposalId <= lastFinalizedId + 1`           | `test_prove_succeedsWhen_FirstProposalIdAtExactBoundary`   | Tests firstProposalId == lastFinalizedId + 1           |
| `lastProposalId < nextProposalId`                  | `test_prove_succeedsWhen_LastProposalIdAtExactBoundary`    | Tests lastProposalId == nextProposalId - 1             |
| `lastProposalId < nextProposalId`                  | `test_prove_RevertWhen_LastProposalIdEqualsNextProposalId` | Tests lastProposalId == nextProposalId (should fail)   |
| `lastProposalId >= lastFinalizedId + minProposals` | `test_prove_succeedsWhen_MinProposalsFinalized`            | Tests lastProposalId == lastFinalizedId + minProposals |
| `proposalAge <= provingWindow`                     | `test_prove_noBondSignal_atExactProvingWindowBoundary`     | Tests proposalAge == provingWindow (no bond)           |
| `proposalAge <= provingWindow`                     | `test_prove_livenessBond_oneSecondPastProvingWindow`       | Tests proposalAge == provingWindow + 1 (LIVENESS)      |
| `proposalAge <= extendedWindow`                    | `test_prove_livenessBond_atExactExtendedWindowBoundary`    | Tests proposalAge == extendedWindow (LIVENESS)         |
| `proposalAge <= extendedWindow`                    | `test_prove_provabilityBond_oneSecondPastExtendedWindow`   | Tests proposalAge == extendedWindow + 1 (PROVABILITY)  |

---

## Modifiers & Access Control

| Line | Condition                                        | Test File             | Test Function                                                                |
| ---- | ------------------------------------------------ | --------------------- | ---------------------------------------------------------------------------- |
| L161 | `_state.nextProposalId != 0` (onlyWhenActivated) | InboxActivation.t.sol | `test_propose_RevertWhen_NotActivated`, `test_prove_RevertWhen_NotActivated` |

---

## saveForcedInclusion() Function

| Line | Condition                    | Test File                  | Test Function                                       |
| ---- | ---------------------------- | -------------------------- | --------------------------------------------------- |
| L347 | `proposalHash != bytes32(0)` | InboxPropose.t.sol         | `test_saveForcedInclusion_RevertWhen_NoProposalYet` |
| L357 | `refund > 0`                 | InboxForcedInclusion.t.sol | `test_saveForcedInclusion_refundsExcessPayment`     |

---

## LibBondInstruction.sol Branches

| Line   | Condition                                          | Test File        | Test Function                                                                                        |
| ------ | -------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------- |
| L41    | `_proposalAge <= _provingWindow` (on-time)         | InboxProve.t.sol | `test_prove_noBondSignal_withinProvingWindow`                                                        |
| L45-46 | `isWithinExtendedWindow` (LIVENESS vs PROVABILITY) | InboxProve.t.sol | `test_prove_emitsLivenessBond_withinExtendedWindow`, `test_prove_emitsBondSignal_afterProvingWindow` |
| L49    | `payer == _actualProver`                           | InboxProve.t.sol | `test_prove_noBondSignal_whenPayerEqualsPayee`                                                       |

---

## LibForcedInclusion.sol Branches

| Line | Condition                          | Test File                                          | Test Function                                                  |
| ---- | ---------------------------------- | -------------------------------------------------- | -------------------------------------------------------------- |
| L54  | `blobSlice.blobHashes.length == 1` | InboxForcedInclusion.t.sol                         | `test_saveForcedInclusion_RevertWhen_MultipleBlobsProvided`    |
| L59  | `msg.value >= requiredFee`         | InboxForcedInclusion.t.sol                         | `test_saveForcedInclusion_RevertWhen_InsufficientFee`          |
| L117 | `_start < head`                    | InboxForcedInclusion.t.sol                         | `test_getForcedInclusions_returnsEmptyWhen_StartBelowHead`     |
| L117 | `_start >= tail`                   | InboxForcedInclusion.t.sol                         | `test_getForcedInclusions_returnsEmptyWhen_StartAtOrAboveTail` |
| L117 | `_maxCount == 0`                   | InboxForcedInclusion.t.sol                         | `test_getForcedInclusions_returnsEmptyWhen_MaxCountZero`       |
| L167 | `_head == _tail` (empty queue)     | Implicitly covered when no forced inclusions exist |

---

## LibBlobs.sol Branches

| Line | Condition                     | Test File                  | Test Function                             |
| ---- | ----------------------------- | -------------------------- | ----------------------------------------- |
| L53  | `_blobReference.numBlobs > 0` | InboxForcedInclusion.t.sol | `test_propose_RevertWhen_NoBlobsProvided` |
| L58  | `blobHashes[i] != 0`          | InboxForcedInclusion.t.sol | `test_propose_RevertWhen_BlobNotFound`    |

---

## LibInboxSetup.sol Branches

### validateConfig() Function

| Condition                                     | Test File             | Test Function                                                              |
| --------------------------------------------- | --------------------- | -------------------------------------------------------------------------- |
| `codec != address(0)`                         | InboxActivation.t.sol | `test_validateConfig_RevertWhen_CodecZero`                                 |
| `proofVerifier != address(0)`                 | InboxActivation.t.sol | `test_validateConfig_RevertWhen_ProofVerifierZero`                         |
| `proposerChecker != address(0)`               | InboxActivation.t.sol | `test_validateConfig_RevertWhen_ProposerCheckerZero`                       |
| `signalService != address(0)`                 | InboxActivation.t.sol | `test_validateConfig_RevertWhen_SignalServiceZero`                         |
| `provingWindow != 0`                          | InboxActivation.t.sol | `test_validateConfig_RevertWhen_ProvingWindowZero`                         |
| `extendedProvingWindow > provingWindow`       | InboxActivation.t.sol | `test_validateConfig_RevertWhen_ExtendedWindowTooSmall`                    |
| `ringBufferSize > 1`                          | InboxActivation.t.sol | `test_validateConfig_RevertWhen_RingBufferSizeTooSmall`                    |
| `basefeeSharingPctg <= 100`                   | InboxActivation.t.sol | `test_validateConfig_RevertWhen_BasefeeSharingPctgTooLarge`                |
| `minForcedInclusionCount != 0`                | InboxActivation.t.sol | `test_validateConfig_RevertWhen_MinForcedInclusionCountZero`               |
| `forcedInclusionFeeInGwei != 0`               | InboxActivation.t.sol | `test_validateConfig_RevertWhen_ForcedInclusionFeeInGweiZero`              |
| `forcedInclusionFeeDoubleThreshold != 0`      | InboxActivation.t.sol | `test_validateConfig_RevertWhen_ForcedInclusionFeeDoubleThresholdZero`     |
| `permissionlessInclusionMultiplier > 1`       | InboxActivation.t.sol | `test_validateConfig_RevertWhen_PermissionlessInclusionMultiplierTooSmall` |
| `minProposalsToFinalize != 0`                 | InboxActivation.t.sol | `test_validateConfig_RevertWhen_MinProposalsToFinalizeTooSmall`            |
| `minProposalsToFinalize < ringBufferSize - 1` | InboxActivation.t.sol | `test_validateConfig_RevertWhen_MinProposalsToFinalizeTooBig`              |

### activate() Function

| Condition                                                     | Test File             | Test Function                                                                                      |
| ------------------------------------------------------------- | --------------------- | -------------------------------------------------------------------------------------------------- |
| `_lastPacayaBlockHash != 0`                                   | InboxActivation.t.sol | `test_activate_RevertWhen_InvalidLastPacayaBlockHash`                                              |
| `block.timestamp <= ACTIVATION_WINDOW + _activationTimestamp` | InboxActivation.t.sol | `test_activate_RevertWhen_ActivationPeriodExpired`, `test_activate_allowsReactivationWithinWindow` |

---

## Test Files Summary

| Test File                  | Test Count | Description                                                             |
| -------------------------- | ---------- | ----------------------------------------------------------------------- |
| InboxActivation.t.sol      | 20         | Activation, pre-activation behavior, config validation, getConfig       |
| InboxPropose.t.sol         | 11         | Proposal submission, deadline, capacity, boundary tests                 |
| InboxProve.t.sol           | 23         | Proof verification, bond instructions, batch validation, boundary tests |
| InboxFinalize.t.sol        | 6          | Finalization, checkpoint syncing                                        |
| InboxCapacity.t.sol        | 3          | Ring buffer capacity tests, boundary tests                              |
| InboxForcedInclusion.t.sol | 9          | Forced inclusion queue, fees, blob validation                           |
| **Total**                  | **72**     |                                                                         |

---

## propose() Overflow/Underflow Analysis

The `propose()` function (L202-221) and its internal functions use `unchecked { }` blocks. All arithmetic operations have been analyzed for safety:

| Line     | Operation                                        | Risk Assessment                                                     |
| -------- | ------------------------------------------------ | ------------------------------------------------------------------- |
| L215     | `nextProposalId + 1`                             | **Safe**: uint48 max is 281 trillion, unreachable in practice       |
| L474     | `block.number - 1`                               | **Safe**: Called after block 0, always valid                        |
| L483     | `(_nextProposalId - 1) % _ringBufferSize`        | **Safe**: `_nextProposalId >= 1` after activation                   |
| L525     | `tail - head` (available)                        | **Safe**: `tail >= head` by design invariant                        |
| L544-545 | `delay * multiplier + oldestTimestamp`           | **Safe**: uint256 prevents overflow with realistic values           |
| L566     | `_head + i`                                      | **Safe**: `i < _toProcess <= available`                             |
| L573     | `totalFees * 1 gwei`                             | **Safe**: `totalFees` is uint64 gwei, max ~18 ETH                   |
| L578     | `_head + uint48(_toProcess)`                     | **Safe**: `_toProcess` is small                                     |
| L615     | `_nextProposalId - _lastFinalizedProposalId - 1` | **Safe**: `_nextProposalId > _lastFinalizedProposalId` by invariant |
| L616     | `_ringBufferSize - 1 - numUnfinalizedProposals`  | **Safe**: L456 check ensures capacity > 0                           |

**Conclusion**: All arithmetic in `propose()` is protected by design invariants and validation checks, making the `unchecked` blocks safe.

---

## prove() Overflow/Underflow Analysis

The `prove()` function is wrapped in `unchecked { }`. All arithmetic operations have been analyzed for safety:

| Line     | Operation                                                                | Risk Assessment                                                                                      |
| -------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| L264     | `lastProposalId = firstProposalId + numProposals - 1`                    | **Safe**: `numProposals > 0` (L258), and L265 catches overflow via `lastProposalId < nextProposalId` |
| L276     | `offset = lastFinalizedProposalId + 1 - firstProposalId`                 | **Safe**: L260 guarantees `firstProposalId <= lastFinalizedProposalId + 1`, so no underflow          |
| L291-292 | `proposalAge = block.timestamp - max(timestamp, lastFinalizedTimestamp)` | **Safe**: `block.timestamp` is always >= any previous timestamp stored                               |
| L296     | `firstProposalId + offset`                                               | **Safe**: Both are uint48, result fits in uint256                                                    |
| L312     | `lastCheckpointTimestamp + minCheckpointDelay`                           | **Safe**: Both are small uint48 values, no practical overflow risk                                   |

**Conclusion**: All arithmetic in `prove()` is protected by preceding validation checks, making the `unchecked` block safe.

---

## Code Quality Improvements Made

1. **Removed unused function**: `_sendBondSignal()` in Inbox.sol was defined but never called. It has been removed.

---

## How to Run Tests

```bash
# Run all inbox tests
FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/core/inbox/*"

# Run with gas snapshots
FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/core/inbox/*" --gas-report

# Run specific test file
FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/core/inbox/InboxActivation.t.sol"
```
