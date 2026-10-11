// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase, MockLandProofVerifier } from "./EtnaInboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract EtnaInboxLandTest is EtnaInboxTestBase {
    /// @dev The EIP-2935 history storage contract and its runtime code.
    address internal constant HISTORY_STORAGE = 0x0000F90827F1C53a10cb7A02335B175320002935;
    bytes internal constant HISTORY_STORAGE_CODE =
        hex"3373fffffffffffffffffffffffffffffffffffffffe14604657602036036042575f35600143038111604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500";

    uint64 internal constant L1_HEAD = 20_000;
    bytes32 internal constant L1_REFERENCE_BLOCK_HASH = keccak256("anchor");
    bytes internal constant PROOF = "etna proof";

    /// @dev The L1 reference block number of every batch built by `_batch`.
    uint64 internal l1ReferenceBlockNumber;
    /// @dev The number of blobs `_land` attaches to the landing transaction.
    uint256 internal blobCount = 2;

    function setUp() public override {
        super.setUp();

        vm.roll(L1_HEAD);
        l1ReferenceBlockNumber = L1_HEAD - 1;
        vm.setBlockhash(l1ReferenceBlockNumber, L1_REFERENCE_BLOCK_HASH);
    }

    // ---------------------------------------------------------------
    // Happy paths
    // ---------------------------------------------------------------

    function test_land_BindsTheStoredStartingCommitteeInTheV3Statement() external {
        _landExpectingStartingCommittee(_batch(5, _recordRange(1, 1)), COMMITTEE_RECORD_0);
    }

    function test_land_BindsTheProxyAndConfiguredRegistryIndependentlyOfTheCaller() external {
        IEtnaInbox.LandInput memory input = _batch(11, _recordRange(1, 2));
        bytes32 expected = _manualStatement(
            0, genesisBlockHash, COMMITTEE_RECORD_0, input, L1_REFERENCE_BLOCK_HASH
        );
        assertNotEq(
            expected,
            _manualStatementForAddresses(
                address(etnaImplementation),
                address(registry),
                0,
                genesisBlockHash,
                COMMITTEE_RECORD_0,
                input,
                L1_REFERENCE_BLOCK_HASH
            ),
            "implementation is not the Inbox"
        );
        assertNotEq(
            expected,
            _manualStatementForAddresses(
                Carol,
                address(registry),
                0,
                genesisBlockHash,
                COMMITTEE_RECORD_0,
                input,
                L1_REFERENCE_BLOCK_HASH
            ),
            "caller is not the Inbox"
        );
        landVerifier.setExpectedStatementHash(expected);
        uint256 snapshot = vm.snapshotState();
        vm.expectCall(
            address(landVerifier), abi.encodeCall(IProofVerifier.verifyProof, (0, expected, PROOF))
        );
        vm.blobhashes(_getBlobHashes(blobCount));
        vm.prank(Carol);
        etnaInbox.land(input, PROOF);
        _assertLastCheckpoint(input.lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);

        assertTrue(vm.revertToStateAndDelete(snapshot), "restored the same landing input");
        _land(input); // Bob submits the identical proof after Carol's execution was reverted.
        _assertLastCheckpoint(input.lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_RejectsAProofForAnotherInboxAndRollsBack() external {
        EtnaInbox otherInbox = EtnaInbox(address(new ERC1967Proxy(address(etnaImplementation), "")));
        IEtnaInbox.LandInput memory input = _batch(11, _recordRange(1, 2));
        bytes32 wrongStatement = _manualStatementForAddresses(
            address(otherInbox),
            address(registry),
            0,
            genesisBlockHash,
            COMMITTEE_RECORD_0,
            input,
            L1_REFERENCE_BLOCK_HASH
        );
        _rejectStatementAndAssertRollback(input, wrongStatement);
        _landExpectingStartingCommittee(input, COMMITTEE_RECORD_0);
        _assertSignalCheckpoint(input);
    }

    function test_land_RejectsAProofForThePreviousRegistryAndRollsBack() external {
        IEtnaInbox.LandInput memory input = _batch(11, _recordRange(1, 2));
        bytes32 previousStatement = _manualStatement(
            0, genesisBlockHash, COMMITTEE_RECORD_0, input, L1_REFERENCE_BLOCK_HASH
        );
        IEtnaInbox.Config memory config = etnaConfig;
        config.stakingRegistry = address(_deployRegistry());
        etnaInbox.upgradeTo(address(new EtnaInbox(config)));
        _rejectStatementAndAssertRollback(input, previousStatement);

        bytes32 expected = _manualStatementForAddresses(
            address(etnaInbox),
            config.stakingRegistry,
            0,
            genesisBlockHash,
            COMMITTEE_RECORD_0,
            input,
            L1_REFERENCE_BLOCK_HASH
        );
        landVerifier.setExpectedStatementHash(expected);
        _land(input);
        _assertLastCheckpoint(input.lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_RejectsAV2ProofAndRollsBack() external {
        IEtnaInbox.LandInput memory input = _batch(11, _recordRange(1, 2));
        bytes memory context = abi.encode(
            bytes32("TAIKO_ETNA_LAND_V2"),
            block.chainid,
            L2_CHAIN_ID,
            uint64(0),
            uint64(0),
            genesisBlockHash,
            COMMITTEE_RECORD_0
        );
        bytes32 legacyStatement = keccak256(
            bytes.concat(
                context,
                abi.encode(
                    input.lastHeight,
                    input.lastBlockHash,
                    input.lastStateRoot,
                    input.l1ReferenceBlockNumber,
                    L1_REFERENCE_BLOCK_HASH,
                    keccak256(abi.encode(input.records)),
                    keccak256(abi.encodePacked(_getBlobHashes(blobCount)))
                )
            )
        );
        _rejectStatementAndAssertRollback(input, legacyStatement);
        _landExpectingStartingCommittee(input, COMMITTEE_RECORD_0);
        _assertSignalCheckpoint(input);
    }

    function test_land_SelectsStartingCommitteeAtBothSidesOfTheEpochBoundary() external {
        _landExpectingStartingCommittee(_batch(9, _recordRange(1, 1)), COMMITTEE_RECORD_0);
        // Parent L-1: block L is still in epoch zero.
        _landExpectingStartingCommittee(_batch(10, _recordRange(2, 0)), COMMITTEE_RECORD_0);
        // Parent L: block L+1 starts epoch one.
        _landExpectingStartingCommittee(_batch(11, _recordRange(2, 1)), _recordHash(1));
        // Parent L+1: the next block remains in epoch one.
        _landExpectingStartingCommittee(_batch(12, _recordRange(3, 0)), _recordHash(1));
    }

    function test_land_BindsStartingCommitteeWhenCrossingFromInsideAnEpoch() external {
        _landExpectingStartingCommittee(_batch(5, _recordRange(1, 1)), COMMITTEE_RECORD_0);
        assertEq(etnaInbox.committee(1), _recordHash(1), "successor already on chain");

        // Committee one was derived at block 1, before this batch. This batch only outputs
        // committee two at block 11; its starting committee remains committee zero.
        IEtnaInbox.LandInput memory input = _batch(12, _recordRange(2, 1));
        _landExpectingStartingCommittee(input, COMMITTEE_RECORD_0);
        assertEq(etnaInbox.committee(1), _recordHash(1), "prior successor unchanged");
        assertEq(etnaInbox.committee(2), _recordHash(2), "new successor recorded");

        // The next batch starts in epoch one. Committee two is already on chain before its
        // switch gate at block 19; committee three is derived at block 21.
        _landExpectingStartingCommittee(_batch(22, _recordRange(3, 1)), _recordHash(1));
        assertEq(etnaInbox.committee(2), _recordHash(2), "landed switch committee unchanged");
        assertEq(etnaInbox.committee(3), _recordHash(3), "third successor recorded");
    }

    function test_land_BindsOneStartingCommitteeAcrossMultipleEpochs() external {
        _landExpectingStartingCommittee(_batch(5, _recordRange(1, 1)), COMMITTEE_RECORD_0);
        _landExpectingStartingCommittee(_batch(31, _recordRange(2, 3)), COMMITTEE_RECORD_0);
        assertEq(etnaInbox.committee(4), _recordHash(4), "last derived successor");
    }

    function test_land_RevertWhen_StartingCommitteeIsMissingBeforeAnyBatchWrites() external {
        vm.store(address(etnaInbox), _committeeSlot(0), bytes32(0));
        IEtnaInbox.LandInput memory input = _batch(5, _recordRange(1, 1));
        vm.record();
        _expectLandRevert(input, EtnaInbox.StartingCommitteeNotRecorded.selector);
        (, bytes32[] memory writes) = vm.accesses(address(etnaInbox));
        for (uint256 i; i < writes.length; ++i) {
            assertNotEq(writes[i], _committeeSlot(1), "no successor write attempted");
            assertNotEq(
                writes[i], bytes32(LAST_CHECKPOINT_SLOT), "no checkpoint-height write attempted"
            );
            assertNotEq(
                writes[i], bytes32(LAST_CHECKPOINT_SLOT + 1), "no checkpoint-hash write attempted"
            );
        }
        _assertLastCheckpoint(0, genesisBlockHash);
        assertEq(etnaInbox.committee(1), bytes32(0), "successor not recorded");
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(5);
    }

    function test_land_RevertWhen_TheNextEpochStartingCommitteeIsMissing() external {
        IEtnaInbox.LandInput memory first = _batch(10, _recordRange(1, 1));
        _land(first);
        vm.store(address(etnaInbox), _committeeSlot(1), bytes32(0));
        _expectLandRevert(
            _batch(11, _recordRange(2, 1)), EtnaInbox.StartingCommitteeNotRecorded.selector
        );
        _assertLastCheckpoint(10, first.lastBlockHash);
        assertEq(etnaInbox.committee(2), bytes32(0), "next committee not installed");
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(11);
    }

    function test_land_ChangingTheStoredStartingHashChangesTheVerifierStatement() external {
        IEtnaInbox.LandInput memory input = _batch(5, _recordRange(1, 1));
        uint256 snapshot = vm.snapshotState();
        _landExpectingStartingCommittee(input, COMMITTEE_RECORD_0);
        assertTrue(vm.revertToStateAndDelete(snapshot), "restored identical batch state");

        bytes32 differentCommittee = keccak256("different on-chain committee");
        vm.store(address(etnaInbox), _committeeSlot(0), differentCommittee);
        assertNotEq(
            _manualStatement(
                0, genesisBlockHash, COMMITTEE_RECORD_0, input, L1_REFERENCE_BLOCK_HASH
            ),
            _manualStatement(
                    0, genesisBlockHash, differentCommittee, input, L1_REFERENCE_BLOCK_HASH
                ),
            "stored root is bound"
        );
        _landExpectingStartingCommittee(input, differentCommittee);
    }

    function test_land_CallerRecordsCannotReplaceTheTrustedStartingCommittee() external {
        IEtnaInbox.LandInput memory input = _batch(5, _recordRange(1, 1));
        input.records[0].recordHash = keccak256("caller-selected successor");
        _landExpectingStartingCommittee(input, COMMITTEE_RECORD_0);
        assertEq(etnaInbox.committee(0), COMMITTEE_RECORD_0, "trusted starting committee unchanged");
        assertEq(etnaInbox.committee(1), input.records[0].recordHash, "proof output successor");
    }

    function test_land_RejectsAProofForACallerChosenStartingCommitteeAndRollsBack() external {
        IEtnaInbox.LandInput memory input = _batch(11, _recordRange(1, 2));
        bytes32 callerChosenRoot = input.records[0].recordHash;
        // This mock models a proof valid only for a public statement using the caller's root.
        landVerifier.setExpectedStatementHash(
            _manualStatement(0, genesisBlockHash, callerChosenRoot, input, L1_REFERENCE_BLOCK_HASH)
        );
        _expectLandRevert(input, MockLandProofVerifier.ProofRejected.selector);
        _assertLastCheckpoint(0, genesisBlockHash);
        assertEq(etnaInbox.committee(0), COMMITTEE_RECORD_0, "trusted root retained");
        assertEq(etnaInbox.committee(1), bytes32(0), "first output reverted");
        assertEq(etnaInbox.committee(2), bytes32(0), "second output reverted");
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(11);

        _landExpectingStartingCommittee(input, COMMITTEE_RECORD_0);
        _assertSignalCheckpoint(input);
    }

    function testFuzz_land_SelectsStartingEpochFromTheFirstUnlandedBlock(
        uint64 _parentSeed,
        uint64 _spanSeed
    )
        external
    {
        uint64 parentHeight = uint64(bound(_parentSeed, 0, 100));
        uint64 lastHeight = parentHeight + uint64(bound(_spanSeed, 1, 40));
        if (parentHeight != 0) {
            _land(
                _batch(
                    parentHeight, _recordRange(1, (parentHeight + EPOCH_LEN_L2 - 1) / EPOCH_LEN_L2)
                )
            );
        }
        uint64 startEpoch = parentHeight / EPOCH_LEN_L2;
        bytes32 expectedStartingHash =
            startEpoch == 0 ? COMMITTEE_RECORD_0 : _recordHash(startEpoch);
        uint64 firstBoundaryEpoch = (parentHeight + EPOCH_LEN_L2 - 1) / EPOCH_LEN_L2;
        uint64 lastBoundaryEpoch = (lastHeight - 1) / EPOCH_LEN_L2;
        uint64 recordCount =
            lastBoundaryEpoch < firstBoundaryEpoch ? 0 : lastBoundaryEpoch - firstBoundaryEpoch + 1;
        IEtnaInbox.LandInput memory input =
            _batch(lastHeight, _recordRange(firstBoundaryEpoch + 1, recordCount));
        _landExpectingStartingCommittee(input, expectedStartingHash);
        _assertLastCheckpoint(lastHeight, input.lastBlockHash);
    }

    function test_land_LandsTheFirstBatch() external {
        uint64 lastHeight = genesisHeight + 5;
        IEtnaInbox.LandInput memory input = _batch(lastHeight, _recordRange(1, 1));
        bytes32 statementHash = _statement(genesisHeight, genesisBlockHash, input);

        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statementHash, PROOF))
        );
        vm.expectEmit();
        emit IEtnaInbox.CommitteeRecorded(1, _recordHash(1));
        vm.expectEmit();
        emit ICheckpointStore.CheckpointSaved(
            uint48(lastHeight), input.lastBlockHash, input.lastStateRoot
        );
        vm.expectEmit();
        emit IEtnaInbox.BatchLanded(
            genesisHeight + 1,
            lastHeight,
            input.lastBlockHash,
            input.lastStateRoot,
            l1ReferenceBlockNumber,
            statementHash,
            Bob
        );
        _land(input);

        _assertLastCheckpoint(lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);
        assertEq(etnaInbox.committee(1), _recordHash(1), "committee 1");
        assertEq(
            vm.load(address(etnaInbox), _committeeSlot(1)), _recordHash(1), "slot of committee 1"
        );
        assertEq(etnaInbox.committee(0), COMMITTEE_RECORD_0, "committee 0 unchanged");
    }

    function test_land_LandsTwoContiguousBatches() external {
        IEtnaInbox.LandInput memory first = _batch(genesisHeight + 5, _recordRange(1, 1));
        _land(first);
        _advanceBlock();

        IEtnaInbox.LandInput memory second = _batch(genesisHeight + 12, _recordRange(2, 1));
        bytes32 statementHash = _statement(genesisHeight + 5, first.lastBlockHash, second);

        vm.expectEmit();
        emit IEtnaInbox.CommitteeRecorded(2, _recordHash(2));
        vm.expectEmit();
        emit IEtnaInbox.BatchLanded(
            genesisHeight + 6,
            genesisHeight + 12,
            second.lastBlockHash,
            second.lastStateRoot,
            l1ReferenceBlockNumber,
            statementHash,
            Bob
        );
        _land(second);

        _assertLastCheckpoint(genesisHeight + 12, second.lastBlockHash);
        _assertSignalCheckpoint(first);
        _assertSignalCheckpoint(second);
        assertEq(etnaInbox.committee(1), _recordHash(1), "committee 1");
        assertEq(etnaInbox.committee(2), _recordHash(2), "committee 2");
    }

    function test_land_RecordsTwoBoundariesEndingOnAnEpochStart() external {
        // The epoch starts at heights 1 and 11, with the latter equal to lastHeight.
        _land(_batch(genesisHeight + 11, _recordRange(1, 2)));

        assertEq(etnaInbox.committee(1), _recordHash(1), "committee 1");
        assertEq(etnaInbox.committee(2), _recordHash(2), "committee 2");
        assertEq(etnaInbox.committee(3), bytes32(0), "committee 3");
    }

    function test_land_AcceptsABatchWithoutEpochBoundary() external {
        _land(_batch(genesisHeight + 11, _recordRange(1, 2)));

        // (B* + 11, B* + 20] holds no epoch start: h_first(1) = B* + 11 is the parent and
        // h_first(2) = B* + 21 lies beyond.
        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 20, _recordRange(3, 0));
        _land(input);

        _assertLastCheckpoint(genesisHeight + 20, input.lastBlockHash);
        assertEq(etnaInbox.committee(3), bytes32(0), "committee 3");
    }

    function test_land_RecordsThreeEpochBoundaries() external {
        _land(_batch(genesisHeight + 5, _recordRange(1, 1)));

        // h_first(1..3) = B* + 11, B* + 21, B* + 31.
        vm.expectEmit();
        emit IEtnaInbox.CommitteeRecorded(2, _recordHash(2));
        vm.expectEmit();
        emit IEtnaInbox.CommitteeRecorded(3, _recordHash(3));
        vm.expectEmit();
        emit IEtnaInbox.CommitteeRecorded(4, _recordHash(4));
        _land(_batch(genesisHeight + 31, _recordRange(2, 3)));

        for (uint64 epoch = 1; epoch <= 4; ++epoch) {
            assertEq(etnaInbox.committee(epoch), _recordHash(epoch), "committee");
        }
        assertEq(etnaInbox.committee(5), bytes32(0), "committee 5");
    }

    function test_land_AcceptsTheLargestBatch() external {
        // h_first(e) = B* + 1 + 10e <= B* + 1000 for e = 0..99.
        IEtnaInbox.LandInput memory input =
            _batch(genesisHeight + MAX_BATCH_BLOCKS, _recordRange(1, 100));
        _land(input);

        _assertLastCheckpoint(genesisHeight + MAX_BATCH_BLOCKS, input.lastBlockHash);
        assertEq(etnaInbox.committee(100), _recordHash(100), "committee 100");
    }

    function test_land_BindsTheRecoveryGeneration() external {
        vm.store(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT), bytes32(uint256(5)));
        assertEq(etnaInbox.recoveryGeneration(), 5, "generation");

        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 5, _recordRange(1, 1));
        bytes32 statementHash = etnaInbox.hashLandStatement(
            5,
            genesisHeight,
            genesisBlockHash,
            COMMITTEE_RECORD_0,
            input,
            L1_REFERENCE_BLOCK_HASH,
            _getBlobHashes(2)
        );
        assertNotEq(statementHash, _statement(genesisHeight, genesisBlockHash, input), "bound");

        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statementHash, PROOF))
        );
        _land(input);
    }

    function test_land_BindsEveryBlobHash() external {
        blobCount = 3;
        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 5, _recordRange(1, 1));
        bytes32 statementHash = etnaInbox.hashLandStatement(
            0,
            genesisHeight,
            genesisBlockHash,
            COMMITTEE_RECORD_0,
            input,
            L1_REFERENCE_BLOCK_HASH,
            _getBlobHashes(3)
        );
        bytes32 twoBlobStatementHash = etnaInbox.hashLandStatement(
            0,
            genesisHeight,
            genesisBlockHash,
            COMMITTEE_RECORD_0,
            input,
            L1_REFERENCE_BLOCK_HASH,
            _getBlobHashes(2)
        );
        assertNotEq(statementHash, twoBlobStatementHash, "third blob bound");

        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statementHash, PROOF))
        );
        _land(input);
    }

    // ---------------------------------------------------------------
    // Committee records
    // ---------------------------------------------------------------

    function test_land_RevertWhen_RecordMissing() external {
        _expectLandRevert(
            _batch(genesisHeight + 11, _recordRange(1, 1)),
            EtnaInbox.CommitteeRecordsMismatch.selector
        );
        _expectLandRevert(
            _batch(genesisHeight + 11, _recordRange(1, 0)),
            EtnaInbox.CommitteeRecordsMismatch.selector
        );
    }

    function test_land_RevertWhen_RecordExtra() external {
        _expectLandRevert(
            _batch(genesisHeight + 11, _recordRange(1, 3)),
            EtnaInbox.CommitteeRecordsMismatch.selector
        );
    }

    function test_land_RevertWhen_RecordInABatchWithoutEpochBoundary() external {
        _land(_batch(genesisHeight + 11, _recordRange(1, 2)));

        _expectLandRevert(
            _batch(genesisHeight + 20, _recordRange(3, 1)),
            EtnaInbox.CommitteeRecordsMismatch.selector
        );
    }

    function test_land_RevertWhen_RecordsReordered() external {
        IEtnaInbox.CommitteeRecord[] memory records = _recordRange(1, 2);
        (records[0], records[1]) = (records[1], records[0]);

        _expectLandRevert(
            _batch(genesisHeight + 11, records), EtnaInbox.CommitteeRecordsMismatch.selector
        );
    }

    function test_land_RevertWhen_RecordHashIsZero() external {
        IEtnaInbox.CommitteeRecord[] memory records = _recordRange(1, 2);
        records[1].recordHash = 0;

        _expectLandRevert(
            _batch(genesisHeight + 11, records), EtnaInbox.CommitteeRecordsMismatch.selector
        );
    }

    function test_land_RevertWhen_RecordKeyedByTheEpochItselfInsteadOfTheNext() external {
        _expectLandRevert(
            _batch(genesisHeight + 11, _recordRange(0, 2)),
            EtnaInbox.CommitteeRecordsMismatch.selector
        );
    }

    function test_land_RevertWhen_CommitteeAlreadyRecorded() external {
        vm.store(address(etnaInbox), _committeeSlot(1), keccak256("stale"));

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)),
            EtnaInbox.CommitteeAlreadyRecorded.selector
        );
    }

    // ---------------------------------------------------------------
    // L1 reference block
    // ---------------------------------------------------------------

    function test_land_ReadsTheAnchorFromBlockhash() external {
        l1ReferenceBlockNumber = L1_HEAD - 256;
        bytes32 l1ReferenceBlockHash = keccak256("oldest blockhash");
        vm.setBlockhash(l1ReferenceBlockNumber, l1ReferenceBlockHash);
        _plantHistory(l1ReferenceBlockNumber, keccak256("history"));

        _landExpectingL1ReferenceBlock(
            _batch(genesisHeight + 5, _recordRange(1, 1)), l1ReferenceBlockHash
        );
    }

    function test_land_ReadsTheAnchorFromTheHistoryContract() external {
        l1ReferenceBlockNumber = L1_HEAD - 257;
        bytes32 l1ReferenceBlockHash = keccak256("history 257");
        _plantHistory(l1ReferenceBlockNumber, l1ReferenceBlockHash);
        _landExpectingL1ReferenceBlock(
            _batch(genesisHeight + 5, _recordRange(1, 1)), l1ReferenceBlockHash
        );

        l1ReferenceBlockNumber = L1_HEAD - 8191;
        l1ReferenceBlockHash = keccak256("history 8191");
        _plantHistory(l1ReferenceBlockNumber, l1ReferenceBlockHash);
        _landExpectingL1ReferenceBlock(
            _batch(genesisHeight + 10, _recordRange(2, 0)), l1ReferenceBlockHash
        );
    }

    function test_historyContract_ServesTheLast8191Blocks() external {
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

    function test_land_RevertWhen_AnchorTooOld() external {
        l1ReferenceBlockNumber = L1_HEAD - 8192;
        _plantHistory(l1ReferenceBlockNumber, keccak256("too old"));

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    function test_land_RevertWhen_AnchorNotInThePast() external {
        l1ReferenceBlockNumber = L1_HEAD;
        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );

        l1ReferenceBlockNumber = L1_HEAD + 1;
        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    function test_land_RevertWhen_BlockhashIsZero() external {
        l1ReferenceBlockNumber = L1_HEAD - 2;
        vm.setBlockhash(l1ReferenceBlockNumber, 0);

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    function test_land_RevertWhen_HistoryHashIsZero() external {
        l1ReferenceBlockNumber = L1_HEAD - 300;
        _plantHistory(l1ReferenceBlockNumber, 0);

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    function test_land_RevertWhen_HistoryContractMissing() external {
        assertEq(HISTORY_STORAGE.code.length, 0, "no history contract");
        l1ReferenceBlockNumber = L1_HEAD - 300;

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    // ---------------------------------------------------------------
    // Blobs, bounds and proof
    // ---------------------------------------------------------------

    function test_land_RevertWhen_NoBlobs() external {
        blobCount = 0;

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.BlobsRequired.selector
        );
    }

    function test_land_RevertWhen_NoProgress() external {
        _expectLandRevert(_batch(genesisHeight, _recordRange(1, 0)), EtnaInbox.NoProgress.selector);
        _land(_batch(5, _recordRange(1, 1)));
        _expectLandRevert(_batch(4, _recordRange(2, 0)), EtnaInbox.NoProgress.selector);
    }

    function test_land_RevertWhen_BatchTooLarge() external {
        _expectLandRevert(
            _batch(genesisHeight + MAX_BATCH_BLOCKS + 1, _recordRange(1, 101)),
            EtnaInbox.BatchTooLarge.selector
        );
    }

    function test_land_RevertWhen_HeightOverflow() external {
        etnaConfig.maxBatchBlocks = type(uint64).max;
        etnaInbox.upgradeTo(address(new EtnaInbox(etnaConfig)));

        _expectLandRevert(
            _batch(uint64(type(uint48).max) + 1, _recordRange(1, 0)),
            EtnaInbox.HeightOverflow.selector
        );
    }

    function test_land_RevertWhen_ProofRejected() external {
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 5, _recordRange(1, 1));

        _expectLandRevert(input, MockLandProofVerifier.ProofRejected.selector);

        _assertLastCheckpoint(genesisHeight, genesisBlockHash);
        assertEq(etnaInbox.committee(1), bytes32(0), "committee 1");
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(uint48(input.lastHeight));
    }

    // ---------------------------------------------------------------
    // hashLandStatement
    // ---------------------------------------------------------------

    function test_hashLandStatement_BindsEachProxySharingTheSameImplementation() external {
        EtnaInbox otherInbox = EtnaInbox(address(new ERC1967Proxy(address(etnaImplementation), "")));
        IEtnaInbox.LandInput memory input = _batch(5, _recordRange(1, 1));
        bytes32[] memory blobs = _getBlobHashes(blobCount);
        bytes32 firstStatement = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, COMMITTEE_RECORD_0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        bytes32 secondStatement = otherInbox.hashLandStatement(
            0, 0, genesisBlockHash, COMMITTEE_RECORD_0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        assertNotEq(firstStatement, secondStatement, "each Inbox proxy is bound");
    }

    function test_hashLandStatement_BindsTheRegistryWhenOnlyItsImmutableChanges() external {
        IEtnaInbox.LandInput memory input = _batch(5, _recordRange(1, 1));
        bytes32[] memory blobs = _getBlobHashes(blobCount);
        bytes32 original = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, COMMITTEE_RECORD_0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        IEtnaInbox.Config memory config = etnaConfig;
        config.stakingRegistry = address(_deployRegistry());
        etnaInbox.upgradeTo(address(new EtnaInbox(config)));
        bytes32 upgraded = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, COMMITTEE_RECORD_0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        assertNotEq(original, upgraded, "configured Registry is bound");
        assertEq(
            upgraded,
            _manualStatementForAddresses(
                address(etnaInbox),
                config.stakingRegistry,
                0,
                genesisBlockHash,
                COMMITTEE_RECORD_0,
                input,
                L1_REFERENCE_BLOCK_HASH
            ),
            "same proxy uses the new Registry"
        );
    }

    function test_hashLandStatement_EncodesTheSpecifiedFields() external {
        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 11, _recordRange(1, 2));
        bytes32[] memory blobHashes = _getBlobHashes(3);

        bytes memory context = abi.encode(
            bytes32("TAIKO_ETNA_LAND_V3"),
            block.chainid,
            L2_CHAIN_ID,
            address(etnaInbox),
            address(registry),
            uint64(9),
            genesisHeight,
            genesisBlockHash,
            COMMITTEE_RECORD_0
        );
        bytes32 expected = keccak256(
            bytes.concat(
                context,
                abi.encode(
                    input.lastHeight,
                    input.lastBlockHash,
                    input.lastStateRoot,
                    input.l1ReferenceBlockNumber,
                    L1_REFERENCE_BLOCK_HASH,
                    keccak256(abi.encode(input.records)),
                    keccak256(abi.encodePacked(blobHashes))
                )
            )
        );
        assertEq(
            etnaInbox.hashLandStatement(
                9,
                genesisHeight,
                genesisBlockHash,
                COMMITTEE_RECORD_0,
                input,
                L1_REFERENCE_BLOCK_HASH,
                blobHashes
            ),
            expected
        );

        vm.chainId(block.chainid + 1);
        assertNotEq(
            etnaInbox.hashLandStatement(
                9,
                genesisHeight,
                genesisBlockHash,
                COMMITTEE_RECORD_0,
                input,
                L1_REFERENCE_BLOCK_HASH,
                blobHashes
            ),
            expected,
            "chain id bound"
        );
    }

    /// @dev The vector shared with the guest and the lander: any change to the statement
    /// encoding breaks it.
    function test_hashLandStatement_MatchesTheFixedVector() external {
        vm.chainId(1);
        address vectorInbox = 0x1111111111111111111111111111111111111111;
        IEtnaInbox.Config memory config = etnaConfig;
        config.stakingRegistry = 0x2222222222222222222222222222222222222222;
        EtnaInbox vectorImplementation = new EtnaInbox(config);
        // The raw hash helper reads only address(this), chain ID and implementation immutables.
        // Etching configured runtime pins the address without initialization or storage fixtures.
        // Foundry resets this code and the chain ID after this test.
        vm.etch(vectorInbox, address(vectorImplementation).code);

        IEtnaInbox.CommitteeRecord[] memory records = new IEtnaInbox.CommitteeRecord[](2);
        records[0] = IEtnaInbox.CommitteeRecord({ epoch: 1, recordHash: bytes32(uint256(0x55)) });
        records[1] = IEtnaInbox.CommitteeRecord({ epoch: 2, recordHash: bytes32(uint256(0x66)) });
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: 164,
            lastBlockHash: bytes32(uint256(0x22)),
            lastStateRoot: bytes32(uint256(0x33)),
            l1ReferenceBlockNumber: 19_000_000,
            records: records
        });
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = bytes32(uint256(0x01aa));
        blobHashes[1] = bytes32(uint256(0x01bb));

        // The two inner hashes, for implementations of the encoding.
        assertEq(
            keccak256(abi.encode(records)),
            0x0fc2fb3087e71a5875752ba977cada62484ec8f9e897200fc61fde95b414fff1,
            "records hash"
        );
        assertEq(
            keccak256(abi.encodePacked(blobHashes)),
            0xe7591a4eb3dcfdc958b08bf3db6054ebae1f9b1a82b8c685499c13314381ea64,
            "blob hashes hash"
        );

        // block.chainid = 1, l2ChainId = 167001, generation = 3, parent = (100, 0x11),
        // starting committee = 0x77, l1ReferenceBlockHash = 0x44,
        // Inbox = 0x1111...1111, Registry = 0x2222...2222.
        // Independently generated with ethers ABI/Keccak; the V3 preimage is 16 words (512 bytes).
        assertEq(
            EtnaInbox(vectorInbox)
                .hashLandStatement(
                    3,
                    100,
                    bytes32(uint256(0x11)),
                    bytes32(uint256(0x77)),
                    input,
                    bytes32(uint256(0x44)),
                    blobHashes
                ),
            0x90607f5e39a9f1a365d93fbf59a9397c3243e004182898c0c8db284ae190a56b,
            "statement hash"
        );
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _batch(
        uint64 _lastHeight,
        IEtnaInbox.CommitteeRecord[] memory _records
    )
        internal
        view
        returns (IEtnaInbox.LandInput memory)
    {
        return IEtnaInbox.LandInput({
            lastHeight: _lastHeight,
            lastBlockHash: keccak256(abi.encode("l2 block", _lastHeight)),
            lastStateRoot: keccak256(abi.encode("l2 state", _lastHeight)),
            l1ReferenceBlockNumber: l1ReferenceBlockNumber,
            records: _records
        });
    }

    function _recordRange(
        uint64 _firstEpoch,
        uint256 _count
    )
        internal
        pure
        returns (IEtnaInbox.CommitteeRecord[] memory records_)
    {
        records_ = new IEtnaInbox.CommitteeRecord[](_count);
        for (uint256 i; i < _count; ++i) {
            uint64 epoch = _firstEpoch + uint64(i);
            records_[i] =
                IEtnaInbox.CommitteeRecord({ epoch: epoch, recordHash: _recordHash(epoch) });
        }
    }

    function _recordHash(uint64 _epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode("committee record", _epoch));
    }

    /// @dev The statement of a batch referencing `L1_REFERENCE_BLOCK_HASH` with `blobCount` blobs.
    function _statement(
        uint64 _parentHeight,
        bytes32 _parentHash,
        IEtnaInbox.LandInput memory _input
    )
        internal
        view
        returns (bytes32)
    {
        return _manualStatement(
            _parentHeight,
            _parentHash,
            etnaInbox.committee(_parentHeight / EPOCH_LEN_L2),
            _input,
            L1_REFERENCE_BLOCK_HASH
        );
    }

    /// @dev Independently encodes the expected V3 public statement for generation zero.
    function _manualStatement(
        uint64 _parentHeight,
        bytes32 _parentHash,
        bytes32 _startCommitteeRecordHash,
        IEtnaInbox.LandInput memory _input,
        bytes32 _l1ReferenceBlockHash
    )
        internal
        view
        returns (bytes32)
    {
        return _manualStatementForAddresses(
            address(etnaInbox),
            address(registry),
            _parentHeight,
            _parentHash,
            _startCommitteeRecordHash,
            _input,
            _l1ReferenceBlockHash
        );
    }

    /// @dev Concatenating static ABI words preserves the exact flat V3 encoding.
    function _manualStatementForAddresses(
        address _inbox,
        address _registry,
        uint64 _parentHeight,
        bytes32 _parentHash,
        bytes32 _startCommitteeRecordHash,
        IEtnaInbox.LandInput memory _input,
        bytes32 _l1ReferenceBlockHash
    )
        internal
        view
        returns (bytes32)
    {
        bytes memory context = abi.encode(
            bytes32("TAIKO_ETNA_LAND_V3"), block.chainid, L2_CHAIN_ID, _inbox, _registry
        );
        context = bytes.concat(
            context, abi.encode(uint64(0), _parentHeight, _parentHash, _startCommitteeRecordHash)
        );
        return keccak256(
            bytes.concat(
                context,
                abi.encode(
                    _input.lastHeight,
                    _input.lastBlockHash,
                    _input.lastStateRoot,
                    _input.l1ReferenceBlockNumber,
                    _l1ReferenceBlockHash,
                    keccak256(abi.encode(_input.records)),
                    keccak256(abi.encodePacked(_getBlobHashes(blobCount)))
                )
            )
        );
    }

    /// @dev Rejects the supplied proof statement and checks every attempted landing write reverted.
    function _rejectStatementAndAssertRollback(
        IEtnaInbox.LandInput memory _input,
        bytes32 _wrongStatement
    )
        internal
    {
        landVerifier.setExpectedStatementHash(_wrongStatement);
        _expectLandRevert(_input, MockLandProofVerifier.ProofRejected.selector);
        _assertLastCheckpoint(0, genesisBlockHash);
        assertEq(etnaInbox.committee(0), COMMITTEE_RECORD_0, "trusted root retained");
        assertEq(etnaInbox.committee(1), bytes32(0), "first output reverted");
        assertEq(etnaInbox.committee(2), bytes32(0), "second output reverted");
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(uint48(_input.lastHeight));
    }

    function _landExpectingStartingCommittee(
        IEtnaInbox.LandInput memory _input,
        bytes32 _startingRecordHash
    )
        internal
    {
        IEtnaInbox.LandedCheckpoint memory parent = etnaInbox.lastCheckpoint();
        bytes32 expected = _manualStatement(
            parent.height, parent.blockHash, _startingRecordHash, _input, L1_REFERENCE_BLOCK_HASH
        );
        landVerifier.setExpectedStatementHash(expected);
        vm.expectCall(
            address(landVerifier), abi.encodeCall(IProofVerifier.verifyProof, (0, expected, PROOF))
        );
        _land(_input);
    }

    function _land(IEtnaInbox.LandInput memory _input) internal {
        vm.blobhashes(_getBlobHashes(blobCount));
        vm.prank(Bob);
        etnaInbox.land(_input, PROOF);
    }

    function _landExpectingL1ReferenceBlock(
        IEtnaInbox.LandInput memory _input,
        bytes32 _l1ReferenceBlockHash
    )
        internal
    {
        IEtnaInbox.LandedCheckpoint memory parent = etnaInbox.lastCheckpoint();
        bytes32 statementHash = etnaInbox.hashLandStatement(
            0,
            parent.height,
            parent.blockHash,
            etnaInbox.committee(parent.height / EPOCH_LEN_L2),
            _input,
            _l1ReferenceBlockHash,
            _getBlobHashes(blobCount)
        );
        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statementHash, PROOF))
        );
        _land(_input);
    }

    function _expectLandRevert(IEtnaInbox.LandInput memory _input, bytes4 _selector) internal {
        vm.blobhashes(_getBlobHashes(blobCount));
        vm.expectRevert(_selector);
        vm.prank(Bob);
        etnaInbox.land(_input, PROOF);
    }

    function _plantHistory(uint256 _number, bytes32 _hash) internal {
        vm.etch(HISTORY_STORAGE, HISTORY_STORAGE_CODE);
        vm.store(HISTORY_STORAGE, bytes32(_number % 8191), _hash);
    }

    function _assertLastCheckpoint(uint64 _height, bytes32 _blockHash) internal view {
        IEtnaInbox.LandedCheckpoint memory checkpoint = etnaInbox.lastCheckpoint();
        assertEq(checkpoint.height, _height, "checkpoint height");
        assertEq(checkpoint.blockHash, _blockHash, "checkpoint hash");
        assertEq(_loadSlot(LAST_CHECKPOINT_SLOT), _height, "slot 270");
        assertEq(bytes32(_loadSlot(LAST_CHECKPOINT_SLOT + 1)), _blockHash, "slot 271");
    }

    function _assertSignalCheckpoint(IEtnaInbox.LandInput memory _input) internal view {
        ICheckpointStore.Checkpoint memory saved =
            signalService.getCheckpoint(uint48(_input.lastHeight));
        assertEq(saved.blockHash, _input.lastBlockHash, "saved block hash");
        assertEq(saved.stateRoot, _input.lastStateRoot, "saved state root");
    }
}

/// @notice An uninitialized proxy cannot land a batch.
contract EtnaInboxLandBeforeInitializationTest is EtnaInboxTestBase {
    function _initializeOnDeploy() internal pure override returns (bool) {
        return false;
    }

    function test_land_RevertWhen_EtnaNotActive() external {
        vm.blobhashes(_getBlobHashes(1));
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: genesisHeight + 1,
            lastBlockHash: keccak256("block"),
            lastStateRoot: keccak256("state"),
            l1ReferenceBlockNumber: uint64(block.number - 1),
            records: new IEtnaInbox.CommitteeRecord[](0)
        });

        vm.expectRevert(EtnaInbox.EtnaNotActive.selector);
        etnaInbox.land(input, "");
    }
}
