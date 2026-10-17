// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase, MockLandProofVerifier } from "./EtnaInboxTestBase.sol";
import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @notice Lands a batch naming itself the fee recipient and, from `receive()`, re-enters the
/// Inbox with a prepared call: `land` or `saveForcedInclusion`.
contract ReentrantLander {
    EtnaInbox private immutable _inbox;
    bytes private _reentryCall;
    uint256 private _reentryValue;
    bool private _catchReentry;
    bool public reentrySucceeded;
    bytes public reentryError;

    constructor(EtnaInbox _target) {
        _inbox = _target;
    }

    function land(
        IEtnaInbox.LandInput calldata _input,
        bytes calldata _reentry,
        uint256 _value,
        bool _catch
    )
        external
    {
        (_reentryCall, _reentryValue, _catchReentry) = (_reentry, _value, _catch);
        _inbox.land(_input, "etna proof");
    }

    receive() external payable {
        (bool success, bytes memory reason) =
            address(_inbox).call{ value: _reentryValue }(_reentryCall);
        if (!_catchReentry && !success) {
            assembly {
                revert(add(reason, 32), mload(reason))
            }
        }
        (reentrySucceeded, reentryError) = (success, reason);
    }
}

/// @notice Rejects L1 fee transfers to exercise landing rollback and zero-fee behavior.
contract RejectingFeeRecipient {
    /// @notice Rejects every incoming fee transfer.
    receive() external payable {
        revert();
    }
}

contract EtnaInboxLandTest is EtnaInboxTestBase {
    /// @dev The EIP-2935 history storage contract and its runtime code.
    address internal constant HISTORY_STORAGE = 0x0000F90827F1C53a10cb7A02335B175320002935;
    bytes internal constant HISTORY_STORAGE_CODE = hex"3373fffffffffffffffffffffffffffffffffffffffe"
        hex"14604657602036036042575f35600143038111"
        hex"604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500";

    uint64 internal constant L1_HEAD = 20_000;
    bytes32 internal constant L1_REFERENCE_BLOCK_HASH = keccak256("anchor");
    bytes internal constant PROOF = "etna proof";

    /// @dev The L1 reference block number of every batch built by `_batch`.
    uint64 internal l1ReferenceBlockNumber;
    /// @dev The number of blobs `_land` attaches to the landing transaction.
    uint256 internal blobCount = 2;

    function test_land_RecordsV8ReceiptWithoutFunding() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        input.l2RewardRecipient = Alice;
        input.baseFeeAmount = 1 ether;
        IEtnaInbox.LandedCheckpoint memory parent = etnaInbox.lastCheckpoint();
        assertEq(parent.height, 0);
        assertEq(parent.blockHash, genesisBlockHash);
        vm.blobhashes(_getBlobHashes(blobCount));
        etnaInbox.land(input, PROOF);
        assertEq(address(etnaInbox).balance, 0);
        bytes32 id = keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_BATCH_V1"),
                block.chainid,
                L2_CHAIN_ID,
                address(etnaInbox),
                uint64(0),
                parent.height,
                parent.blockHash,
                input.lastHeight,
                input.lastBlockHash
            )
        );
        bytes32 expected = keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_RECEIPT_V1"),
                id,
                input.l2RewardRecipient,
                input.baseFeeAmount
            )
        );
        assertEq(etnaInbox.rewardCommitments(id), expected);
        assertEq(vm.load(address(etnaInbox), keccak256(abi.encode(id, uint256(283)))), expected);
    }

    function setUp() public override {
        super.setUp();

        vm.roll(L1_HEAD);
        l1ReferenceBlockNumber = L1_HEAD - 1;
        vm.setBlockhash(l1ReferenceBlockNumber, L1_REFERENCE_BLOCK_HASH);
    }

    /// @dev The former nineteen-word V7 statement cannot authorize a V8 landing.
    function test_land_RevertWhen_ProofUsesAFormerStatement() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        bytes memory words = _manualPreimage(
            address(etnaInbox),
            address(registry),
            0,
            genesisBlockHash,
            COMMITTEE_CONFIG_HASH,
            input,
            L1_REFERENCE_BLOCK_HASH
        );
        bytes32 oldParticipation = keccak256(abi.encode(uint256(32), uint256(0)));
        bytes32 oldTag = bytes32("TAIKO_ETNA_LAND_V7");
        assembly {
            mstore(add(words, 32), oldTag)
            mstore(add(words, 608), oldParticipation)
            mstore(words, 608)
        }
        _rejectStatementAndAssertRollback(input, keccak256(words));
    }

    /// @dev Requiring any future committee publication would block this valid checkpoint advance.
    function test_land_CrossesEpochBoundariesWithoutCommitteeRecords() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertLastCheckpoint(11, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_NeverReadsOrWritesAFutureCommitteeSlot() external {
        vm.record();
        _land(_batch(31));
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(etnaInbox));
        for (uint64 epoch; epoch <= 4; ++epoch) {
            bytes32 legacySlot = _legacyCommitteeSlot(epoch);
            for (uint256 i; i < reads.length; ++i) {
                assertNotEq(reads[i], legacySlot, "no legacy mapping read");
            }
            for (uint256 i; i < writes.length; ++i) {
                assertNotEq(writes[i], legacySlot, "no legacy mapping write");
            }
            assertEq(vm.load(address(etnaInbox), legacySlot), bytes32(0), "legacy slot untouched");
        }
        assertEq(etnaInbox.genesisCommitteeRecordHash(), COMMITTEE_RECORD_0, "bootstrap retained");
        assertEq(etnaInbox.committeeConfigHash(), COMMITTEE_CONFIG_HASH, "config retained");
    }

    function test_land_LandsAcrossBothSidesOfEpochAndSwitchBoundaries() external {
        uint64[9] memory cuts = [uint64(5), 8, 9, 10, 11, 12, 19, 21, 31];
        for (uint256 i; i < cuts.length; ++i) {
            IEtnaInbox.LandInput memory input = _batch(cuts[i]);
            _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
            _assertLastCheckpoint(input.lastHeight, input.lastBlockHash);
            _assertSignalCheckpoint(input);
        }
    }

    function testFuzz_land_LandsArbitraryContiguousCuts(
        uint64 _parentSeed,
        uint64 _spanSeed
    )
        external
    {
        uint64 parentHeight = uint64(bound(_parentSeed, 0, 100));
        uint64 lastHeight = parentHeight + uint64(bound(_spanSeed, 1, 40));
        if (parentHeight != 0) _land(_batch(parentHeight));
        IEtnaInbox.LandInput memory input = _batch(lastHeight);
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertLastCheckpoint(lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_LandsTheFirstBatch() external {
        IEtnaInbox.LandInput memory input = _batch(5);
        bytes32 statement = _statement(0, genesisBlockHash, input);
        landVerifier.setExpectedStatementHash(statement);
        vm.expectCall(
            address(landVerifier), abi.encodeCall(IProofVerifier.verifyProof, (0, statement, PROOF))
        );
        vm.expectEmit();
        emit ICheckpointStore.CheckpointSaved(5, input.lastBlockHash, input.lastStateRoot);
        vm.expectEmit();
        emit IEtnaInbox.BatchLanded(
            1, 5, input.lastBlockHash, input.lastStateRoot, l1ReferenceBlockNumber, statement, Bob
        );
        _land(input);
        _assertLastCheckpoint(5, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_AcceptsTheLargestBatch() external {
        IEtnaInbox.LandInput memory input = _batch(MAX_BATCH_BLOCKS);
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertLastCheckpoint(MAX_BATCH_BLOCKS, input.lastBlockHash);
    }

    function test_land_BindsTheStoredConfiguration() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32 original = _statement(0, genesisBlockHash, input);
        bytes32 changed = keccak256("different config");
        vm.store(address(etnaInbox), bytes32(COMMITTEE_CONFIG_SLOT), changed);
        _rejectStatementAndAssertRollback(input, original);
        _landExpectingConfig(input, changed);
        _assertLastCheckpoint(11, input.lastBlockHash);
    }

    function test_land_RejectsAProofForCallerChosenCheckpointAndRollsBack() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32 wrong = _manualStatement(
            1, keccak256("caller parent"), COMMITTEE_CONFIG_HASH, input, L1_REFERENCE_BLOCK_HASH
        );
        _rejectStatementAndAssertRollback(input, wrong);
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
    }

    function test_land_RejectsAV3ProofAndRollsBack() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes memory context = abi.encode(
            bytes32("TAIKO_ETNA_LAND_V3"),
            block.chainid,
            L2_CHAIN_ID,
            address(etnaInbox),
            address(registry),
            uint64(0),
            uint64(0),
            genesisBlockHash,
            COMMITTEE_RECORD_0
        );
        // V3's empty dynamic-array hash still includes the offset and length words.
        bytes32 legacy = keccak256(
            bytes.concat(
                context,
                abi.encode(
                    input.lastHeight,
                    input.lastBlockHash,
                    input.lastStateRoot,
                    input.l1ReferenceBlockNumber,
                    L1_REFERENCE_BLOCK_HASH,
                    keccak256(abi.encode(uint256(32), uint256(0))),
                    keccak256(abi.encodePacked(_getBlobHashes(blobCount)))
                )
            )
        );
        _rejectStatementAndAssertRollback(input, legacy);
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
    }

    /// @dev Mutates each of twenty public words with nonzero queue heads and verifies rollback.
    function test_land_RejectsEveryMutatedV8FieldAndRollsBack() external {
        _saveForcedInclusions(3);
        _landConsuming(_batch(2), 1);
        IEtnaInbox.LandInput memory input = _batch(11);
        input.forcedInclusionHead = 3;
        bytes memory words = _manualPreimage(
            address(etnaInbox),
            address(registry),
            2,
            _batch(2).lastBlockHash,
            COMMITTEE_CONFIG_HASH,
            input,
            L1_REFERENCE_BLOCK_HASH
        );
        assertEq(words.length, 640, "twenty static words");
        assertEq(_word(words, 0), bytes32("TAIKO_ETNA_LAND_V8"), "word 1: V8 domain");
        assertEq(uint256(_word(words, 15)), 1, "word 16: head before");
        assertEq(uint256(_word(words, 16)), 3, "word 17: head after");
        assertEq(address(uint160(uint256(_word(words, 17)))), Bob, "word 18: fee recipient");
        assertEq(address(uint160(uint256(_word(words, 18)))), Alice, "word 19: L2 recipient");
        assertEq(uint256(_word(words, 19)), input.baseFeeAmount, "word 20: amount");
        bytes32 expected = keccak256(words);
        for (uint256 i; i < 20; ++i) {
            uint256 lastByte = 32 * i + 31;
            words[lastByte] = bytes1(uint8(words[lastByte]) ^ 1);
            assertNotEq(keccak256(words), expected, "every word changes the hash");
            _rejectStatementAndAssertRollback(input, keccak256(words));
            words[lastByte] = bytes1(uint8(words[lastByte]) ^ 1);
        }
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertForcedInclusionState(3, 3);
    }

    function test_land_BindsTheProxyAndConfiguredRegistryIndependentlyOfTheCaller() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32 expected = _manualStatement(
            0, genesisBlockHash, COMMITTEE_CONFIG_HASH, input, L1_REFERENCE_BLOCK_HASH
        );
        assertNotEq(
            expected,
            _manualStatementForAddresses(
                address(etnaImplementation),
                address(registry),
                0,
                genesisBlockHash,
                COMMITTEE_CONFIG_HASH,
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
                COMMITTEE_CONFIG_HASH,
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
        _landAs(Carol, input);
        _assertLastCheckpoint(input.lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);

        assertTrue(vm.revertToStateAndDelete(snapshot), "restored the same landing input");
        _land(input); // Bob submits the identical proof after Carol's execution was reverted.
        _assertLastCheckpoint(input.lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_RejectsAProofForAnotherInboxAndRollsBack() external {
        EtnaInbox otherInbox = EtnaInbox(payable(new ERC1967Proxy(address(etnaImplementation), "")));
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32 wrongStatement = _manualStatementForAddresses(
            address(otherInbox),
            address(registry),
            0,
            genesisBlockHash,
            COMMITTEE_CONFIG_HASH,
            input,
            L1_REFERENCE_BLOCK_HASH
        );
        _rejectStatementAndAssertRollback(input, wrongStatement);
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertSignalCheckpoint(input);
    }

    function test_land_RejectsAProofForThePreviousRegistryAndRollsBack() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32 previousStatement = _manualStatement(
            0, genesisBlockHash, COMMITTEE_CONFIG_HASH, input, L1_REFERENCE_BLOCK_HASH
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
            COMMITTEE_CONFIG_HASH,
            input,
            L1_REFERENCE_BLOCK_HASH
        );
        landVerifier.setExpectedStatementHash(expected);
        _land(input);
        _assertLastCheckpoint(input.lastHeight, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_BindsTheRecoveryGeneration() external {
        vm.store(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT), bytes32(uint256(5)));
        assertEq(etnaInbox.recoveryGeneration(), 5, "generation");

        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 5);
        bytes32 statementHash = etnaInbox.hashLandStatement(
            5, genesisHeight, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, _getBlobHashes(2)
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
        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 5);
        bytes32 statementHash = etnaInbox.hashLandStatement(
            0, genesisHeight, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, _getBlobHashes(3)
        );
        bytes32 twoBlobStatementHash = etnaInbox.hashLandStatement(
            0, genesisHeight, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, _getBlobHashes(2)
        );
        assertNotEq(statementHash, twoBlobStatementHash, "third blob bound");

        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, statementHash, PROOF))
        );
        _land(input);
    }

    function test_land_ReadsTheAnchorFromBlockhash() external {
        l1ReferenceBlockNumber = L1_HEAD - 256;
        bytes32 l1ReferenceBlockHash = keccak256("oldest blockhash");
        vm.setBlockhash(l1ReferenceBlockNumber, l1ReferenceBlockHash);
        _plantHistory(l1ReferenceBlockNumber, keccak256("history"));

        _landExpectingL1ReferenceBlock(_batch(genesisHeight + 5), l1ReferenceBlockHash);
    }

    function test_land_ReadsTheAnchorFromTheHistoryContract() external {
        l1ReferenceBlockNumber = L1_HEAD - 257;
        bytes32 l1ReferenceBlockHash = keccak256("history 257");
        _plantHistory(l1ReferenceBlockNumber, l1ReferenceBlockHash);
        _landExpectingL1ReferenceBlock(_batch(genesisHeight + 5), l1ReferenceBlockHash);

        l1ReferenceBlockNumber = L1_HEAD - 8191;
        l1ReferenceBlockHash = keccak256("history 8191");
        _plantHistory(l1ReferenceBlockNumber, l1ReferenceBlockHash);
        _landExpectingL1ReferenceBlock(_batch(genesisHeight + 10), l1ReferenceBlockHash);
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

        _expectLandRevert(_batch(genesisHeight + 5), EtnaInbox.AnchorUnavailable.selector);
    }

    function test_land_RevertWhen_AnchorNotInThePast() external {
        l1ReferenceBlockNumber = L1_HEAD;
        _expectLandRevert(_batch(genesisHeight + 5), EtnaInbox.AnchorUnavailable.selector);

        l1ReferenceBlockNumber = L1_HEAD + 1;
        _expectLandRevert(_batch(genesisHeight + 5), EtnaInbox.AnchorUnavailable.selector);
    }

    function test_land_RevertWhen_BlockhashIsZero() external {
        l1ReferenceBlockNumber = L1_HEAD - 2;
        vm.setBlockhash(l1ReferenceBlockNumber, 0);

        _expectLandRevert(_batch(genesisHeight + 5), EtnaInbox.AnchorUnavailable.selector);
    }

    function test_land_RevertWhen_HistoryHashIsZero() external {
        l1ReferenceBlockNumber = L1_HEAD - 300;
        _plantHistory(l1ReferenceBlockNumber, 0);

        _expectLandRevert(_batch(genesisHeight + 5), EtnaInbox.AnchorUnavailable.selector);
    }

    function test_land_RevertWhen_HistoryContractMissing() external {
        assertEq(HISTORY_STORAGE.code.length, 0, "no history contract");
        l1ReferenceBlockNumber = L1_HEAD - 300;

        _expectLandRevert(_batch(genesisHeight + 5), EtnaInbox.AnchorUnavailable.selector);
    }

    function test_land_RevertWhen_NoBlobs() external {
        blobCount = 0;

        _expectLandRevert(_batch(genesisHeight + 5), EtnaInbox.BlobsRequired.selector);
    }

    function test_land_RevertWhen_NoProgress() external {
        _expectLandRevert(_batch(genesisHeight), EtnaInbox.NoProgress.selector);
        _land(_batch(5));
        _expectLandRevert(_batch(4), EtnaInbox.NoProgress.selector);
    }

    function test_land_RevertWhen_BatchTooLarge() external {
        _expectLandRevert(
            _batch(genesisHeight + MAX_BATCH_BLOCKS + 1), EtnaInbox.BatchTooLarge.selector
        );
    }

    function test_land_RevertWhen_HeightOverflow() external {
        etnaConfig.maxBatchBlocks = type(uint64).max;
        etnaInbox.upgradeTo(address(new EtnaInbox(etnaConfig)));

        _expectLandRevert(_batch(uint64(type(uint48).max) + 1), EtnaInbox.HeightOverflow.selector);
    }

    function test_land_RevertWhen_ProofRejected() external {
        landVerifier.setRejects(true);
        IEtnaInbox.LandInput memory input = _batch(genesisHeight + 5);

        _expectLandRevert(input, MockLandProofVerifier.ProofRejected.selector);

        _assertLastCheckpoint(genesisHeight, genesisBlockHash);
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(uint48(input.lastHeight));
    }

    /// @dev Bob lands a batch whose statement names Carol: the fees go to Carol, not the caller.
    function test_land_AdvancesForcedInclusionHeadAndPaysTheFeeRecipient() external {
        uint64[] memory fees = _saveForcedInclusions(2);
        assertGt(fees[1], fees[0], "the fee grows with the queue");
        uint256 feesWei = (uint256(fees[0]) + uint256(fees[1])) * 1 gwei;
        uint256 inboxBefore = address(etnaInbox).balance;
        uint256 landerBefore = Bob.balance;
        uint256 recipientBefore = Carol.balance;
        assertEq(inboxBefore, feesWei, "the Inbox holds both fees");

        IEtnaInbox.LandInput memory input = _batch(3);
        input.forcedInclusionHead = 2;
        input.feeRecipient = Carol;
        bytes32 statement = _statement(0, genesisBlockHash, input);
        landVerifier.setExpectedStatementHash(statement);
        vm.expectCall(
            address(landVerifier), abi.encodeCall(IProofVerifier.verifyProof, (0, statement, PROOF))
        );
        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.BatchLanded(
            1, 3, input.lastBlockHash, input.lastStateRoot, l1ReferenceBlockNumber, statement, Bob
        );
        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.ForcedInclusionsConsumed(0, 2, feesWei, Carol);
        _land(input);

        _assertForcedInclusionState(2, 2);
        assertEq(Carol.balance - recipientBefore, feesWei, "recipient paid both fees");
        assertEq(Bob.balance, landerBefore, "the caller is not paid");
        assertEq(inboxBefore - address(etnaInbox).balance, feesWei, "Inbox paid out both fees");
        assertEq(bytes32(_loadSlot(_entrySlot(0))), keccak256(hex"c0"), "consumed entry 0 kept");
        assertEq(uint64(_loadSlot(_entrySlot(0) + 1) >> 112), fees[0], "consumed fee 0 kept");
        assertEq(bytes32(_loadSlot(_entrySlot(1))), keccak256(hex"c0"), "consumed entry 1 kept");
        assertEq(uint64(_loadSlot(_entrySlot(1) + 1) >> 112), fees[1], "consumed fee 1 kept");
        _assertLastCheckpoint(3, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_KeepsHeadWithoutForcedInclusions() external {
        _saveForcedInclusions(1);
        uint256 inboxBefore = address(etnaInbox).balance;
        uint256 landerBefore = Bob.balance;

        IEtnaInbox.LandInput memory input = _batch(3);
        assertEq(input.forcedInclusionHead, 0, "the stored head");
        vm.recordLogs();
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertNotEq(logs[i].topics[0], IEtnaInbox.ForcedInclusionsConsumed.selector, "no event");
        }

        _assertForcedInclusionState(0, 1);
        assertEq(Bob.balance, landerBefore, "no transfer");
        assertEq(address(etnaInbox).balance, inboxBefore, "fee retained");
        _assertLastCheckpoint(3, input.lastBlockHash);
    }

    /// @dev A copier that resubmits Bob's public landing (calldata, sidecar and proof) lands
    /// it, but the fees still go to the recipient Bob's statement binds.
    function test_land_PaysTheBoundRecipientWhenAnotherCallerCopiesTheLanding() external {
        uint64[] memory fees = _saveForcedInclusions(2);
        uint256 feesWei = (uint256(fees[0]) + uint256(fees[1])) * 1 gwei;
        uint256 landerBefore = Bob.balance;
        uint256 copierBefore = Carol.balance;

        IEtnaInbox.LandInput memory input = _batch(3);
        input.forcedInclusionHead = 2;
        assertEq(input.feeRecipient, Bob, "Bob's landing names Bob");
        bytes32 statement = _statement(0, genesisBlockHash, input);
        landVerifier.setExpectedStatementHash(statement);
        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.BatchLanded(
            1, 3, input.lastBlockHash, input.lastStateRoot, l1ReferenceBlockNumber, statement, Carol
        );
        vm.expectEmit(address(etnaInbox));
        emit IEtnaInbox.ForcedInclusionsConsumed(0, 2, feesWei, Bob);
        _landAs(Carol, input);

        _assertForcedInclusionState(2, 2);
        assertEq(Bob.balance - landerBefore, feesWei, "the bound recipient is paid");
        assertEq(Carol.balance, copierBefore, "the copier is not paid");
        _expectLandRevert(input, EtnaInbox.NoProgress.selector);
    }

    /// @dev A copier that swaps in its own recipient changes the statement, so Bob's proof no
    /// longer verifies and nothing moves.
    function test_land_RevertWhen_CopierSubstitutesItsFeeRecipient() external {
        _saveForcedInclusions(2);
        IEtnaInbox.LandInput memory input = _batch(3);
        input.forcedInclusionHead = 2;
        bytes32 bobStatement = _statement(0, genesisBlockHash, input);
        input.feeRecipient = Carol;
        assertNotEq(_statement(0, genesisBlockHash, input), bobStatement, "recipient bound");
        uint256 copierBefore = Carol.balance;

        _rejectStatementAndAssertRollback(input, bobStatement);
        assertEq(Carol.balance, copierBefore, "the copier is not paid");

        input.feeRecipient = Bob;
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertForcedInclusionState(2, 2);
    }

    /// @dev A zero recipient is rejected whether or not the batch consumes forced inclusions.
    function test_land_RevertWhen_FeeRecipientIsZero() external {
        IEtnaInbox.LandInput memory input = _batch(3);
        input.feeRecipient = address(0);
        _expectLandRevert(input, EtnaInbox.ZeroFeeRecipient.selector);

        _saveForcedInclusions(1);
        input.forcedInclusionHead = 1;
        _expectLandRevert(input, EtnaInbox.ZeroFeeRecipient.selector);
        _assertForcedInclusionState(0, 1);
        _assertLastCheckpoint(0, genesisBlockHash);
    }

    function test_land_RevertWhen_ForcedInclusionHeadBeyondTail() external {
        IEtnaInbox.LandInput memory input = _batch(3);
        input.forcedInclusionHead = 1;
        _expectLandRevert(input, EtnaInbox.InvalidForcedInclusionHead.selector);

        _saveForcedInclusions(1);
        input.forcedInclusionHead = 2;
        _expectLandRevert(input, EtnaInbox.InvalidForcedInclusionHead.selector);
        input.forcedInclusionHead = type(uint48).max;
        _expectLandRevert(input, EtnaInbox.InvalidForcedInclusionHead.selector);
        _assertForcedInclusionState(0, 1);
        _assertLastCheckpoint(0, genesisBlockHash);

        input.forcedInclusionHead = 1;
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertForcedInclusionState(1, 1);
    }

    function test_land_RevertWhen_ForcedInclusionHeadGoesBack() external {
        _saveForcedInclusions(3);
        _landConsuming(_batch(3), 2);

        IEtnaInbox.LandInput memory input = _batch(6);
        input.forcedInclusionHead = 1;
        _expectLandRevert(input, EtnaInbox.InvalidForcedInclusionHead.selector);
        input.forcedInclusionHead = 0;
        _expectLandRevert(input, EtnaInbox.InvalidForcedInclusionHead.selector);
        _assertForcedInclusionState(2, 3);
        _assertLastCheckpoint(3, _batch(3).lastBlockHash);

        input.forcedInclusionHead = 2;
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertForcedInclusionState(2, 3);
    }

    /// @dev Each forced inclusion is its own L2 block, so a batch consumes at most one entry per
    /// block.
    function test_land_RevertWhen_MoreForcedInclusionsThanBlocks() external {
        _saveForcedInclusions(4);
        IEtnaInbox.LandInput memory input = _batch(2);
        input.forcedInclusionHead = 3;
        _expectLandRevert(input, EtnaInbox.InvalidForcedInclusionHead.selector);
        _assertForcedInclusionState(0, 4);

        input.forcedInclusionHead = 2;
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertForcedInclusionState(2, 4);

        input = _batch(3);
        input.forcedInclusionHead = 4;
        _expectLandRevert(input, EtnaInbox.InvalidForcedInclusionHead.selector);
        input.forcedInclusionHead = 3;
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
        _assertForcedInclusionState(3, 4);
    }

    function test_land_VerifierRejectionRollsBackHeadAndFees() external {
        _saveForcedInclusions(2);
        uint256 inboxBefore = address(etnaInbox).balance;
        uint256 landerBefore = Bob.balance;
        landVerifier.setRejects(true);

        IEtnaInbox.LandInput memory input = _batch(3);
        input.forcedInclusionHead = 2;
        _expectLandRevert(input, MockLandProofVerifier.ProofRejected.selector);

        _assertForcedInclusionState(0, 2);
        assertEq(address(etnaInbox).balance, inboxBefore, "fees retained");
        assertEq(Bob.balance, landerBefore, "nothing paid");
        _assertLastCheckpoint(0, genesisBlockHash);
    }

    /// @dev The fee transfer to the bound recipient is the only external call after verification;
    /// the shared lock makes a re-entering recipient fail the whole landing, or fail alone if it
    /// catches the error.
    function test_land_IsNonReentrantFromFeeRecipient() external {
        ReentrantLander lander = new ReentrantLander(etnaInbox);
        vm.deal(address(lander), 10 ether);
        uint64[] memory fees = _saveForcedInclusions(2);
        uint256 feesWei = (uint256(fees[0]) + uint256(fees[1])) * 1 gwei;
        IEtnaInbox.LandInput memory input = _batch(3);
        input.forcedInclusionHead = 2;
        input.feeRecipient = address(lander);
        bytes[2] memory reentries = [
            abi.encodeCall(IEtnaInbox.land, (_batch(5), PROOF)),
            abi.encodeCall(IEtnaInbox.saveForcedInclusion, (hex"c0"))
        ];
        uint256[2] memory values =
            [uint256(0), uint256(etnaInbox.getCurrentForcedInclusionFee()) * 1 gwei];
        vm.blobhashes(_getBlobHashes(blobCount));

        for (uint256 i; i < reentries.length; ++i) {
            vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
            lander.land(input, reentries[i], values[i], false);
            _assertForcedInclusionState(0, 2);
            _assertLastCheckpoint(0, genesisBlockHash);

            uint256 snapshot = vm.snapshotState();
            uint256 landerBefore = address(lander).balance;
            lander.land(input, reentries[i], values[i], true);
            assertFalse(lander.reentrySucceeded(), "re-entry failed");
            assertEq(
                lander.reentryError(),
                abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector),
                "re-entry rejected"
            );
            _assertForcedInclusionState(2, 2);
            _assertLastCheckpoint(3, input.lastBlockHash);
            assertEq(address(lander).balance - landerBefore, feesWei, "only the outer fees");
            assertTrue(vm.revertToStateAndDelete(snapshot), "restored");
        }
    }

    function test_hashLandStatement_BindsEachProxySharingTheSameImplementation() external {
        EtnaInbox otherInbox = EtnaInbox(payable(new ERC1967Proxy(address(etnaImplementation), "")));
        vm.store(address(otherInbox), bytes32(COMMITTEE_CONFIG_SLOT), COMMITTEE_CONFIG_HASH);
        IEtnaInbox.LandInput memory input = _batch(5);
        bytes32[] memory blobs = _getBlobHashes(blobCount);
        bytes32 firstStatement = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        bytes32 secondStatement = otherInbox.hashLandStatement(
            0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        assertNotEq(firstStatement, secondStatement, "each Inbox proxy is bound");
    }

    function test_hashLandStatement_BindsTheRegistryWhenOnlyItsImmutableChanges() external {
        IEtnaInbox.LandInput memory input = _batch(5);
        bytes32[] memory blobs = _getBlobHashes(blobCount);
        bytes32 original = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        IEtnaInbox.Config memory config = etnaConfig;
        config.stakingRegistry = address(_deployRegistry());
        etnaInbox.upgradeTo(address(new EtnaInbox(config)));
        bytes32 upgraded = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        assertNotEq(original, upgraded, "configured Registry is bound");
        assertEq(
            upgraded,
            _manualStatementForAddresses(
                address(etnaInbox),
                config.stakingRegistry,
                0,
                genesisBlockHash,
                COMMITTEE_CONFIG_HASH,
                input,
                L1_REFERENCE_BLOCK_HASH
            ),
            "same proxy uses the new Registry"
        );
    }

    function test_hashLandStatement_BindsBlobOrder() external view {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32[] memory blobs = _getBlobHashes(2);
        bytes32 original = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        (blobs[0], blobs[1]) = (blobs[1], blobs[0]);
        assertNotEq(
            original,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "blob order bound"
        );
    }

    function test_hashLandStatement_BindsEverySuppliedField() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32[] memory blobs = _getBlobHashes(2);
        bytes32 expected = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        assertEq(expected, _statement(0, genesisBlockHash, input), "independent encoding");
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                1, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "generation"
        );
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 1, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "parent height"
        );
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, bytes32(uint256(1)), 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "parent hash"
        );
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, bytes32(uint256(1)), blobs
            ),
            "reference hash"
        );
        input.lastHeight += 1;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "last height"
        );
        input.lastHeight -= 1;
        bytes32 originalHash = input.lastBlockHash;
        input.lastBlockHash = bytes32(uint256(1));
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "last hash"
        );
        input.lastBlockHash = originalHash;
        originalHash = input.lastStateRoot;
        input.lastStateRoot = bytes32(uint256(1));
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "last state root"
        );
        input.lastStateRoot = originalHash;
        input.l1ReferenceBlockNumber += 1;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "reference number"
        );
        input.l1ReferenceBlockNumber -= 1;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 1, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "forced inclusion head before"
        );
        input.forcedInclusionHead += 1;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "forced inclusion head after"
        );
        input.forcedInclusionHead -= 1;
        input.feeRecipient = Carol;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "fee recipient"
        );
        input.feeRecipient = Bob;
        blobs[0] = bytes32(uint256(1));
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "blob hash"
        );
        blobs = _getBlobHashes(2);
        input.l2RewardRecipient = Carol;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "L2 reward recipient"
        );
        input.l2RewardRecipient = Alice;
        input.baseFeeAmount += 1;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "base fee amount"
        );
        input.baseFeeAmount -= 1;
        vm.chainId(block.chainid + 1);
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "L1 chain id"
        );
    }

    function test_hashLandStatement_BindsTheConfiguredL2ChainId() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32 original = _statement(0, genesisBlockHash, input);
        IEtnaInbox.Config memory config = etnaConfig;
        config.l2ChainId += 1;
        etnaInbox.upgradeTo(address(new EtnaInbox(config)));
        assertNotEq(
            original,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, 0, input, L1_REFERENCE_BLOCK_HASH, _getBlobHashes(2)
            ),
            "L2 chain id bound"
        );
    }

    /// @dev The configuration opening (352 bytes) and V8 statement (640 bytes) vectors of
    /// `testdata/etna_vectors/vectors.json`, which `cast` computes and taiko-client-rs reads too.
    /// The Inbox is etched at the vector's address with the vector's identities and
    /// configuration hash, so `hashLandStatement` binds exactly the vector's twenty static words.
    function test_hashLandStatement_MatchesTheV8Vector() external {
        string memory json = LibEtnaVectors.load();
        address vectorInbox = _etchVectorInbox(json);
        bytes32[] memory blobs =
            vm.parseJsonBytes32Array(json, ".land_statement.inputs.blob_hashes");
        assertEq(
            keccak256(abi.encodePacked(blobs)),
            LibEtnaVectors.bytes32At(json, ".land_statement.blob_hashes_hash"),
            "ordered blobs"
        );
        bytes32 expected = LibEtnaVectors.bytes32At(json, ".land_statement.hash");
        assertEq(
            keccak256(LibEtnaVectors.bytesAt(json, ".land_statement.preimage")),
            expected,
            "the preimage opens the statement"
        );
        assertEq(_hashVectorStatement(json, vectorInbox, blobs), expected, "V8 statement");
        assertEq(LibEtnaVectors.bytesAt(json, ".land_statement.preimage").length, 640);
        assertEq(IEtnaInbox.land.selector, bytes4(LibEtnaVectors.bytesAt(json, ".land_selector")));
        LibEtnaRewards.Receipt memory receipt = LibEtnaVectors.rewardReceipt(json);
        bytes32 id = LibEtnaRewards.batchId(receipt);
        assertEq(id, LibEtnaVectors.bytes32At(json, ".reward_receipt.batch_id"));
        assertEq(
            LibEtnaRewards.commitment(receipt),
            LibEtnaVectors.bytes32At(json, ".reward_receipt.commitment")
        );
        assertEq(
            LibEtnaRewards.receiptSlot(id), LibEtnaVectors.bytes32At(json, ".reward_receipt.slot")
        );
    }

    function test_land_RejectsEveryMutatedParentAnchorConfigWord() external {
        bytes memory configWords = _parentAnchorConfigWords(address(registry));
        bytes32 configHash = keccak256(configWords);
        vm.store(address(etnaInbox), bytes32(COMMITTEE_CONFIG_SLOT), configHash);
        IEtnaInbox.LandInput memory input = _batch(11);
        for (uint256 i; i < 11; ++i) {
            bytes memory mutated = bytes.concat(configWords);
            assembly {
                let word := add(add(mutated, 32), mul(i, 32))
                mstore(word, xor(mload(word), 1))
            }
            _rejectStatementAndAssertRollback(
                input,
                _manualStatement(
                    0, genesisBlockHash, keccak256(mutated), input, L1_REFERENCE_BLOCK_HASH
                )
            );
        }
        _landExpectingConfig(input, configHash);
        _assertLastCheckpoint(11, input.lastBlockHash);
        _assertSignalCheckpoint(input);
    }

    function test_land_RevertWhen_ProofUsesTheFormerFixedCutoffConfigHash() external {
        bytes32 configHash = keccak256(_parentAnchorConfigWords(address(registry)));
        vm.store(address(etnaInbox), bytes32(COMMITTEE_CONFIG_SLOT), configHash);
        bytes32 formerConfigHash = keccak256(
            abi.encode(
                bytes32("ETNA_FIXED_CUTOFF_V1"),
                uint256(167_001),
                address(registry),
                uint64(10),
                uint64(20),
                uint256(1e9),
                uint256(1 ether),
                uint64(128),
                uint64(32),
                uint64(2),
                uint8(1)
            )
        );
        IEtnaInbox.LandInput memory input = _batch(11);
        _rejectStatementAndAssertRollback(
            input,
            _manualStatement(0, genesisBlockHash, formerConfigHash, input, L1_REFERENCE_BLOCK_HASH)
        );
    }

    /// @dev Etches an Inbox at the statement vector's address with the vector's chain ids,
    /// registry and configuration hash, after checking the configuration opening vector.
    function _etchVectorInbox(string memory _json) internal returns (address inbox_) {
        string memory p = ".land_statement.inputs.";
        vm.chainId(LibEtnaVectors.uintAt(_json, string.concat(p, "l1_chain_id")));
        inbox_ = LibEtnaVectors.addressAt(_json, string.concat(p, "inbox"));
        IEtnaInbox.Config memory config = etnaConfig;
        config.l2ChainId = uint64(LibEtnaVectors.uintAt(_json, string.concat(p, "l2_chain_id")));
        config.stakingRegistry = LibEtnaVectors.addressAt(_json, string.concat(p, "registry"));
        vm.etch(inbox_, address(new EtnaInbox(config)).code);

        bytes memory configWords = LibEtnaVectors.configWords(_json);
        bytes32 configHash = LibEtnaVectors.bytes32At(_json, ".committee_config.hash");
        assertEq(configWords.length, 352, "eleven config words");
        assertEq(configWords, LibEtnaVectors.bytesAt(_json, ".committee_config.preimage"));
        assertEq(keccak256(configWords), configHash, "config opening");
        assertEq(
            LibEtnaVectors.bytes32At(_json, string.concat(p, "committee_config_hash")),
            configHash,
            "the statement binds the config vector"
        );
        vm.store(inbox_, bytes32(COMMITTEE_CONFIG_SLOT), configHash);
    }

    /// @dev Hashes the shared statement vector through the etched Inbox.
    function _hashVectorStatement(
        string memory _json,
        address _inbox,
        bytes32[] memory _blobs
    )
        internal
        view
        returns (bytes32)
    {
        string memory p = ".land_statement.inputs.";
        IEtnaInbox.LandInput memory input = LibEtnaVectors.landInput(_json);
        assertEq(abi.encode(input).length, 256, "eight static LandInput words");
        return EtnaInbox(payable(_inbox))
            .hashLandStatement(
                uint64(LibEtnaVectors.uintAt(_json, string.concat(p, "generation"))),
                uint64(LibEtnaVectors.uintAt(_json, string.concat(p, "parent_height"))),
                LibEtnaVectors.bytes32At(_json, string.concat(p, "parent_hash")),
                uint48(
                    LibEtnaVectors.uintAt(_json, string.concat(p, "forced_inclusion_head_before"))
                ),
                input,
                LibEtnaVectors.bytes32At(_json, string.concat(p, "l1_reference_block_hash")),
                _blobs
            );
    }

    event BatchRewardRecorded(
        bytes32 indexed batchId,
        address indexed l2RewardRecipient,
        uint256 baseFeeAmount,
        uint64 generation,
        uint64 parentHeight,
        bytes32 parentHash,
        uint64 lastHeight,
        bytes32 lastBlockHash
    );

    /// @notice Records a zero reward receipt and emits its discovery event without funding.
    function test_land_RecordsZeroRewardAndDiscoveryEvent() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        LibEtnaRewards.Receipt memory receipt = _receipt(input);
        bytes32 id = LibEtnaRewards.batchId(receipt);
        vm.expectEmit();
        emit BatchRewardRecorded(
            id,
            input.l2RewardRecipient,
            0,
            0,
            0,
            genesisBlockHash,
            input.lastHeight,
            input.lastBlockHash
        );
        _land(input);
        assertEq(etnaInbox.rewardCommitments(id), LibEtnaRewards.commitment(receipt));
        assertEq(
            vm.load(address(etnaInbox), LibEtnaRewards.receiptSlot(id)),
            LibEtnaRewards.commitment(receipt)
        );
        assertEq(address(etnaInbox).balance, 0);
    }

    /// @notice Pays queued L1 fees independently from the recorded L2 reward.
    function test_land_SeparatesL1FeesAndL2Rewards() external {
        uint64[] memory fees = _saveForcedInclusions(1);
        IEtnaInbox.LandInput memory input = _batch(1);
        input.forcedInclusionHead = 1;
        input.baseFeeAmount = type(uint256).max;
        input.l2RewardRecipient = Alice;
        LibEtnaRewards.Receipt memory receipt = _receipt(input);
        uint256 l1Before = Bob.balance;
        uint256 l2Before = Alice.balance;
        _land(input);
        assertEq(Bob.balance - l1Before, uint256(fees[0]) * 1 gwei);
        assertEq(Alice.balance, l2Before);
        assertEq(
            etnaInbox.rewardCommitments(LibEtnaRewards.batchId(receipt)),
            LibEtnaRewards.commitment(receipt)
        );
        assertEq(address(etnaInbox).balance, 0);
    }

    /// @notice Rejects a zero L2 reward recipient without advancing the checkpoint.
    function test_land_RevertWhen_RewardRecipientIsZero() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        input.l2RewardRecipient = address(0);
        _expectLandRevert(input, EtnaInbox.ZeroRewardRecipient.selector);
        _assertLastCheckpoint(0, genesisBlockHash);
    }

    /// @notice Rolls back the receipt, checkpoint and queue when an L1 fee transfer fails.
    function test_land_RejectingL1PaymentRollsBackReceiptCheckpointAndQueue() external {
        _saveForcedInclusions(1);
        IEtnaInbox.LandInput memory input = _batch(1);
        input.forcedInclusionHead = 1;
        input.baseFeeAmount = 2 ether;
        input.feeRecipient = address(new RejectingFeeRecipient());
        bytes32 id = LibEtnaRewards.batchId(_receipt(input));
        uint256 held = address(etnaInbox).balance;
        _expectLandRevert(input, LibAddress.ETH_TRANSFER_FAILED.selector);
        assertEq(etnaInbox.rewardCommitments(id), bytes32(0));
        assertEq(address(etnaInbox).balance, held);
        _assertForcedInclusionState(0, 1);
        _assertLastCheckpoint(0, genesisBlockHash);
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(1);
        // The exact same receipt can be recorded once the payment is accepted.
        input.feeRecipient = Bob;
        _land(input);
        assertNotEq(etnaInbox.rewardCommitments(id), bytes32(0));
    }

    /// @notice Skips the L1 fee transfer when no queued fees are owed.
    function test_land_DoesNotCallL1RecipientForZeroFees() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        input.feeRecipient = address(new RejectingFeeRecipient());
        input.baseFeeAmount = 1 ether;
        _land(input);
        _assertLastCheckpoint(1, input.lastBlockHash);
    }

    /// @notice Rejects a previously recorded receipt without overwriting its commitment.
    function test_land_RevertWhen_ReceiptAlreadyRecorded() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        bytes32 id = LibEtnaRewards.batchId(_receipt(input));
        vm.store(address(etnaInbox), LibEtnaRewards.receiptSlot(id), bytes32(uint256(7)));
        _expectLandRevert(input, EtnaInbox.RewardAlreadyRecorded.selector);
        assertEq(etnaInbox.rewardCommitments(id), bytes32(uint256(7)));
        _assertLastCheckpoint(0, genesisBlockHash);
    }

    /// @notice Binds the reward recipient and amount to the verified landing statement.
    function test_land_RejectsSubstitutedRewardRecipientAndAmount() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        bytes32 statement = _statement(0, genesisBlockHash, input);
        input.l2RewardRecipient = Carol;
        _rejectStatementAndAssertRollback(input, statement);
        input.l2RewardRecipient = Alice;
        input.baseFeeAmount = 1;
        _rejectStatementAndAssertRollback(input, statement);
    }

    /// @notice Rejects value on both landing calls and plain Ether transfers.
    function test_land_IsNonpayableAndRejectsPlainEther() external {
        IEtnaInbox.LandInput memory input = _batch(1);
        vm.deal(address(this), 1 ether);
        (bool ok,) =
            address(etnaInbox).call{ value: 1 }(abi.encodeCall(IEtnaInbox.land, (input, PROOF)));
        assertFalse(ok);
        (ok,) = address(etnaInbox).call{ value: 1 }("");
        assertFalse(ok);
        _assertLastCheckpoint(0, genesisBlockHash);
    }

    /// @notice Commits the stored recovery generation and actual parent checkpoint.
    function test_land_ReceiptUsesStoredGenerationAndActualParent() external {
        _land(_batch(7));
        vm.store(address(etnaInbox), bytes32(RECOVERY_GENERATION_SLOT), bytes32(uint256(5)));
        IEtnaInbox.LandInput memory input = _batch(9);
        input.baseFeeAmount = 42;
        LibEtnaRewards.Receipt memory receipt = _receipt(input);
        assertEq(receipt.parentHeight, 7);
        assertEq(receipt.parentHash, _batch(7).lastBlockHash);
        assertEq(receipt.generation, 5);
        _land(input);
        assertEq(
            etnaInbox.rewardCommitments(LibEtnaRewards.batchId(receipt)),
            LibEtnaRewards.commitment(receipt)
        );
    }

    /// @dev Builds a receipt from the current checkpoint and stored recovery generation.
    /// @param _input The landing batch supplying the reward and final checkpoint.
    /// @return The receipt expected to be committed by the landing.
    function _receipt(IEtnaInbox.LandInput memory _input)
        internal
        view
        returns (LibEtnaRewards.Receipt memory)
    {
        IEtnaInbox.LandedCheckpoint memory parent = etnaInbox.lastCheckpoint();
        return LibEtnaRewards.Receipt(
            block.chainid,
            L2_CHAIN_ID,
            address(etnaInbox),
            etnaInbox.recoveryGeneration(),
            parent.height,
            parent.blockHash,
            _input.lastHeight,
            _input.lastBlockHash,
            _input.l2RewardRecipient,
            _input.baseFeeAmount
        );
    }

    /// @dev Eleven independent static words; the contract stores this commitment opaquely.
    function _parentAnchorConfigWords(address _registry) internal pure returns (bytes memory) {
        return abi.encode(
            bytes32("ETNA_PARENT_ANCHOR_V3"),
            uint256(167_001),
            _registry,
            uint256(1e9),
            uint256(1 ether),
            uint64(128),
            uint64(32),
            uint64(2),
            uint8(2),
            uint64(12),
            uint64(2)
        );
    }

    /// @dev A batch that consumes no forced inclusion: its head is the stored head. Its fee
    /// recipient is Bob, the default lander.
    function _batch(uint64 _lastHeight) internal view returns (IEtnaInbox.LandInput memory) {
        return IEtnaInbox.LandInput({
            lastHeight: _lastHeight,
            lastBlockHash: keccak256(abi.encode("l2 block", _lastHeight)),
            lastStateRoot: keccak256(abi.encode("l2 state", _lastHeight)),
            l1ReferenceBlockNumber: l1ReferenceBlockNumber,
            forcedInclusionHead: _forcedInclusionHead(),
            feeRecipient: Bob,
            l2RewardRecipient: Alice,
            baseFeeAmount: 0
        });
    }

    /// @dev The stored forced inclusion head, read from slot 281 bits 0-47.
    function _forcedInclusionHead() internal view returns (uint48) {
        return uint48(_loadSlot(FORCED_INCLUSION_HEAD_TAIL_SLOT));
    }

    /// @dev The first word of forced inclusion entry `_index`, holding its transaction hash.
    function _entrySlot(uint256 _index) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_index, FORCED_INCLUSION_QUEUE_SLOT)));
    }

    /// @dev Word `_index` of an ABI encoding.
    function _word(bytes memory _words, uint256 _index) internal pure returns (bytes32 word_) {
        assembly {
            word_ := mload(add(add(_words, 32), mul(_index, 32)))
        }
    }

    /// @dev Alice saves `_count` calldata forced inclusions at the current fee each.
    function _saveForcedInclusions(uint256 _count) internal returns (uint64[] memory fees_) {
        vm.deal(Alice, 1000 ether);
        vm.blobhashes(_getBlobHashes(1));
        fees_ = new uint64[](_count);
        for (uint256 i; i < _count; ++i) {
            fees_[i] = etnaInbox.getCurrentForcedInclusionFee();
            vm.prank(Alice);
            etnaInbox.saveForcedInclusion{ value: uint256(fees_[i]) * 1 gwei }(hex"c0");
        }
    }

    /// @dev Lands `_input` with the forced inclusion head moved to `_newHead`.
    function _landConsuming(IEtnaInbox.LandInput memory _input, uint48 _newHead) internal {
        _input.forcedInclusionHead = _newHead;
        _landExpectingConfig(_input, COMMITTEE_CONFIG_HASH);
    }

    function _assertForcedInclusionState(uint48 _head, uint48 _tail) internal view {
        (uint48 head, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertEq(head, _head, "forced inclusion head");
        assertEq(tail, _tail, "forced inclusion tail");
        assertEq(_forcedInclusionHead(), _head, "slot 281 head");
    }

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
            etnaInbox.committeeConfigHash(),
            _input,
            L1_REFERENCE_BLOCK_HASH
        );
    }

    function _manualStatement(
        uint64 _parentHeight,
        bytes32 _parentHash,
        bytes32 _configHash,
        IEtnaInbox.LandInput memory _input,
        bytes32 _referenceHash
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
            _configHash,
            _input,
            _referenceHash
        );
    }

    function _manualStatementForAddresses(
        address _inbox,
        address _registry,
        uint64 _parentHeight,
        bytes32 _parentHash,
        bytes32 _configHash,
        IEtnaInbox.LandInput memory _input,
        bytes32 _referenceHash
    )
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            _manualPreimage(
                _inbox, _registry, _parentHeight, _parentHash, _configHash, _input, _referenceHash
            )
        );
    }

    /// @dev Independent flat V8 encoding, deliberately not the implementation's struct helper.
    /// The head before is read from slot 281; distinct L1 and L2 recipients and amount follow.
    function _manualPreimage(
        address _inbox,
        address _registry,
        uint64 _parentHeight,
        bytes32 _parentHash,
        bytes32 _configHash,
        IEtnaInbox.LandInput memory _input,
        bytes32 _referenceHash
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory context = abi.encode(
            bytes32("TAIKO_ETNA_LAND_V8"), block.chainid, L2_CHAIN_ID, _inbox, _registry
        );
        return bytes.concat(
            context,
            abi.encode(uint64(0), _parentHeight, _parentHash, _configHash),
            abi.encode(
                _input.lastHeight,
                _input.lastBlockHash,
                _input.lastStateRoot,
                _input.l1ReferenceBlockNumber,
                _referenceHash,
                keccak256(abi.encodePacked(_getBlobHashes(blobCount)))
            ),
            abi.encode(_forcedInclusionHead(), _input.forcedInclusionHead, _input.feeRecipient),
            abi.encode(_input.l2RewardRecipient, _input.baseFeeAmount)
        );
    }

    function _rejectStatementAndAssertRollback(
        IEtnaInbox.LandInput memory _input,
        bytes32 _wrongStatement
    )
        internal
    {
        bytes32 configBefore = etnaInbox.committeeConfigHash();
        bytes32 receiptId = keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_BATCH_V1"),
                block.chainid,
                L2_CHAIN_ID,
                address(etnaInbox),
                etnaInbox.recoveryGeneration(),
                etnaInbox.lastCheckpoint().height,
                etnaInbox.lastCheckpoint().blockHash,
                _input.lastHeight,
                _input.lastBlockHash
            )
        );
        bytes32 receiptBefore = etnaInbox.rewardCommitments(receiptId);
        IEtnaInbox.LandedCheckpoint memory parent = etnaInbox.lastCheckpoint();
        (uint48 head, uint48 tail) = etnaInbox.getForcedInclusionState();
        uint256 inboxBalance = address(etnaInbox).balance;
        uint256 landerBalance = Bob.balance;
        uint256 recipientBalance = _input.feeRecipient.balance;
        landVerifier.setExpectedStatementHash(_wrongStatement);
        _expectLandRevert(_input, MockLandProofVerifier.ProofRejected.selector);
        _assertLastCheckpoint(parent.height, parent.blockHash);
        _assertForcedInclusionState(head, tail);
        assertEq(address(etnaInbox).balance, inboxBalance, "fees retained");
        assertEq(Bob.balance, landerBalance, "nothing paid");
        assertEq(_input.feeRecipient.balance, recipientBalance, "recipient not paid");
        assertEq(etnaInbox.genesisCommitteeRecordHash(), COMMITTEE_RECORD_0, "bootstrap retained");
        assertEq(etnaInbox.committeeConfigHash(), configBefore, "config retained");
        assertEq(etnaInbox.rewardCommitments(receiptId), receiptBefore, "receipt rolled back");
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(uint48(_input.lastHeight));
    }

    function _landExpectingConfig(
        IEtnaInbox.LandInput memory _input,
        bytes32 _configHash
    )
        internal
    {
        IEtnaInbox.LandedCheckpoint memory parent = etnaInbox.lastCheckpoint();
        bytes32 expected = _manualStatement(
            parent.height, parent.blockHash, _configHash, _input, L1_REFERENCE_BLOCK_HASH
        );
        landVerifier.setExpectedStatementHash(expected);
        vm.expectCall(
            address(landVerifier), abi.encodeCall(IProofVerifier.verifyProof, (0, expected, PROOF))
        );
        _land(_input);
    }

    function _land(IEtnaInbox.LandInput memory _input) internal {
        _landAs(Bob, _input);
    }

    /// @dev Lands the proven batch from the requested caller.
    function _landAs(address _caller, IEtnaInbox.LandInput memory _input) internal {
        vm.blobhashes(_getBlobHashes(blobCount));
        vm.prank(_caller);
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
            _forcedInclusionHead(),
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
            forcedInclusionHead: 0,
            feeRecipient: Alice,
            l2RewardRecipient: Alice,
            baseFeeAmount: 0
        });

        vm.expectRevert(EtnaInbox.EtnaNotActive.selector);
        etnaInbox.land(input, "");
    }
}
