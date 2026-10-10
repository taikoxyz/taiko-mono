// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase, MockLandProofVerifier } from "./EtnaInboxTestBase.sol";
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
    bytes32 internal constant ANCHOR_HASH = keccak256("anchor");
    bytes internal constant PROOF = "etna proof";

    /// @dev The anchor block number of every batch built by `_batch`.
    uint64 internal anchorNumber;
    /// @dev The number of blobs `_land` attaches to the landing transaction.
    uint256 internal blobCount = 2;

    function setUp() public override {
        super.setUp();
        _activate();

        vm.roll(L1_HEAD);
        anchorNumber = L1_HEAD - 1;
        vm.setBlockhash(anchorNumber, ANCHOR_HASH);
    }

    // ---------------------------------------------------------------
    // Happy paths
    // ---------------------------------------------------------------

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
            anchorNumber,
            statementHash,
            Bob
        );
        _land(input);

        _assertLastCheckpoint(lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);
        assertEq(etnaInbox.committee(1), _recordHash(1), "committee 1");
        assertEq(vm.load(address(inbox), _committeeSlot(1)), _recordHash(1), "slot of committee 1");
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
            anchorNumber,
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
        // h_first(0) = B* + 1 and h_first(1) = B* + 11 = lastHeight.
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
        vm.store(address(inbox), bytes32(RECOVERY_GENERATION_SLOT), bytes32(uint256(5)));
        assertEq(etnaInbox.recoveryGeneration(), 5, "generation");

        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 5, _recordRange(1, 1));
        bytes32 statementHash = etnaInbox.hashLandStatement(
            5, genesisHeight, genesisBlockHash, input, ANCHOR_HASH, _getBlobHashes(2)
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
            0, genesisHeight, genesisBlockHash, input, ANCHOR_HASH, _getBlobHashes(3)
        );
        bytes32 twoBlobStatementHash = etnaInbox.hashLandStatement(
            0, genesisHeight, genesisBlockHash, input, ANCHOR_HASH, _getBlobHashes(2)
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
        vm.store(address(inbox), _committeeSlot(1), keccak256("stale"));

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)),
            EtnaInbox.CommitteeAlreadyRecorded.selector
        );
    }

    // ---------------------------------------------------------------
    // Anchor
    // ---------------------------------------------------------------

    function test_land_ReadsTheAnchorFromBlockhash() external {
        anchorNumber = L1_HEAD - 256;
        bytes32 anchorHash = keccak256("oldest blockhash");
        vm.setBlockhash(anchorNumber, anchorHash);
        _plantHistory(anchorNumber, keccak256("history"));

        _landExpectingAnchor(_batch(genesisHeight + 5, _recordRange(1, 1)), anchorHash);
    }

    function test_land_ReadsTheAnchorFromTheHistoryContract() external {
        anchorNumber = L1_HEAD - 257;
        bytes32 anchorHash = keccak256("history 257");
        _plantHistory(anchorNumber, anchorHash);
        _landExpectingAnchor(_batch(genesisHeight + 5, _recordRange(1, 1)), anchorHash);

        anchorNumber = L1_HEAD - 8191;
        anchorHash = keccak256("history 8191");
        _plantHistory(anchorNumber, anchorHash);
        _landExpectingAnchor(_batch(genesisHeight + 10, _recordRange(2, 0)), anchorHash);
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
        anchorNumber = L1_HEAD - 8192;
        _plantHistory(anchorNumber, keccak256("too old"));

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    function test_land_RevertWhen_AnchorNotInThePast() external {
        anchorNumber = L1_HEAD;
        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );

        anchorNumber = L1_HEAD + 1;
        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    function test_land_RevertWhen_BlockhashIsZero() external {
        anchorNumber = L1_HEAD - 2;
        vm.setBlockhash(anchorNumber, 0);

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    function test_land_RevertWhen_HistoryHashIsZero() external {
        anchorNumber = L1_HEAD - 300;
        _plantHistory(anchorNumber, 0);

        _expectLandRevert(
            _batch(genesisHeight + 5, _recordRange(1, 1)), EtnaInbox.AnchorUnavailable.selector
        );
    }

    function test_land_RevertWhen_HistoryContractMissing() external {
        assertEq(HISTORY_STORAGE.code.length, 0, "no history contract");
        anchorNumber = L1_HEAD - 300;

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
        _expectLandRevert(
            _batch(genesisHeight - 1, _recordRange(1, 0)), EtnaInbox.NoProgress.selector
        );
    }

    function test_land_RevertWhen_BatchTooLarge() external {
        _expectLandRevert(
            _batch(genesisHeight + MAX_BATCH_BLOCKS + 1, _recordRange(1, 101)),
            EtnaInbox.BatchTooLarge.selector
        );
    }

    function test_land_RevertWhen_HeightOverflow() external {
        etnaConfig.maxBatchBlocks = type(uint64).max;
        inbox.upgradeTo(address(new EtnaInbox(etnaConfig)));

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

    function test_hashLandStatement_EncodesTheSpecifiedFields() external {
        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 11, _recordRange(1, 2));
        bytes32[] memory blobHashes = _getBlobHashes(3);

        bytes32 expected = keccak256(
            abi.encode(
                bytes32("TAIKO_ETNA_LAND_V1"),
                block.chainid,
                L2_CHAIN_ID,
                uint64(9),
                genesisHeight,
                genesisBlockHash,
                input.lastHeight,
                input.lastBlockHash,
                input.lastStateRoot,
                input.anchorNumber,
                ANCHOR_HASH,
                keccak256(abi.encode(input.records)),
                keccak256(abi.encodePacked(blobHashes))
            )
        );
        assertEq(
            etnaInbox.hashLandStatement(
                9, genesisHeight, genesisBlockHash, input, ANCHOR_HASH, blobHashes
            ),
            expected
        );

        vm.chainId(block.chainid + 1);
        assertNotEq(
            etnaInbox.hashLandStatement(
                9, genesisHeight, genesisBlockHash, input, ANCHOR_HASH, blobHashes
            ),
            expected,
            "chain id bound"
        );
    }

    /// @dev The vector shared with the guest and the lander: any change to the statement
    /// encoding breaks it.
    function test_hashLandStatement_MatchesTheFixedVector() external {
        vm.chainId(1);

        IEtnaInbox.CommitteeRecord[] memory records = new IEtnaInbox.CommitteeRecord[](2);
        records[0] = IEtnaInbox.CommitteeRecord({ epoch: 1, recordHash: bytes32(uint256(0x55)) });
        records[1] = IEtnaInbox.CommitteeRecord({ epoch: 2, recordHash: bytes32(uint256(0x66)) });
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: 164,
            lastBlockHash: bytes32(uint256(0x22)),
            lastStateRoot: bytes32(uint256(0x33)),
            anchorNumber: 19_000_000,
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
        // anchorHash = 0x44.
        assertEq(
            etnaInbox.hashLandStatement(
                3, 100, bytes32(uint256(0x11)), input, bytes32(uint256(0x44)), blobHashes
            ),
            0x1a092efe65ea68bacc83192c377e867459e47c98926da507dc5b4164f4443a69,
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
            anchorNumber: anchorNumber,
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

    /// @dev The statement of a batch anchored at `ANCHOR_HASH` with `blobCount` blobs.
    function _statement(
        uint64 _parentHeight,
        bytes32 _parentHash,
        IEtnaInbox.LandInput memory _input
    )
        internal
        view
        returns (bytes32)
    {
        return etnaInbox.hashLandStatement(
            0, _parentHeight, _parentHash, _input, ANCHOR_HASH, _getBlobHashes(blobCount)
        );
    }

    function _land(IEtnaInbox.LandInput memory _input) internal {
        vm.blobhashes(_getBlobHashes(blobCount));
        vm.prank(Bob);
        etnaInbox.land(_input, PROOF);
    }

    function _landExpectingAnchor(
        IEtnaInbox.LandInput memory _input,
        bytes32 _anchorHash
    )
        internal
    {
        IEtnaInbox.LandedCheckpoint memory parent = etnaInbox.lastCheckpoint();
        bytes32 statementHash = etnaInbox.hashLandStatement(
            0, parent.height, parent.blockHash, _input, _anchorHash, _getBlobHashes(blobCount)
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

/// @notice `land` before `activateEtna`.
contract EtnaInboxLandBeforeActivationTest is EtnaInboxTestBase {
    function test_land_RevertWhen_EtnaNotActive() external {
        vm.blobhashes(_getBlobHashes(1));
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: genesisHeight + 1,
            lastBlockHash: keccak256("block"),
            lastStateRoot: keccak256("state"),
            anchorNumber: uint64(block.number - 1),
            records: new IEtnaInbox.CommitteeRecord[](0)
        });

        vm.expectRevert(EtnaInbox.EtnaNotActive.selector);
        etnaInbox.land(input, "");
    }
}
