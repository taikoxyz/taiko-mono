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

    /// @dev Independently mutate each of the fifteen public words accepted by the verifier.
    function test_land_RejectsEveryMutatedV4FieldAndRollsBack() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes memory words = _manualPreimage(
            address(etnaInbox),
            address(registry),
            0,
            genesisBlockHash,
            COMMITTEE_CONFIG_HASH,
            input,
            L1_REFERENCE_BLOCK_HASH
        );
        assertEq(words.length, 480, "fifteen static words");
        for (uint256 i; i < 15; ++i) {
            uint256 lastByte = 32 * i + 31;
            words[lastByte] = bytes1(uint8(words[lastByte]) ^ 1);
            _rejectStatementAndAssertRollback(input, keccak256(words));
            words[lastByte] = bytes1(uint8(words[lastByte]) ^ 1);
        }
        _landExpectingConfig(input, COMMITTEE_CONFIG_HASH);
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
            5, genesisHeight, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, _getBlobHashes(2)
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
            0, genesisHeight, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, _getBlobHashes(3)
        );
        bytes32 twoBlobStatementHash = etnaInbox.hashLandStatement(
            0, genesisHeight, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, _getBlobHashes(2)
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

    function test_hashLandStatement_BindsEachProxySharingTheSameImplementation() external {
        EtnaInbox otherInbox = EtnaInbox(address(new ERC1967Proxy(address(etnaImplementation), "")));
        vm.store(address(otherInbox), bytes32(COMMITTEE_CONFIG_SLOT), COMMITTEE_CONFIG_HASH);
        IEtnaInbox.LandInput memory input = _batch(5);
        bytes32[] memory blobs = _getBlobHashes(blobCount);
        bytes32 firstStatement = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        bytes32 secondStatement = otherInbox.hashLandStatement(
            0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        assertNotEq(firstStatement, secondStatement, "each Inbox proxy is bound");
    }

    function test_hashLandStatement_BindsTheRegistryWhenOnlyItsImmutableChanges() external {
        IEtnaInbox.LandInput memory input = _batch(5);
        bytes32[] memory blobs = _getBlobHashes(blobCount);
        bytes32 original = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        IEtnaInbox.Config memory config = etnaConfig;
        config.stakingRegistry = address(_deployRegistry());
        etnaInbox.upgradeTo(address(new EtnaInbox(config)));
        bytes32 upgraded = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
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
            0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        (blobs[0], blobs[1]) = (blobs[1], blobs[0]);
        assertNotEq(
            original,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "blob order bound"
        );
    }

    function test_hashLandStatement_BindsEverySuppliedField() external {
        IEtnaInbox.LandInput memory input = _batch(11);
        bytes32[] memory blobs = _getBlobHashes(2);
        bytes32 expected = etnaInbox.hashLandStatement(
            0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
        );
        assertEq(expected, _statement(0, genesisBlockHash, input), "independent encoding");
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                1, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "generation"
        );
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 1, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "parent height"
        );
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, bytes32(uint256(1)), input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "parent hash"
        );
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(0, 0, genesisBlockHash, input, bytes32(uint256(1)), blobs),
            "reference hash"
        );
        input.lastHeight += 1;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "last height"
        );
        input.lastHeight -= 1;
        bytes32 originalHash = input.lastBlockHash;
        input.lastBlockHash = bytes32(uint256(1));
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "last hash"
        );
        input.lastBlockHash = originalHash;
        originalHash = input.lastStateRoot;
        input.lastStateRoot = bytes32(uint256(1));
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "last state root"
        );
        input.lastStateRoot = originalHash;
        input.l1ReferenceBlockNumber += 1;
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "reference number"
        );
        input.l1ReferenceBlockNumber -= 1;
        blobs[0] = bytes32(uint256(1));
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
            ),
            "blob hash"
        );
        blobs = _getBlobHashes(2);
        vm.chainId(block.chainid + 1);
        assertNotEq(
            expected,
            etnaInbox.hashLandStatement(
                0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, blobs
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
                0, 0, genesisBlockHash, input, L1_REFERENCE_BLOCK_HASH, _getBlobHashes(2)
            ),
            "L2 chain id bound"
        );
    }

    /// @dev Independent ethers/5.7.2 vector shared with the client; config 352 bytes, V4 480 bytes.
    function test_hashLandStatement_MatchesTheFixedVector() external {
        vm.chainId(1);
        address vectorInbox = 0x1111111111111111111111111111111111111111;
        IEtnaInbox.Config memory config = etnaConfig;
        config.stakingRegistry = 0x2222222222222222222222222222222222222222;
        EtnaInbox impl = new EtnaInbox(config);
        vm.etch(vectorInbox, address(impl).code);
        bytes memory configWords = abi.encode(
            bytes32("ETNA_FIXED_CUTOFF_V1"),
            uint256(167_001),
            config.stakingRegistry,
            uint64(10),
            uint64(20),
            uint256(1e9),
            uint256(1 ether),
            uint64(128),
            uint64(32),
            uint64(2),
            uint8(1)
        );
        bytes32 configHash = 0xaf72a8cac328b7a82ec9c449fb39aecc89a196de580f512cc40f0e1d8a6ad2fa;
        assertEq(configWords.length, 352, "eleven config words");
        assertEq(keccak256(configWords), configHash, "config opening");
        vm.store(vectorInbox, bytes32(COMMITTEE_CONFIG_SLOT), configHash);
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: 164,
            lastBlockHash: bytes32(uint256(0x22)),
            lastStateRoot: bytes32(uint256(0x33)),
            l1ReferenceBlockNumber: 19_000_000
        });
        assertEq(abi.encode(input).length, 128, "four static LandInput words");
        bytes32[] memory blobs = new bytes32[](2);
        blobs[0] = bytes32(uint256(0x01aa));
        blobs[1] = bytes32(uint256(0x01bb));
        assertEq(
            keccak256(abi.encodePacked(blobs)),
            0xe7591a4eb3dcfdc958b08bf3db6054ebae1f9b1a82b8c685499c13314381ea64,
            "ordered blobs"
        );
        assertEq(
            EtnaInbox(vectorInbox)
                .hashLandStatement(
                    3, 100, bytes32(uint256(0x11)), input, bytes32(uint256(0x44)), blobs
                ),
            0xc25b74e918f50098001818a711b7604376e98978fa8cdace46af3803cdd100c2,
            "V4 statement"
        );
    }

    function _batch(uint64 _lastHeight) internal view returns (IEtnaInbox.LandInput memory) {
        return IEtnaInbox.LandInput({
            lastHeight: _lastHeight,
            lastBlockHash: keccak256(abi.encode("l2 block", _lastHeight)),
            lastStateRoot: keccak256(abi.encode("l2 state", _lastHeight)),
            l1ReferenceBlockNumber: l1ReferenceBlockNumber
        });
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

    /// @dev Independent flat V4 encoding, deliberately not the implementation's struct helper.
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
            bytes32("TAIKO_ETNA_LAND_V4"), block.chainid, L2_CHAIN_ID, _inbox, _registry
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
            )
        );
    }

    function _rejectStatementAndAssertRollback(
        IEtnaInbox.LandInput memory _input,
        bytes32 _wrongStatement
    )
        internal
    {
        bytes32 configBefore = etnaInbox.committeeConfigHash();
        landVerifier.setExpectedStatementHash(_wrongStatement);
        _expectLandRevert(_input, MockLandProofVerifier.ProofRejected.selector);
        _assertLastCheckpoint(0, genesisBlockHash);
        assertEq(etnaInbox.genesisCommitteeRecordHash(), COMMITTEE_RECORD_0, "bootstrap retained");
        assertEq(etnaInbox.committeeConfigHash(), configBefore, "config retained");
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
            l1ReferenceBlockNumber: uint64(block.number - 1)
        });

        vm.expectRevert(EtnaInbox.EtnaNotActive.selector);
        etnaInbox.land(input, "");
    }
}
