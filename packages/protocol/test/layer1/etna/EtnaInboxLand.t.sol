// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockLandProofVerifier } from "./EtnaInboxTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { LibEtnaLandStatement } from "./LibEtnaLandStatement.sol";
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
    // Any height, one leaf per height
    // ---------------------------------------------------------------

    /// @dev A one-block landing (h = p + 1) carries no leaves, its cutHash hashes the empty list
    /// as keccak256(""), and landings[h] holds three words.
    function test_land_singleBlock_noLeaves() external {
        IEtnaInbox.LandInput memory input = _input(0, 1);
        bytes32[] memory none = _leaves(0, 1);
        assertEq(none.length, 0, "no leaves");
        bytes32 cutHash = _cutHash(input, none);
        assertEq(
            cutHash,
            keccak256(
                abi.encode(
                    bytes32("ETNA_LAND_CUTS_V1"), uint256(0), uint256(0), uint256(1), keccak256("")
                )
            ),
            "cut hash over the empty list"
        );

        _land(input, none);

        _assertCheckpoint(1, bytes32(uint256(101)));
        uint256 slot = _landingSlot(1);
        assertEq(_inboxWord(slot), _landingWord1(0, 0, 0), "word 1: parent, generation, head");
        assertEq(_inboxWord(slot + 1), bytes32(uint256(101)), "word 2: EL hash");
        assertEq(_inboxWord(slot + 2), bytes32(uint256(201)), "word 3: Comet hash");
        assertEq(_inboxWord(slot + 3), 0, "no fourth word");
        assertEq(signalService.getCheckpoint(1).stateRoot, bytes32(uint256(301)), "state root");

        // The next block lands on its own from the new checkpoint.
        _land(1, 2);
        _assertCheckpoint(2, bytes32(uint256(102)));
        assertEq(_inboxWord(_landingSlot(2)), _landingWord1(1, 0, 0), "parent 1");
    }

    /// @dev A competitor settles p + 1 first, a height that was never a grid point. The original
    /// transaction proving (p, p + 3] still lands unchanged: its leaf at index c - p - 1 = 0 is
    /// cutLeaf(p + 1) over the competitor's record, and the verifier accepts only its statement.
    function test_land_overlapAtPPlusOne() external {
        uint256 p = 2;
        _land(0, p);
        IEtnaInbox.LandInput memory original = _input(p, p + 3);
        bytes32[] memory leaves = _leaves(p, p + 3);
        assertEq(leaves.length, 2, "the leaves of p + 1 and p + 2");
        bytes32 statement = _statement(original, _inbox().landings(p), _cutHash(original, leaves));

        _land(p, p + 1);
        _assertCheckpoint(p + 1, bytes32(uint256(100 + p + 1)));
        IEtnaInbox.Landing memory atC = _inbox().landings(p + 1);
        assertEq(
            leaves[0],
            LibEtnaLandStatement.cutLeaf(p + 1, atC.elHash, atC.cometHash, atC.head),
            "leaves[0] is cutLeaf(p + 1)"
        );

        landVerifier.setExpectedStatementHash(statement);
        assertEq(_land(original, leaves), statement, "the original statement");
        _assertCheckpoint(p + 3, bytes32(uint256(100 + p + 3)));
        assertEq(_inboxWord(_landingSlot(p + 3)), _landingWord1(p + 1, 0, 0), "parent is c");
    }

    /// @dev `leaves.length` must be exactly h - p - 1.
    function test_land_revertsOnWrongLeafCount() external {
        _expectLandRevert(_input(0, 3), new bytes32[](1), IEtnaInbox.LeafCountMismatch.selector);
        _expectLandRevert(_input(0, 3), new bytes32[](3), IEtnaInbox.LeafCountMismatch.selector);
        _expectLandRevert(_input(0, 1), new bytes32[](1), IEtnaInbox.LeafCountMismatch.selector);
        _land(0, 2);
        _expectLandRevert(_input(2, 7), _leaves(2, 6), IEtnaInbox.LeafCountMismatch.selector);
        _expectLandRevert(_input(0, 7), _leaves(2, 7), IEtnaInbox.LeafCountMismatch.selector);
    }

    /// @dev With c = 4 and p = 2 the leaf at index c - p - 1 = 1 must match c's record; altering
    /// it reverts before the proof is verified, while altering another index leaves the decision
    /// to the proof.
    function test_land_revertsOnLeafMismatchAtC() external {
        _land(0, 2);
        _land(2, 4);
        IEtnaInbox.LandInput memory input = _input(2, 7);
        bytes32[] memory leaves = _leaves(2, 7);
        assertEq(leaves[1], _leaf(4), "index c - p - 1 holds the leaf of c");

        // The verifier rejects every proof, so a leaf check after it would fail as the proof.
        landVerifier.setRejects(true);
        leaves[1] = keccak256("not the leaf of c");
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);

        leaves = _leaves(2, 7);
        leaves[0] = keccak256("not checked");
        leaves[2] = keccak256("not checked");
        _expectLandRevert(input, leaves, MockLandProofVerifier.ProofRejected.selector);

        landVerifier.setRejects(false);
        _land(input, _leaves(2, 7));
        _assertCheckpoint(7, bytes32(uint256(107)));
    }

    /// @dev The statement preimage is the 21 static ABI words of ENC-A-35 in order, 672 bytes, and
    /// the Inbox verifies exactly its keccak256.
    function test_statement_is672Bytes() external {
        IEtnaInbox.LandInput memory input = _input(0, 3);
        bytes32[] memory leaves = _leaves(0, 3);
        bytes32 cutHash = _cutHash(input, leaves);
        IEtnaInbox.Landing memory origin = _inbox().landings(0);
        bytes memory preimage = _statementPreimage(input, origin, cutHash);
        assertEq(preimage.length, 672, "672 bytes");

        bytes32[21] memory words = [
            bytes32("TAIKO_ETNA_LAND_V1"),
            bytes32(block.chainid),
            bytes32(uint256(L2_CHAIN_ID)),
            bytes32(uint256(uint160(inboxProxy))),
            bytes32(uint256(uint160(address(registry)))),
            bytes32(0),
            bytes32(0),
            bytes32(uint256(100)),
            bytes32(0),
            _inbox().committeeConfigHash(),
            bytes32(uint256(3)),
            bytes32(uint256(103)),
            bytes32(uint256(203)),
            bytes32(uint256(303)),
            bytes32(LEAN_REFERENCE_BLOCK),
            LEAN_REFERENCE_HASH,
            keccak256(abi.encodePacked(blobHashes)),
            bytes32(0),
            bytes32(0),
            bytes32(LEAN_SNAPSHOT),
            cutHash
        ];
        for (uint256 i; i < words.length; ++i) {
            assertEq(_word(preimage, i), words[i], string.concat("word ", vm.toString(i)));
        }

        assertEq(_land(input, leaves), keccak256(preimage), "the Inbox verifies this statement");
    }

    /// @dev `cutLeaf(x) = keccak256(abi.encode(x, blockHash, cometHash, forcedHead))`, four words,
    /// and the Inbox accepts exactly that leaf at c.
    function test_cutLeaf_fourWords() external {
        uint256 x = 5;
        bytes32 bh = keccak256("block hash");
        bytes32 ch = keccak256("comet hash");
        uint256 head = 7;
        assertEq(abi.encode(x, bh, ch, head).length, 128, "four words");
        assertEq(
            LibEtnaLandStatement.cutLeaf(x, bh, ch, head),
            keccak256(abi.encode(x, bh, ch, head)),
            "cutLeaf"
        );

        _land(0, 1);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(
            abi.encode(uint256(1), bytes32(uint256(101)), bytes32(uint256(201)), uint256(0))
        );
        _land(_input(0, 2), leaves);
        _assertCheckpoint(2, bytes32(uint256(102)));
    }

    // ---------------------------------------------------------------
    // Landing and its writes
    // ---------------------------------------------------------------

    /// @dev A downstream checkpoint failure rolls back the record already written by land.
    function test_land_RollbackAfterCheckpointFailure() external {
        vm.mockCallRevert(
            address(signalService),
            abi.encodeWithSelector(SignalService.saveCheckpoint.selector),
            abi.encode("checkpoint failed")
        );
        IEtnaInbox.LandInput memory input = _input(0, 6);
        vm.blobhashes(blobHashes);
        vm.expectRevert(abi.encode("checkpoint failed"));
        _inbox().land(input, _leaves(0, 6), PROOF);
        for (uint256 w; w < 3; ++w) {
            assertEq(_inboxWord(_landingSlot(6) + w), 0, "record rolled back");
        }
        _assertCheckpoint(0, bytes32(uint256(100)));
        _assertQueue(0, LEAN_FORCED_INCLUSIONS);
        assertEq(_inbox().activeCommitteeSnapshot(), registryCheckpointBlock);
    }

    /// @dev The first batch writes the terminal record and retains the start record.
    function test_land_LandsFirstBatch() external {
        IEtnaInbox.LandInput memory input = _input(0, 6);
        bytes32[] memory leaves = _leaves(0, 6);
        assertEq(leaves.length, 5, "the leaves of 1 to 5");
        assertEq(_inbox().l2ChainId(), L2_CHAIN_ID, "statement L2 chain id");
        assertEq(_inbox().stakingRegistry(), address(registry), "statement registry");

        // `_land` expects `Landed(0, 0, 6, cutHash, 4, 1)` and one verifier call.
        _land(input, leaves);

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
        assertEq(leaves.length, 11, "eleven heights inside (0, 12)");
        assertEq(leaves[5], _leaf(6), "the leaf at 6");

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
    /// or the reference block: `land` adds no snapshot check to the reference Solidity.
    function test_land_StoresTheProvenSnapshotWithoutBounds() external {
        IEtnaInbox.LandInput memory input = _input(0, 6);
        input.activeCommitteeSnapshot = 0;
        _land(input, _leaves(0, 6));
        assertEq(_inbox().activeCommitteeSnapshot(), 0, "below the stored snapshot");

        input = _input(6, 12);
        input.activeCommitteeSnapshot = type(uint256).max;
        _land(input, _leaves(6, 12));
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
    // Step 1: range
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

    /// @dev `h < 2^48` is part of the range check: 2^48 is rejected by the range check before the
    /// batch size check, even at the largest allowed batch size, and from a checkpoint just below
    /// the limit 2^48 - 1 lands.
    function test_land_RevertWhen_HeightReaches2Pow48() external {
        bytes32[] memory none = new bytes32[](0);
        uint256 h = _TWO_POW_48;
        _upgradeWithMaxBatchBlocks(MAX_BATCH_BLOCKS_CAP);
        _expectLandRevert(_input(0, h), none, IEtnaInbox.InvalidRange.selector);

        uint256 p = _TWO_POW_48 - 10;
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

        _expectLandRevert(_input(p, h), _leaves(p, h), IEtnaInbox.InvalidRange.selector);
        _assertCheckpoint(p, near.elHash);

        IEtnaInbox.LandInput memory input = _input(p, _TWO_POW_48 - 1);
        input.forcedInclusionHead = 0;
        _land(input, _leaves(p, _TWO_POW_48 - 1));
        _assertCheckpoint(_TWO_POW_48 - 1, input.lastBlockHash);
        _assertLanding(
            _TWO_POW_48 - 1,
            IEtnaInbox.Landing({
                parentHeight: uint48(p),
                generation: 0,
                head: 0,
                elHash: input.lastBlockHash,
                cometHash: input.lastCometHash
            })
        );
        assertEq(
            signalService.getCheckpoint(uint48(_TWO_POW_48 - 1)).stateRoot,
            input.lastStateRoot,
            "signal checkpoint"
        );
    }

    /// @dev `h - p <= maxBatchBlocks`, inclusive: with the minimum of one block (0, 1] lands and
    /// (0, 2] does not; with 1000, 1000 lands and 1001 does not.
    function test_land_RevertWhen_BatchTooLarge() external {
        assertEq(MAX_BATCH_BLOCKS, 1000, "maxBatchBlocks");
        _expectLandRevert(_input(0, 1001), _leaves(0, 1001), IEtnaInbox.BatchTooLarge.selector);

        _upgradeWithMaxBatchBlocks(1);
        _expectLandRevert(_input(0, 2), _leaves(0, 2), IEtnaInbox.BatchTooLarge.selector);
        _land(0, 1);
        // The bound is on the proven range (p, h], not on the settled suffix (c, h].
        _expectLandRevert(_input(0, 2), _leaves(0, 2), IEtnaInbox.BatchTooLarge.selector);
        _land(1, 2);

        _upgradeWithMaxBatchBlocks(MAX_BATCH_BLOCKS);
        IEtnaInbox.LandInput memory input = _input(0, 1000);
        input.forcedInclusionHead = LEAN_FORCED_INCLUSIONS;
        bytes32[] memory leaves = _leaves(0, 1000);
        assertEq(leaves.length, 999, "999 leaves");
        _land(input, leaves);
        _assertCheckpoint(1000, bytes32(uint256(1100)));
    }

    /// @dev PARAM-11-6: a landing at the cap of 12,951 blocks, with 12,950 leaves, six blobs and a
    /// 4 KiB proof, fits one transaction under the EIP-7825 cap of 2^24 gas. Counting every
    /// calldata byte as non-zero, standard pricing (16 gas per byte) plus the measured execution
    /// stays below the EIP-7623 floor (40 gas per byte), so the floor sets the transaction's gas
    /// and `test_maxBatchBlocksLimit_FitsOneTransaction` derives the cap from it. The mock verifier
    /// costs almost nothing; the logged margin is what a real verifier may use.
    function test_land_AtTheBatchCapFitsOneTransaction() external {
        uint256 h = MAX_BATCH_BLOCKS_CAP;
        _upgradeWithMaxBatchBlocks(MAX_BATCH_BLOCKS_CAP);
        _setBlobCount(6);
        IEtnaInbox.LandInput memory input = _input(0, h);
        input.forcedInclusionHead = LEAN_FORCED_INCLUSIONS;
        bytes32[] memory leaves = _leaves(0, h);
        assertEq(leaves.length, h - 1, "B - 1 leaves");
        bytes memory proof = new bytes(4096);
        landVerifier.setExpectedStatementHash(
            _statement(input, _inbox().landings(0), _cutHash(input, leaves))
        );

        vm.blobhashes(blobHashes);
        vm.prank(Bob);
        _inbox().land(input, leaves, proof);
        uint256 execution = vm.lastCallGas().gasTotalUsed;
        _assertCheckpoint(h, input.lastBlockHash);

        uint256 calldataBytes = abi.encodeCall(IEtnaInbox.land, (input, leaves, proof)).length;
        uint256 floorGas = 21_000 + 40 * calldataBytes;
        uint256 standardGas = 21_000 + 16 * calldataBytes + execution;
        emit log_named_uint("land execution gas", execution);
        emit log_named_uint("margin for a real verifier", floorGas - standardGas);
        assertLt(standardGas, floorGas, "the floor sets the gas");
        assertLt(floorGas, 2 ** 24, "fits one transaction");
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
        _land(0, 6);
        _plantQueue(0, LEAN_FORCED_INCLUSIONS);
        _expectLandRevert(
            _input(6, 12), _leaves(6, 12), IEtnaInbox.ForcedInclusionHeadMismatch.selector
        );
        _plantQueue(2, LEAN_FORCED_INCLUSIONS);
        _expectLandRevert(
            _input(6, 12), _leaves(6, 12), IEtnaInbox.ForcedInclusionHeadMismatch.selector
        );
    }

    /// @dev The leaf at c must match c's record in all four words; it is checked while the
    /// verifier rejects everything, so the leaf check runs before the proof.
    function test_land_RevertWhen_FrontierLeafDiffers() external {
        _land(0, 6);
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _input(0, 12);
        (bytes32 el, bytes32 comet, uint256 head) = _cut(6);
        bytes32 wrong = bytes32(uint256(999));
        bytes32[] memory leaves = _leaves(0, 12);

        leaves[5] = _leafOf(6, el, wrong, head);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);
        leaves[5] = _leafOf(6, wrong, comet, head);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);
        leaves[5] = _leafOf(7, el, comet, head);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);
        leaves[5] = _leafOf(6, el, comet, head + 1);
        _expectLandRevert(input, leaves, IEtnaInbox.FrontierLeafMismatch.selector);

        // With the honest leaf only the proof fails.
        leaves[5] = _leaf(6);
        _expectLandRevert(input, leaves, MockLandProofVerifier.ProofRejected.selector);
    }

    /// @dev Only the leaf at c is checked; the other leaves only feed cutHash.
    function test_land_ChecksOnlyTheLeafAtTheCheckpoint() external {
        bytes32 garbage = keccak256("not a cut leaf");
        uint256 fresh = vm.snapshotState();

        _land(0, 6);
        bytes32[] memory leaves = _leaves(0, 18);
        leaves[11] = garbage;
        _land(_input(0, 18), leaves);
        _assertCheckpoint(18, bytes32(uint256(118)));

        vm.revertToState(fresh);
        _land(0, 12);
        leaves = _leaves(0, 18);
        leaves[5] = garbage;
        _land(_input(0, 18), leaves);
        _assertCheckpoint(18, bytes32(uint256(118)));

        vm.revertToState(fresh);
        _land(0, 12);
        leaves = _leaves(0, 18);
        leaves[11] = garbage;
        _expectLandRevert(_input(0, 18), leaves, IEtnaInbox.FrontierLeafMismatch.selector);
    }

    // ---------------------------------------------------------------
    // Step 4: forced inclusion head
    // ---------------------------------------------------------------

    function test_land_RevertWhen_ForcedInclusionHeadOutOfBounds() external {
        bytes32[] memory leaves = _leaves(6, 12);
        _land(0, 6);
        IEtnaInbox.LandInput memory input = _input(6, 12);

        input.forcedInclusionHead = 0;
        _expectLandRevert(input, leaves, IEtnaInbox.InvalidForcedInclusionHead.selector);
        input.forcedInclusionHead = LEAN_FORCED_INCLUSIONS + 1;
        _expectLandRevert(input, leaves, IEtnaInbox.InvalidForcedInclusionHead.selector);

        // Both ends are inclusive: no advance, and an advance to the tail.
        uint256 beforeLanding = vm.snapshotState();
        input.forcedInclusionHead = 1;
        _land(input, leaves);
        _assertQueue(1, LEAN_FORCED_INCLUSIONS);
        vm.revertToState(beforeLanding);
        input.forcedInclusionHead = LEAN_FORCED_INCLUSIONS;
        _land(input, leaves);
        _assertQueue(LEAN_FORCED_INCLUSIONS, LEAN_FORCED_INCLUSIONS);
        vm.revertToState(beforeLanding);

        // An advance beyond h - c = 6 with enough entries queued.
        _saveForcedInclusions(5);
        input.forcedInclusionHead = 8;
        _expectLandRevert(input, leaves, IEtnaInbox.InvalidForcedInclusionHead.selector);
        input.forcedInclusionHead = 7;
        _land(input, leaves);
        _assertQueue(7, 8);
    }

    /// @dev c = 6 with head 0, h = 12 and tail 10, proved from p = 0: the advance is bounded by
    /// h - c = 6, not h - p = 12.
    function test_land_HeadAdvanceIsBoundedByHMinusC() external {
        _saveForcedInclusions(7);
        IEtnaInbox.LandInput memory first = _input(0, 6);
        first.forcedInclusionHead = 0;
        _land(first, _leaves(0, 6));
        _assertQueue(0, 10);

        IEtnaInbox.LandInput memory input = _input(0, 12);
        (bytes32 el, bytes32 comet,) = _cut(6);
        bytes32[] memory leaves = _leaves(0, 12);
        leaves[5] = _leafOf(6, el, comet, 0);

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
            _input(0, 6), _leaves(0, 6), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_ReferenceNotInThePast() external {
        _setReference(block.number, keccak256("current"));
        _expectLandRevert(
            _input(0, 6), _leaves(0, 6), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
        _setReference(block.number + 1, keccak256("future"));
        _expectLandRevert(
            _input(0, 6), _leaves(0, 6), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    /// @dev `l1ReferenceBlockNumber` is a full word: a value whose low 64 bits name a recent block
    /// with a hash is still not in the past.
    function test_land_RevertWhen_ReferenceNumberIsAtLeast2Pow64() external {
        uint256 recent = block.number - 1;
        vm.setBlockhash(recent, keccak256("recent"));
        _setReference((uint256(1) << 64) + recent, keccak256("recent"));
        _expectLandRevert(
            _input(0, 6), _leaves(0, 6), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_BlockhashIsZero() external {
        _setReference(block.number - 2, 0);
        _expectLandRevert(
            _input(0, 6), _leaves(0, 6), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_HistoryHashIsZero() external {
        vm.roll(L1_HEAD);
        _setReference(L1_HEAD - 300, 0);
        _plantHistory(L1_HEAD - 300, 0);
        _expectLandRevert(
            _input(0, 6), _leaves(0, 6), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_HistoryContractMissing() external {
        assertEq(HISTORY_STORAGE.code.length, 0, "no history contract");
        vm.roll(L1_HEAD);
        _setReference(L1_HEAD - 300, keccak256("unavailable"));
        _expectLandRevert(
            _input(0, 6), _leaves(0, 6), IEtnaInbox.ReferenceBlockUnavailable.selector
        );
    }

    function test_land_RevertWhen_BlobCountOutsideOneToSix() external {
        bytes32[] memory leaves = _leaves(0, 6);
        _setBlobCount(0);
        _expectLandRevert(_input(0, 6), leaves, IEtnaInbox.InvalidBlobCount.selector);
        _setBlobCount(7);
        _expectLandRevert(_input(0, 6), leaves, IEtnaInbox.InvalidBlobCount.selector);

        _setBlobCount(1);
        _land(0, 6);
        _setBlobCount(6);
        _land(6, 12);
    }

    /// @dev The statement binds every blob hash in index order: a reordered or shorter list is a
    /// different statement.
    function test_land_BindsEveryBlobHashInOrder() external {
        bytes32[] memory leaves = _leaves(0, 6);
        IEtnaInbox.LandInput memory input = _input(0, 6);
        bytes32 cutHash = _cutHash(input, leaves);
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
        _expectLandRevert(input, leaves, MockLandProofVerifier.ProofRejected.selector);
        blobHashes = reversed;
        _expectLandRevert(input, leaves, MockLandProofVerifier.ProofRejected.selector);
        _setBlobCount(3);
        assertEq(_land(input, leaves), inOrder, "three blobs in order");
    }

    // ---------------------------------------------------------------
    // Step 6: proof, atomicity, lock and calls
    // ---------------------------------------------------------------

    function test_land_RevertWhen_ProofRejected_RollsBackEverything() external {
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _input(0, 6);
        _expectLandRevert(input, _leaves(0, 6), MockLandProofVerifier.ProofRejected.selector);

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
    /// is written: c = 0 forces p = 0, and landings[0] is unwritten.
    function test_land_RevertWhen_NotInitialized() external {
        _deployFreshInbox(false);
        _inbox().upgradeTo(address(inboxImpl));
        assertFalse(_inbox().isInitialized(), "not initialized");

        vm.blobhashes(blobHashes);
        vm.expectRevert(IEtnaInbox.MissingOrigin.selector);
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
        _inbox().land(input, _leaves(0, 6), PROOF);
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
            } else if (a.account == address(registry)) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.StaticCall));
                assertEq(a.data, abi.encodeWithSignature("inNonReentrant()"));
            } else if (a.account == registry.impl()) {
                assertEq(uint8(a.kind), uint8(VmSafe.AccountAccessKind.DelegateCall));
            } else {
                revert(string.concat("unexpected call to ", vm.toString(a.account)));
            }
        }
        assertEq(seen, 7, "verifier, history and SignalService called");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _plantHistory(uint256 _number, bytes32 _hash) private {
        vm.etch(HISTORY_STORAGE, HISTORY_STORAGE_CODE);
        vm.store(HISTORY_STORAGE, bytes32(_number % 8191), _hash);
    }

    /// @dev Word `_i` of `_data`.
    function _word(
        bytes memory _data,
        uint256 _i
    )
        private
        pure
        returns (bytes32 word_)
    {
        assembly {
            word_ := mload(add(_data, add(32, mul(_i, 32))))
        }
    }
}
