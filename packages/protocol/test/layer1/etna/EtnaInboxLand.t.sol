// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "./EtnaInboxTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { VmSafe } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @notice A SignalService stand-in that records, while `land` saves its checkpoint, whether the
/// Inbox holds its reentrancy lock and what a re-entry into the Inbox returns.
contract LockProbeSignalService {
    bytes public reentryCall;
    uint256 public saves;
    bool public lockHeld;
    bool public reentrySucceeded;
    bytes public reentryError;

    function setReentryCall(bytes calldata _call) external {
        reentryCall = _call;
    }

    function saveCheckpoint(ICheckpointStore.Checkpoint calldata) external {
        ++saves;
        lockHeld = EssentialContract(msg.sender).inNonReentrant();
        (reentrySucceeded, reentryError) = msg.sender.call(reentryCall);
    }
}

contract EtnaInboxLandTest is EtnaLandTestBase {
    /// @dev The EIP-2935 history storage contract and its runtime code.
    address internal constant HISTORY_STORAGE = 0x0000F90827F1C53a10cb7A02335B175320002935;
    bytes internal constant HISTORY_STORAGE_CODE = hex"3373fffffffffffffffffffffffffffffffffffffffe"
        hex"14604657602036036042575f35600143038111"
        hex"604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500";

    /// @dev The L1 block of the reference block tests.
    uint256 internal constant L1_HEAD = 20_000;

    /// @dev 2^48, the first height a landing record cannot hold.
    uint256 private constant _TWO_POW_48 = 2 ** 48;

    // ---------------------------------------------------------------
    // Landing and its writes
    // ---------------------------------------------------------------

    /// @dev (0, 6] carries no leaf, so its cutHash is over keccak256(""); every spec 6.1 step 7
    /// write lands and `landings(0)` is untouched.
    function test_land_LandsFirstGridSegment() external {
        IEtnaInbox.LandInput memory input = _input(0, 6);
        bytes32[] memory none = new bytes32[](0);
        bytes32 cutHash = _cutHash(input, none);
        assertEq(
            cutHash,
            keccak256(
                abi.encode(
                    bytes32("ETNA_LAND_CUTS_V1"), uint256(0), uint256(0), uint256(6), keccak256("")
                )
            ),
            "cut hash over the empty list"
        );
        // The `g0_p0_h6` vector.
        assertEq(
            cutHash,
            0xcf8e3c664c50dae3ca433e951161604725515156d44722b20b12c56e002d3715,
            "cut hash vector"
        );
        assertEq(_inbox().l2ChainId(), L2_CHAIN_ID, "statement L2 chain id");
        assertEq(_inbox().stakingRegistry(), address(registry), "statement registry");

        // `_land` expects `Landed(0, 0, 6, cutHash, 4, 1)` and one verifier call.
        _land(input, none);

        _assertCheckpoint(6, bytes32(uint256(106)));
        _assertLanding(6, _record(0, 0, 1, 6));
        _assertLanding(0, _record(0, 0, 0, 0));
        assertEq(_inbox().activeCommitteeSnapshot(), LEAN_SNAPSHOT, "snapshot");
        assertEq(uint256(_inboxWord(ACTIVE_COMMITTEE_SNAPSHOT_SLOT)), LEAN_SNAPSHOT, "slot 284");
        _assertQueue(1, LEAN_FORCED_INCLUSIONS);
        assertEq(_inboxWord(RECOVERY_GENERATION_SLOT), 0, "generation");
        ICheckpointStore.Checkpoint memory saved = signalService.getCheckpoint(6);
        assertEq(saved.blockNumber, 6, "signal height");
        assertEq(saved.blockHash, bytes32(uint256(106)), "signal block hash");
        assertEq(saved.stateRoot, bytes32(uint256(306)), "signal state root");
    }

    /// @dev Proving (0, 12] after (0, 6] landed: parentHash, parentCometHash and headBefore come
    /// from `landings(0)`, not from the checkpoint at 6; the new record's parent is the actual c.
    function test_land_StatementBindsOriginNotCheckpoint() external {
        _land(0, 6);
        IEtnaInbox.LandInput memory input = _input(0, 12);
        bytes32[] memory leaves = _leaves(0, 12);
        assertEq(leaves.length, 1, "one grid point inside (0, 12)");
        assertEq(leaves[0], _leaf(6), "the leaf at 6");

        bytes32 cutHash = _cutHash(input, leaves);
        bytes32 fromOrigin = _statement(input, _inbox().landings(0), cutHash);
        bytes32 fromCheckpoint = _statement(input, _inbox().landings(6), cutHash);
        assertNotEq(fromOrigin, fromCheckpoint, "origin and checkpoint differ");
        landVerifier.setExpectedStatementHash(fromOrigin);

        assertEq(_land(input, leaves), fromOrigin, "statement over landings(0)");
        _assertLanding(12, _record(6, 0, 2, 12));
        _assertCheckpoint(12, bytes32(uint256(112)));
        _assertQueue(2, LEAN_FORCED_INCLUSIONS);
        _assertLanding(6, _record(0, 0, 1, 6));
    }

    function test_land_PassesProposalAgeZero() external {
        vm.expectCall(
            address(landVerifier), abi.encodePacked(IProofVerifier.verifyProof.selector, uint256(0))
        );
        _land(0, 6);
    }

    /// @dev Spec 6.1 step 7 stores the snapshot as proven, with no bound against the stored one
    /// or the reference block (design C4).
    function test_land_StoresTheProvenSnapshotWithoutBounds() external {
        bytes32[] memory none = new bytes32[](0);
        IEtnaInbox.LandInput memory input = _input(0, 6);
        input.activeCommitteeSnapshot = 0;
        _land(input, none);
        assertEq(_inbox().activeCommitteeSnapshot(), 0, "below the stored snapshot");

        input = _input(6, 12);
        input.activeCommitteeSnapshot = type(uint256).max;
        _land(input, none);
        assertEq(
            uint256(_inboxWord(ACTIVE_COMMITTEE_SNAPSHOT_SLOT)),
            type(uint256).max,
            "beyond the reference block"
        );
    }

    /// @dev Lean `protocol_fee_is_preserved_by_landing`: with four entries saved, landing (0, 6]
    /// consumes one and moves no ETH.
    function test_land_DoesNotMoveFees() external {
        uint256 fees = inboxProxy.balance;
        fees += _saveForcedInclusions(1);
        _assertQueue(0, 4);
        assertEq(inboxProxy.balance, fees, "the Inbox holds every fee");
        uint256 landerBefore = Bob.balance;
        uint256 treasuryBefore = PROTOCOL_FEE_RECIPIENT.balance;

        _land(0, 6);

        _assertQueue(1, 4);
        assertEq(inboxProxy.balance, fees, "fees stay in the Inbox");
        assertEq(Bob.balance, landerBefore, "nothing to the lander");
        assertEq(PROTOCOL_FEE_RECIPIENT.balance, treasuryBefore, "nothing to the treasury");
        assertEq(
            _inbox().getForcedInclusion(0).txHash,
            keccak256(abi.encodePacked("forced", uint256(0))),
            "the consumed entry is kept"
        );
    }

    // ---------------------------------------------------------------
    // Step 1: range and grid
    // ---------------------------------------------------------------

    function test_land_RevertWhen_AlreadySettled() external {
        bytes32[] memory none = new bytes32[](0);
        _land(0, 12);

        _expectLandRevert(_input(0, 12), _leaves(0, 12), IEtnaInbox.AlreadySettled.selector);
        _expectLandRevert(_input(0, 6), none, IEtnaInbox.AlreadySettled.selector);
        _expectLandRevert(_input(6, 12), none, IEtnaInbox.AlreadySettled.selector);
        // A settled target is reported as such even from an origin above it.
        _expectLandRevert(_input(18, 12), none, IEtnaInbox.AlreadySettled.selector);
        _assertCheckpoint(12, bytes32(uint256(112)));
    }

    function test_land_RevertWhen_ParentOutsideGenerationStartAndCheckpoint() external {
        bytes32[] memory none = new bytes32[](0);
        _land(0, 6);
        // p above c.
        _expectLandRevert(_input(12, 18), none, IEtnaInbox.InvalidRange.selector);

        // Generation 1 starts at c = 6, as a recovery there would leave it.
        _plantGeneration(1, 6);
        assertEq(_inbox().generationStartHeight(), 6, "start height");
        _expectLandRevert(_input(0, 12), _leaves(0, 12), IEtnaInbox.InvalidRange.selector);

        // The start height is a valid origin; the statement and record carry generation 1.
        _land(6, 12);
        _assertLanding(12, _record(6, 1, 2, 12));
        _expectLandRevert(_input(0, 18), _leaves(0, 18), IEtnaInbox.InvalidRange.selector);
    }

    /// @dev `h < 2^48` is part of the range check: 2^48 + 2, the first grid point at or above
    /// 2^48, is rejected even with an unbounded batch size, and from a checkpoint just below the
    /// limit only 2^48 - 4 lands.
    function test_land_RevertWhen_HeightReaches2Pow48() external {
        bytes32[] memory none = new bytes32[](0);
        uint256 h = _TWO_POW_48 + 2;
        assertEq(h % K, 0, "2^48 + 2 is a grid point");
        _upgradeWithMaxBatchBlocks(type(uint64).max);
        _expectLandRevert(_input(0, h), none, IEtnaInbox.InvalidRange.selector);
        // The range check runs before the grid check.
        _expectLandRevert(_input(0, _TWO_POW_48), none, IEtnaInbox.InvalidRange.selector);

        uint256 p = _TWO_POW_48 - 10;
        assertEq(p % K, 0, "2^48 - 10 is a grid point");
        IEtnaInbox.Landing memory near = IEtnaInbox.Landing({
            parentHeight: 0,
            generation: 0,
            head: 0,
            elHash: keccak256("el near 2^48"),
            cometHash: keccak256("comet near 2^48")
        });
        _plantLanding(p, near);
        _storeInboxWord(LAST_CHECKPOINT_HEIGHT_SLOT, bytes32(p));
        _storeInboxWord(LAST_CHECKPOINT_HASH_SLOT, near.elHash);

        _expectLandRevert(_input(p, h), new bytes32[](1), IEtnaInbox.InvalidRange.selector);
        _assertCheckpoint(p, near.elHash);

        IEtnaInbox.LandInput memory input = _input(p, _TWO_POW_48 - 4);
        input.forcedInclusionHead = 0;
        _land(input, none);
        _assertCheckpoint(_TWO_POW_48 - 4, input.lastBlockHash);
        _assertLanding(
            _TWO_POW_48 - 4,
            IEtnaInbox.Landing({
                parentHeight: uint48(p),
                generation: 0,
                head: 0,
                elHash: input.lastBlockHash,
                cometHash: input.lastCometHash
            })
        );
        assertEq(
            signalService.getCheckpoint(uint48(_TWO_POW_48 - 4)).stateRoot,
            input.lastStateRoot,
            "signal checkpoint"
        );
    }

    function test_land_RevertWhen_OffGrid() external {
        bytes32[] memory none = new bytes32[](0);
        _expectLandRevert(_input(0, 13), new bytes32[](1), IEtnaInbox.OffGrid.selector);
        _land(0, 12);
        _expectLandRevert(_input(7, 18), none, IEtnaInbox.OffGrid.selector);
        _expectLandRevert(_input(6, 13), none, IEtnaInbox.OffGrid.selector);
        _expectLandRevert(_input(12, 15), none, IEtnaInbox.OffGrid.selector);
    }

    /// @dev `h - p <= maxBatchBlocks`, inclusive: with the minimum of one segment (0, 6] lands and
    /// (0, 12] does not; with 1000, 996 lands and 1002 does not.
    function test_land_RevertWhen_BatchTooLarge() external {
        assertEq(MAX_BATCH_BLOCKS, 1000, "maxBatchBlocks");
        _expectLandRevert(_input(0, 1002), _leaves(0, 1002), IEtnaInbox.BatchTooLarge.selector);

        _upgradeWithMaxBatchBlocks(6);
        _expectLandRevert(_input(0, 12), _leaves(0, 12), IEtnaInbox.BatchTooLarge.selector);
        _land(0, 6);
        // The bound is on the proven range (p, h], not on the settled suffix (c, h].
        _expectLandRevert(_input(0, 12), _leaves(0, 12), IEtnaInbox.BatchTooLarge.selector);
        _land(6, 12);

        _upgradeWithMaxBatchBlocks(MAX_BATCH_BLOCKS);
        IEtnaInbox.LandInput memory input = _input(0, 996);
        input.forcedInclusionHead = LEAN_FORCED_INCLUSIONS;
        bytes32[] memory leaves = _leaves(0, 996);
        assertEq(leaves.length, 165, "165 leaves");
        _land(input, leaves);
        _assertCheckpoint(996, bytes32(uint256(1096)));
    }

    // ---------------------------------------------------------------
    // Step 2: origin record
    // ---------------------------------------------------------------

    function test_land_RevertWhen_OriginMissing() external {
        _land(0, 12);
        assertEq(_inbox().landings(6).elHash, 0, "no record at 6");
        _expectLandRevert(_input(6, 18), _leaves(6, 18), IEtnaInbox.MissingOrigin.selector);
    }

    /// @dev Unreachable through `land` and `recover`: records above a generation's start height
    /// are all its own. The state is planted: generation 1 starting at 6 while c = 12 holds a
    /// generation-0 record. Only the start height itself is exempt.
    function test_land_RevertWhen_ForeignGeneration() external {
        _land(0, 6);
        _land(6, 12);
        _plantGeneration(1, 6);

        _expectLandRevert(_input(12, 18), new bytes32[](0), IEtnaInbox.ForeignGeneration.selector);

        _land(6, 18);
        _assertLanding(18, _record(12, 1, 3, 18));
    }

    // ---------------------------------------------------------------
    // Step 3: leaves
    // ---------------------------------------------------------------

    function test_land_RevertWhen_LeafCountWrong() external {
        _expectLandRevert(_input(0, 12), new bytes32[](0), IEtnaInbox.LeafCountMismatch.selector);
        _expectLandRevert(_input(0, 12), new bytes32[](2), IEtnaInbox.LeafCountMismatch.selector);
        _expectLandRevert(_input(0, 6), new bytes32[](1), IEtnaInbox.LeafCountMismatch.selector);
        _expectLandRevert(_input(0, 18), _leaves(0, 12), IEtnaInbox.LeafCountMismatch.selector);
    }

    /// @dev Unreachable through `land` and `recover`: c's recorded head always equals the queue
    /// head. The queue head is planted on either side of it.
    function test_land_RevertWhen_ForcedInclusionHeadMismatch() external {
        bytes32[] memory none = new bytes32[](0);
        _land(0, 6);
        _plantQueue(0, LEAN_FORCED_INCLUSIONS);
        _expectLandRevert(_input(6, 12), none, IEtnaInbox.ForcedInclusionHeadMismatch.selector);
        _plantQueue(2, LEAN_FORCED_INCLUSIONS);
        _expectLandRevert(_input(6, 12), none, IEtnaInbox.ForcedInclusionHeadMismatch.selector);
    }

    /// @dev The leaf at c must match c's record in all four words; it is checked while the
    /// verifier rejects everything, so the leaf check runs before the proof.
    function test_land_RevertWhen_FrontierLeafDiffers() external {
        _land(0, 6);
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _input(0, 12);
        (bytes32 el, bytes32 comet, uint256 head) = _cut(6);
        bytes32 wrong = bytes32(uint256(999));
        bytes32[] memory leaves = new bytes32[](1);

        leaves[0] = _leafOf(6, el, wrong, head);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);
        leaves[0] = _leafOf(6, wrong, comet, head);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);
        leaves[0] = _leafOf(7, el, comet, head);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);
        leaves[0] = _leafOf(6, el, comet, head + 1);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);

        // With the honest leaf only the proof fails.
        leaves[0] = _leaf(6);
        _expectLandRevert(input, leaves, MockLandProofVerifier.ProofRejected.selector);
    }

    /// @dev Only the leaf at c is checked; the other leaves only feed cutHash.
    function test_land_ChecksOnlyTheLeafAtTheCheckpoint() external {
        bytes32 garbage = keccak256("not a cut leaf");
        uint256 fresh = vm.snapshotState();

        _land(0, 6);
        bytes32[] memory leaves = _leaves(0, 18);
        leaves[1] = garbage;
        _land(_input(0, 18), leaves);
        _assertCheckpoint(18, bytes32(uint256(118)));

        vm.revertToState(fresh);
        _land(0, 12);
        leaves = _leaves(0, 18);
        leaves[0] = garbage;
        _land(_input(0, 18), leaves);
        _assertCheckpoint(18, bytes32(uint256(118)));

        vm.revertToState(fresh);
        _land(0, 12);
        leaves = _leaves(0, 18);
        leaves[1] = garbage;
        _expectLandRevert(_input(0, 18), leaves, IEtnaInbox.FrontierLeafMismatch.selector);
    }

    // ---------------------------------------------------------------
    // Step 4: forced inclusion head
    // ---------------------------------------------------------------

    function test_land_RevertWhen_ForcedInclusionHeadOutOfBounds() external {
        bytes32[] memory none = new bytes32[](0);
        _land(0, 6);
        IEtnaInbox.LandInput memory input = _input(6, 12);

        input.forcedInclusionHead = 0;
        _expectLandRevert(input, none, IEtnaInbox.InvalidForcedInclusionHead.selector);
        input.forcedInclusionHead = LEAN_FORCED_INCLUSIONS + 1;
        _expectLandRevert(input, none, IEtnaInbox.InvalidForcedInclusionHead.selector);

        // Both ends are inclusive: no advance, and an advance to the tail.
        uint256 beforeLanding = vm.snapshotState();
        input.forcedInclusionHead = 1;
        _land(input, none);
        _assertQueue(1, LEAN_FORCED_INCLUSIONS);
        vm.revertToState(beforeLanding);
        input.forcedInclusionHead = LEAN_FORCED_INCLUSIONS;
        _land(input, none);
        _assertQueue(LEAN_FORCED_INCLUSIONS, LEAN_FORCED_INCLUSIONS);
        vm.revertToState(beforeLanding);

        // An advance beyond h - c = 6 with enough entries queued.
        _saveForcedInclusions(5);
        input.forcedInclusionHead = 8;
        _expectLandRevert(input, none, IEtnaInbox.InvalidForcedInclusionHead.selector);
        input.forcedInclusionHead = 7;
        _land(input, none);
        _assertQueue(7, 8);
    }

    /// @dev c = 6 with head 0, h = 12 and tail 10, proved from p = 0: the advance is bounded by
    /// h - c = 6, not h - p = 12.
    function test_land_HeadAdvanceIsBoundedByHMinusC() external {
        bytes32[] memory none = new bytes32[](0);
        _saveForcedInclusions(7);
        IEtnaInbox.LandInput memory first = _input(0, 6);
        first.forcedInclusionHead = 0;
        _land(first, none);
        _assertQueue(0, 10);

        IEtnaInbox.LandInput memory input = _input(0, 12);
        (bytes32 el, bytes32 comet,) = _cut(6);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _leafOf(6, el, comet, 0);

        input.forcedInclusionHead = 7;
        _expectLandRevert(input, leaves, IEtnaInbox.InvalidForcedInclusionHead.selector);
        input.forcedInclusionHead = 6;
        _land(input, leaves);
        _assertQueue(6, 10);
        _assertLanding(12, _record(6, 0, 6, 12));
    }

    // ---------------------------------------------------------------
    // Step 5: reference block and blobs
    // ---------------------------------------------------------------

    function test_land_ReadsTheReferenceFromBlockhash() external {
        vm.roll(L1_HEAD);
        _setReference(L1_HEAD - 256, keccak256("oldest blockhash"));
        _plantHistory(L1_HEAD - 256, keccak256("history"));
        _land(0, 6);
    }

    function test_land_ReadsTheReferenceFromTheHistoryContract() external {
        vm.roll(L1_HEAD);
        _setReference(L1_HEAD - 257, keccak256("history 257"));
        _plantHistory(L1_HEAD - 257, keccak256("history 257"));
        _land(0, 6);

        _setReference(L1_HEAD - 8191, keccak256("history 8191"));
        _plantHistory(L1_HEAD - 8191, keccak256("history 8191"));
        _land(6, 12);
    }

    function test_historyContract_ServesTheLast8191Blocks() external {
        vm.roll(L1_HEAD);
        _plantHistory(L1_HEAD - 1, keccak256("newest"));
        _plantHistory(L1_HEAD - 8191, keccak256("oldest"));

        (bool success, bytes memory data) = HISTORY_STORAGE.staticcall(abi.encode(L1_HEAD - 1));
        assertTrue(success, "newest served");
        assertEq(abi.decode(data, (bytes32)), keccak256("newest"), "newest hash");

        (success, data) = HISTORY_STORAGE.staticcall(abi.encode(L1_HEAD - 8191));
        assertTrue(success, "oldest served");
        assertEq(abi.decode(data, (bytes32)), keccak256("oldest"), "oldest hash");

        (success,) = HISTORY_STORAGE.staticcall(abi.encode(L1_HEAD));
        assertFalse(success, "current block");
        (success,) = HISTORY_STORAGE.staticcall(abi.encode(L1_HEAD - 8192));
        assertFalse(success, "beyond the window");
        (success,) = HISTORY_STORAGE.staticcall(abi.encodePacked(uint248(L1_HEAD - 1)));
        assertFalse(success, "short calldata");
    }

    function test_land_RevertWhen_ReferenceTooOld() external {
        vm.roll(L1_HEAD);
        _setReference(L1_HEAD - 8192, keccak256("too old"));
        _plantHistory(L1_HEAD - 8192, keccak256("too old"));
        _expectLandRevert(
            _input(0, 6), new bytes32[](0), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_ReferenceNotInThePast() external {
        _setReference(block.number, keccak256("current"));
        _expectLandRevert(
            _input(0, 6), new bytes32[](0), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
        _setReference(block.number + 1, keccak256("future"));
        _expectLandRevert(
            _input(0, 6), new bytes32[](0), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    /// @dev `l1ReferenceBlockNumber` is a full word: a value whose low 64 bits name a recent block
    /// with a hash is still not in the past.
    function test_land_RevertWhen_ReferenceNumberIsAtLeast2Pow64() external {
        uint256 recent = block.number - 1;
        vm.setBlockhash(recent, keccak256("recent"));
        _setReference((uint256(1) << 64) + recent, keccak256("recent"));
        _expectLandRevert(
            _input(0, 6), new bytes32[](0), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_BlockhashIsZero() external {
        _setReference(block.number - 2, 0);
        _expectLandRevert(
            _input(0, 6), new bytes32[](0), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_HistoryHashIsZero() external {
        vm.roll(L1_HEAD);
        _setReference(L1_HEAD - 300, 0);
        _plantHistory(L1_HEAD - 300, 0);
        _expectLandRevert(
            _input(0, 6), new bytes32[](0), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_HistoryContractMissing() external {
        assertEq(HISTORY_STORAGE.code.length, 0, "no history contract");
        vm.roll(L1_HEAD);
        _setReference(L1_HEAD - 300, keccak256("unavailable"));
        _expectLandRevert(
            _input(0, 6), new bytes32[](0), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_BlobCountOutsideOneToSix() external {
        bytes32[] memory none = new bytes32[](0);
        _setBlobCount(0);
        _expectLandRevert(_input(0, 6), none, IEtnaInbox.InvalidBlobCount.selector);
        _setBlobCount(7);
        _expectLandRevert(_input(0, 6), none, IEtnaInbox.InvalidBlobCount.selector);

        _setBlobCount(1);
        _land(0, 6);
        _setBlobCount(6);
        _land(6, 12);
    }

    /// @dev The statement binds every blob hash in index order: a reordered or shorter list is a
    /// different statement.
    function test_land_BindsEveryBlobHashInOrder() external {
        bytes32[] memory none = new bytes32[](0);
        IEtnaInbox.LandInput memory input = _input(0, 6);
        bytes32 cutHash = _cutHash(input, none);
        IEtnaInbox.Landing memory origin = _inbox().landings(0);

        _setBlobCount(3);
        bytes32 inOrder = _statement(input, origin, cutHash);
        bytes32[] memory reversed = new bytes32[](3);
        (reversed[0], reversed[1], reversed[2]) = (_blobHash(2), _blobHash(1), _blobHash(0));
        blobHashes = reversed;
        assertNotEq(_statement(input, origin, cutHash), inOrder, "order bound");
        _setBlobCount(2);
        assertNotEq(_statement(input, origin, cutHash), inOrder, "third blob bound");

        landVerifier.setExpectedStatementHash(inOrder);
        _expectLandRevert(input, none, MockLandProofVerifier.ProofRejected.selector);
        blobHashes = reversed;
        _expectLandRevert(input, none, MockLandProofVerifier.ProofRejected.selector);
        _setBlobCount(3);
        assertEq(_land(input, none), inOrder, "three blobs in order");
    }

    // ---------------------------------------------------------------
    // Step 6: proof, atomicity, lock and calls
    // ---------------------------------------------------------------

    function test_land_RevertWhen_ProofRejected_RollsBackEverything() external {
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _input(0, 6);
        _expectLandRevert(input, new bytes32[](0), MockLandProofVerifier.ProofRejected.selector);

        _assertCheckpoint(0, bytes32(uint256(100)));
        assertEq(_inbox().activeCommitteeSnapshot(), registryCheckpointBlock, "snapshot");
        _assertQueue(0, LEAN_FORCED_INCLUSIONS);
        _assertLanding(
            6,
            IEtnaInbox.Landing({ parentHeight: 0, generation: 0, head: 0, elHash: 0, cometHash: 0 })
        );
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(6);
    }

    /// @dev Before `init` the proxy on the `EtnaInbox` implementation rejects `land` and nothing
    /// is written.
    function test_land_RevertWhen_NotInitialized() external {
        _deployFreshInbox(false);
        _inbox().upgradeTo(address(inboxImpl));
        assertFalse(_inbox().isInitialized(), "not initialized");

        vm.blobhashes(blobHashes);
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        vm.prank(Bob);
        _inbox().land(_input(0, 6), new bytes32[](0), PROOF);

        for (uint256 slot = 251; slot < 301; ++slot) {
            assertEq(_inboxWord(slot), 0, string.concat("slot ", vm.toString(slot)));
        }
        for (uint256 w; w < 3; ++w) {
            assertEq(_inboxWord(_landingSlot(6) + w), 0, "landings(6)");
        }
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(6);
    }

    /// @dev `land` holds the reentrancy lock it shares with `recover` until it returns: a
    /// SignalService stand-in sees it held and its re-entry fails.
    function test_land_HoldsTheReentrancyLock() external {
        LockProbeSignalService probe = new LockProbeSignalService();
        IEtnaInbox.Config memory config = _defaultConfig();
        config.signalService = address(probe);
        _inbox().upgradeTo(address(_newInboxImpl(config)));
        probe.setReentryCall(
            abi.encodeCall(IEtnaInbox.land, (_input(6, 12), new bytes32[](0), PROOF))
        );

        _land(0, 6);

        assertEq(probe.saves(), 1, "one checkpoint saved");
        assertTrue(probe.lockHeld(), "lock held while saving");
        assertFalse(probe.reentrySucceeded(), "re-entry rejected");
        assertEq(
            probe.reentryError(),
            abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector),
            "REENTRANT_CALL"
        );
        assertFalse(_inbox().inNonReentrant(), "released after the landing");
    }

    /// @dev `land` calls nothing but the verifier (static), the EIP-2935 history contract
    /// (static, only for a reference 257-8191 blocks back) and the SignalService, and sends no
    /// ETH.
    function test_land_CallsOnlyTheVerifierHistoryAndSignalService() external {
        vm.roll(L1_HEAD);
        _setReference(L1_HEAD - 257, keccak256("history 257"));
        _plantHistory(L1_HEAD - 257, keccak256("history 257"));
        IEtnaInbox.LandInput memory input = _input(0, 6);
        address signalImpl = signalService.impl();

        vm.blobhashes(blobHashes);
        vm.startStateDiffRecording();
        vm.prank(Bob);
        _inbox().land(input, new bytes32[](0), PROOF);
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        uint256 seen;
        for (uint256 i; i < accesses.length; ++i) {
            VmSafe.AccountAccess memory a = accesses[i];
            if (!_isCall(a.kind) || a.account == address(vm)) continue;
            assertEq(a.value, 0, "no ETH sent");
            if (a.account == inboxProxy) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.Call), "Inbox entry");
                assertEq(a.accessor, Bob, "called by the lander");
            } else if (a.account == address(inboxImpl)) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.DelegateCall), "Inbox impl");
            } else if (a.account == address(landVerifier)) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.StaticCall), "verifier");
                seen |= 1;
            } else if (a.account == HISTORY_STORAGE) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.StaticCall), "history");
                seen |= 2;
            } else if (a.account == address(signalService)) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.Call), "SignalService");
                seen |= 4;
            } else if (a.account == signalImpl) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.DelegateCall), "signal impl");
            } else {
                revert(string.concat("unexpected call to ", vm.toString(a.account)));
            }
        }
        assertEq(seen, 7, "verifier, history and SignalService called");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The record `(_parent, _generation, _head)` holding the committed chain's hashes at
    /// `_x`.
    function _record(
        uint256 _parent,
        uint256 _generation,
        uint256 _head,
        uint256 _x
    )
        private
        pure
        returns (IEtnaInbox.Landing memory)
    {
        (bytes32 el, bytes32 comet,) = _cut(_x);
        return IEtnaInbox.Landing({
            parentHeight: uint48(_parent),
            generation: uint48(_generation),
            head: uint48(_head),
            elHash: el,
            cometHash: comet
        });
    }

    function _plantHistory(uint256 _number, bytes32 _hash) private {
        vm.etch(HISTORY_STORAGE, HISTORY_STORAGE_CODE);
        vm.store(HISTORY_STORAGE, bytes32(_number % 8191), _hash);
    }

    function _isCall(VmSafe.AccountAccessKind _kind) private pure returns (bool) {
        return _kind == VmSafe.AccountAccessKind.Call
            || _kind == VmSafe.AccountAccessKind.DelegateCall
            || _kind == VmSafe.AccountAccessKind.CallCode
            || _kind == VmSafe.AccountAccessKind.StaticCall
            || _kind == VmSafe.AccountAccessKind.Create;
    }
}
