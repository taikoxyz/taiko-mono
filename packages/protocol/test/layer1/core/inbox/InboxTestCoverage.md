# Inbox Branch Coverage Analysis

## Analysis Status

- [x] propose() - analyzed
- [x] prove() - analyzed
- [x] \_finalize() - analyzed
- [x] Tests created for gaps (B3.6, B3.7, B14.3, B19.2)

---

## 1. propose() Function Analysis (lines 215-289)

### Branches:

| Line    | Branch | Condition                                                          | Covered? | Test                                                      |
| ------- | ------ | ------------------------------------------------------------------ | -------- | --------------------------------------------------------- |
| 221     | B1.1   | `input.deadline == 0` (skip check)                                 | YES      | test_propose_firstProposal                                |
| 221     | B1.2   | `input.deadline != 0 && block.timestamp <= input.deadline` (pass)  | YES      | test_propose_withDeadline                                 |
| 221     | B1.3   | `input.deadline != 0 && block.timestamp > input.deadline` (revert) | YES      | test_propose_RevertWhen_DeadlineExceeded                  |
| 226-227 | B2.1   | `block.number > proposalHeadContainerBlock` (pass)                 | YES      | All propose tests                                         |
| 226-227 | B2.2   | `block.number <= proposalHeadContainerBlock` (revert)              | YES      | test_propose_RevertWhen_SameBlock                         |
| 231     | B3     | `_verifyHeadProposal` - see sub-branches below                     | -        | -                                                         |
| 233-235 | B4.1   | `hashCoreState == coreStateHash` (pass)                            | YES      | All successful propose tests                              |
| 233-235 | B4.2   | `hashCoreState != coreStateHash` (revert)                          | YES      | test_propose_RevertWhen_InvalidState                      |
| 242     | B5.1   | `_getAvailableCapacity > 0` (pass)                                 | YES      | All successful propose tests                              |
| 242     | B5.2   | `_getAvailableCapacity == 0` (revert)                              | **NO**   | NotEnoughCapacity hard to trigger                         |
| 257     | B6.1   | `!result.allowsPermissionless` (check proposer)                    | YES      | Most propose tests                                        |
| 257     | B6.2   | `result.allowsPermissionless` (skip proposer check)                | YES      | test_propose_becomesPermissionless_whenForcedInclusionOld |

### \_verifyHeadProposal Sub-branches (lines 651-679):

| Line | Branch | Condition                                                                        | Covered? | Test                                             |
| ---- | ------ | -------------------------------------------------------------------------------- | -------- | ------------------------------------------------ |
| 657  | B3.1   | `length == 0` (revert EmptyProposals)                                            | YES      | test_propose_RevertWhen_EmptyProposals           |
| 661  | B3.2   | `proposalHash != storedHash` (revert ProposalHashMismatch)                       | YES      | test_propose_RevertWhen_ProposalHashMismatch     |
| 666  | B3.3   | `nextSlotHash == 0 && length == 1` (pass)                                        | YES      | All normal propose tests                         |
| 668  | B3.4   | `nextSlotHash == 0 && length > 1` (revert TooManyProofProposals)                 | YES      | test_propose_RevertWhen_TooManyProofProposals    |
| 669  | B3.5   | `nextSlotHash != 0 && length != 2` (revert MissingProofProposal)                 | YES      | test_propose_RevertWhen_MissingProofProposal     |
| 675  | B3.6   | `nextSlotHash != 0 && headId <= proofId` (revert InvalidLastProposalProof)       | YES      | test_propose_RevertWhen_InvalidLastProposalProof |
| 676  | B3.7   | `nextSlotHash != 0 && proofHash != storedHash` (revert NextProposalHashMismatch) | YES      | test_propose_RevertWhen_NextProposalHashMismatch |

### \_consumeForcedInclusions Sub-branches (lines 702-744):

| Line | Branch | Condition                                                         | Covered? | Test                                                       |
| ---- | ------ | ----------------------------------------------------------------- | -------- | ---------------------------------------------------------- |
| 732  | B7.1   | `requested < min && available > toProcess && isDue` (revert)      | YES      | test_propose_RevertWhen_ForcedInclusionDue_andNotProcessed |
| 732  | B7.2   | `requested >= min` (skip check)                                   | YES      | test_propose_consumesForcedInclusions                      |
| 742  | B7.3   | `block.timestamp > permissionlessTimestamp` (permissionless)      | YES      | test_propose_becomesPermissionless_whenForcedInclusionOld  |
| 742  | B7.4   | `block.timestamp <= permissionlessTimestamp` (not permissionless) | YES      | Most propose tests                                         |

### \_dequeueAndProcessForcedInclusions Sub-branches (lines 756-798):

| Line | Branch | Condition                            | Covered? | Test                                      |
| ---- | ------ | ------------------------------------ | -------- | ----------------------------------------- |
| 767  | B8.1   | `toProcess > 0` (process inclusions) | YES      | test_propose_consumesForcedInclusions     |
| 779  | B8.2   | `totalFees > 0` (transfer fees)      | YES      | test_propose_transfersForcedInclusionFees |
| 779  | B8.3   | `totalFees == 0` (no transfer)       | **NO**   | Need test with zero-fee inclusions        |
| 792  | B8.4   | `toProcess == 0` (no processing)     | YES      | test_propose_firstProposal                |

---

## 2. prove() Function Analysis (lines 292-332)

### Branches:

| Line    | Branch | Condition                                   | Covered? | Test                                              |
| ------- | ------ | ------------------------------------------- | -------- | ------------------------------------------------- |
| 295     | B9.1   | `inputs.length == 0` (revert)               | YES      | test_prove_RevertWhen_EmptyInputs                 |
| 295     | B9.2   | `inputs.length > 0` (continue)              | YES      | All successful prove tests                        |
| 299     | B10.1  | `proposalHash != storedHash` (revert)       | YES      | test_prove_RevertWhen_ProposalNotFound            |
| 304-306 | B11.1  | `bondInstructions.length == 0` (hash = 0)   | YES      | test_prove_noBondInstructions_withinProvingWindow |
| 304-306 | B11.2  | `bondInstructions.length > 0` (hash = hash) | YES      | test_prove_nonEmptyBondInstructions_livenessBond  |
| 326     | B12.1  | `inputs.length == 1` (calculate age)        | YES      | test_prove_singleProposal                         |
| 326     | B12.2  | `inputs.length > 1` (age = 0)               | YES      | test_prove_twoConsecutiveProposals                |

### \_calculateBondInstructions Sub-branches (lines 923-951):

| Line    | Branch | Condition                                                      | Covered? | Test                                                           |
| ------- | ------ | -------------------------------------------------------------- | -------- | -------------------------------------------------------------- |
| 929     | B13.1  | `timestamp <= windowEnd` (on-time, no bonds)                   | YES      | test_prove_noBondInstructions_withinProvingWindow              |
| 932-936 | B13.2  | `withinExtended && actualProver != designated` (liveness bond) | YES      | test_prove_livenessBond_afterProvingWindow_differentProver     |
| 932-936 | B13.3  | `withinExtended && actualProver == designated` (no bond)       | YES      | test_prove_noBond_afterProvingWindow_sameDesignatedProver      |
| 932-936 | B13.4  | `afterExtended && actualProver != proposer` (provability bond) | YES      | test_prove_provabilityBond_afterExtendedWindow_differentProver |
| 932-936 | B13.5  | `afterExtended && actualProver == proposer` (no bond)          | YES      | test_prove_noBondInstruction_sameProver                        |

### \_storeTransitionRecord Sub-branches (lines 961-984):

| Line    | Branch | Condition                                               | Covered? | Test                                                         |
| ------- | ------ | ------------------------------------------------------- | -------- | ------------------------------------------------------------ |
| 971     | B14.1  | `firstRecord.proposalId != proposalId` (new, overwrite) | YES      | test_prove_storesTransitionInRingBuffer                      |
| 976     | B14.2  | `proposalId == && parentHash ==` (same, update)         | YES      | test_prove_updatesExistingTransition_sameHash                |
| 978-982 | B14.3  | `proposalId == && parentHash !=` (fallback mapping)     | YES      | test_prove_differentParentTransitionHash_usesFallbackMapping |

### \_updateTransitionRecord Sub-branches (lines 993-1011):

| Line | Branch | Condition                                   | Covered? | Test                                          |
| ---- | ------ | ------------------------------------------- | -------- | --------------------------------------------- |
| 1001 | B15.1  | `existingHash != newHash` (conflict)        | YES      | test_prove_conflictingTransition_emitsEvent   |
| 1007 | B15.2  | `existingHash == newHash` (update deadline) | YES      | test_prove_updatesExistingTransition_sameHash |

---

## 3. \_finalize() Function Analysis (lines 810-877)

### Branches:

| Line    | Branch | Condition                                                    | Covered? | Test                                                                 |
| ------- | ------ | ------------------------------------------------------------ | -------- | -------------------------------------------------------------------- |
| 820     | B16.1  | `proposalId > proposalHead` (break, no more)                 | YES      | test_finalize_stopsWhenProposalNotProven                             |
| 826     | B16.2  | `record.transitionHash == 0` (break, not proven)             | YES      | test_finalize_stopsWhenProposalNotProven                             |
| 827     | B16.3  | `record.finalizationDeadline == max` (break, conflicted)     | YES      | test_finalize_breaksAtConflictingTransition_duringFinalization       |
| 829-831 | B16.4  | `i >= transitionCount && timestamp < deadline` (break, wait) | YES      | test_finalize_incrementalFinalization                                |
| 830     | B16.5  | `i >= transitionCount && timestamp >= deadline` (revert)     | YES      | test_finalize_RevertWhen_TransitionNotProvided_afterGracePeriod      |
| 834-836 | B16.6  | `hashTransition != stored` (revert)                          | YES      | test_finalize_RevertWhen_TransitionHashMismatch                      |
| 843     | B17.1  | `bondInstructionHash != 0` (aggregate)                       | YES      | test_finalize_aggregatesBondInstructionHash                          |
| 843     | B17.2  | `bondInstructionHash == 0` (skip)                            | YES      | test_finalize_singleProposal                                         |
| 855     | B18.1  | `finalizedCount != transitionCount` (revert)                 | YES      | test_finalize_RevertWhen_IncorrectTransitionCount                    |
| 858     | B18.2  | `finalizedCount == 0 && checkpoint != zero` (revert)         | YES      | test_finalize_RevertWhen_InvalidCheckpoint_nonZeroWhenNoFinalization |
| 858     | B18.3  | `finalizedCount == 0 && checkpoint == zero` (pass)           | YES      | test_propose_firstProposal                                           |
| 867-869 | B18.4  | `checkpointHash != transitionCheckpointHash` (revert)        | YES      | test_finalize_RevertWhen_CheckpointMismatch                          |
| 872     | B19.1  | `finalizationHead > syncHead + minSyncDelay` (sync)          | YES      | test_finalize_savesCheckpoint_afterMinSyncDelay                      |
| 872     | B19.2  | `finalizationHead <= syncHead + minSyncDelay` (skip sync)    | YES      | test_finalize_skipsSync_whenBelowMinSyncDelay                        |

### \_syncToLayer2 Sub-branches (lines 887-907):

| Line | Branch | Condition                                         | Covered? | Test                                            |
| ---- | ------ | ------------------------------------------------- | -------- | ----------------------------------------------- |
| 896  | B20.1  | `aggregatedBondInstructionsHash != 0` (signal)    | **NO**   | Need bond signal test                           |
| 896  | B20.2  | `aggregatedBondInstructionsHash == 0` (no signal) | YES      | test_finalize_savesCheckpoint_afterMinSyncDelay |

---

## Summary of Uncovered Branches

### High Priority (Error paths):

1. **B5.2** - NotEnoughCapacity (hard to trigger, MissingProofProposal fires first)
2. ~~**B3.6** - InvalidLastProposalProof (ring buffer wrap scenario)~~ - COVERED
3. ~~**B3.7** - NextProposalHashMismatch (ring buffer wrap scenario)~~ - COVERED

### Medium Priority (Bond-related):

4. ~~**B11.2** - prove() with non-empty bond instructions~~ - COVERED (after bug fix)
5. ~~**B13.2** - Liveness bond (within extended window, different prover)~~ - COVERED (after bug fix)
6. ~~**B13.3** - Within extended window, same designated prover~~ - COVERED (after bug fix)
7. ~~**B13.4** - Provability bond (after extended window, different prover)~~ - COVERED (after bug fix)
8. ~~**B17.1** - Bond instruction aggregation in finalize~~ - COVERED
9. **B20.1** - Signal service called with bond instructions (user said not required to test)

### Lower Priority:

10. **B8.3** - Zero-fee forced inclusions
11. ~~**B14.3** - Different parent transition hash (fallback mapping)~~ - COVERED
12. ~~**B19.2** - Sync rate limiting (skip sync when too soon)~~ - COVERED

---

## Tests to Create (Remaining)

1. ~~**Inbox_Prove.t.sol**: Bond instruction generation tests (B11.2, B13.2, B13.3, B13.4)~~ - DONE (after bug fix)
2. ~~**Inbox_Prove.t.sol**: Different parent transition hash test (B14.3)~~ - DONE
3. ~~**Inbox_Finalize.t.sol**: Bond aggregation test (B17.1)~~ - DONE
4. ~~**Inbox_Finalize.t.sol**: Sync rate limiting test (B19.2)~~ - DONE
5. ~~**Inbox_RingBuffer.t.sol**: Ring buffer wrap tests (B3.6, B3.7)~~ - DONE

## Tests Created

1. **Inbox_Prove.t.sol**:
   - `test_prove_differentParentTransitionHash_usesFallbackMapping` - B14.3
   - `test_prove_conflictingTransition_fallbackMapping` - B14.3 conflict path
   - `test_prove_nonEmptyBondInstructions_livenessBond` - B11.2
   - `test_prove_livenessBond_afterProvingWindow_differentProver` - B13.2
   - `test_prove_noBond_afterProvingWindow_sameDesignatedProver` - B13.3
   - `test_prove_provabilityBond_afterExtendedWindow_differentProver` - B13.4

2. **Inbox_Finalize.t.sol**:
   - `test_finalize_skipsSync_whenBelowMinSyncDelay` - B19.2
   - `test_finalize_aggregatesBondInstructionHash` - B17.1

3. **Inbox_RingBuffer.t.sol**:
   - `test_propose_RevertWhen_InvalidLastProposalProof` - B3.6
   - `test_propose_RevertWhen_NextProposalHashMismatch` - B3.7
   - `test_propose_wrapAround_withCorrectProof` - Success case for wrap-around

4. **Inbox_Finalize.t.sol** (additional):
   - `test_finalize_breaksAtConflictingTransition_duringFinalization` - B16.3 (actually triggers the break)

## Bug Fixes Applied

1. **Inbox.sol line 931** (was line 929): Fixed `_calculateBondInstructions` window calculation
   - **Before**: `uint256 windowEnd = block.timestamp + _provingWindow;`
   - **After**: `uint256 windowEnd = _input.proposal.timestamp + _provingWindow;`
   - This bug caused bond instructions to never be generated because `block.timestamp <= block.timestamp + X` is always true.

## Test Infrastructure Improvements

1. **InboxTestHelper.sol**: Added `_hasCheckpointSavedEvent()` helper for consistent event checking
2. **Inbox_Finalize.t.sol**: Refactored `test_finalize_skipsSync_whenBelowMinSyncDelay` to use the new helper

## Dead Code Analysis

1. **NotEnoughCapacity error**: Analyzed and confirmed as unreachable code. The `MissingProofProposal` error always fires first in wrap-around scenarios (the only way to reach 0 capacity).
