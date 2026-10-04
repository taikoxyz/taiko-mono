// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LegacySignalService } from "./LegacySignalService.sol";
import { SignalServiceProofFixture } from "./SignalServiceProofFixture.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";
import { ISignalServiceEtna } from "src/shared/signal/ISignalServiceEtna.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceEtna } from "src/shared/signal/SignalServiceEtna.sol";
import { AnchorTestBase } from "test/layer2/core/Anchor.t.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract TestSignalServiceEtna is CommonTest, AnchorTestBase, SignalServiceProofFixture {
    Anchor private _anchor;
    SignalService private _signalService;

    function setUp() public override {
        vm.chainId(167_001);
        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);

        // Deploy the real Anchor and SignalService proxies with reciprocal immutable addresses.
        address signalServiceProxy =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        _anchor = _deployAnchor(ICheckpointStore(signalServiceProxy), ETNA_TIMESTAMP);
        _signalService = _deployEtna(false, REMOTE_SIGNAL_SERVICE);
        assertEq(address(_signalService), signalServiceProxy);
        _recordBeaconRoot(ETNA_TIMESTAMP, VALID_PROOF_STATE_ROOT);
    }

    function test_stateRootProof_MagicMatchesSpecifiedFormat() external view {
        assertEq(
            SignalServiceEtna(address(_signalService)).STATE_ROOT_PROOF_MAGIC(),
            bytes4(keccak256("TAIKO_STATE_ROOT_PROOF_V1"))
        );
        _assertStorageMode(_signalService, false);
    }

    function test_verifySignalReceived_AcceptsRealStateRootProofWithoutCheckpoint() external view {
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );
    }

    function test_verifySignalReceived_StateRootProofDoesNotCacheOrSaveCheckpoint() external {
        vm.recordLogs();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );

        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(vm.load(address(_signalService), _cacheSlot(false)), bytes32(0));
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        _signalService.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
    }

    function test_proveSignalReceived_AcceptsRealStateRootProofAndCaches() external {
        assertEq(
            _signalService.proveSignalReceived(
                SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
            ),
            0
        );

        assertEq(vm.load(address(_signalService), _cacheSlot(false)), bytes32(uint256(1)));
        assertEq(vm.load(address(_signalService), _cacheSlot(true)), bytes32(0));
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        assertEq(
            _signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, ""), 0
        );
    }

    function test_proveSignalReceived_CacheRemainsUsableAfterOracleExpiry() external {
        _signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );
        _recordBeaconRoot(ETNA_TIMESTAMP + 8191, bytes32(uint256(123)));

        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        _signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");

        vm.expectRevert(Anchor.L1StateRootNotFound.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );
    }

    function test_verifySignalReceived_RevertWhen_StateRootProofTimestampBeforeEtna() external {
        _recordBeaconRoot(ETNA_TIMESTAMP - 1, VALID_PROOF_STATE_ROOT);

        vm.expectRevert(Anchor.EtnaNotActive.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP - 1)
        );
    }

    function test_verifySignalReceived_RevertWhen_StateRootProofTimestampMissing() external {
        vm.expectRevert(Anchor.L1StateRootNotFound.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP + 1)
        );
    }

    function test_verifySignalReceived_RevertWhen_StateRootProofRootIsZero() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, bytes32(0));

        vm.expectRevert(Anchor.L1StateRootNotFound.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );
    }

    function test_verifySignalReceived_RevertWhen_OracleStateRootDiffersFromProof() external {
        // An authentic pre-Etna checkpoint must not replace the timestamp-selected Etna root.
        _saveCheckpoint(_signalService, VALID_PROOF_STATE_ROOT);
        _recordBeaconRoot(ETNA_TIMESTAMP, bytes32(uint256(123)));

        vm.expectRevert();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );
    }

    function test_preEtnaAnchorV4_OldCheckpointAndFirstEtnaProofRemainUsable() external {
        vm.roll(100);
        vm.warp(ETNA_TIMESTAMP - 1);
        vm.prank(GOLDEN_TOUCH);
        _anchor.anchorV4(
            _checkpoint(
                uint48(VALID_PROOF_BLOCK_ID),
                uint256(VALID_BLOCK_HASH),
                uint256(VALID_PROOF_STATE_ROOT)
            )
        );

        vm.roll(101);
        _recordBeaconRoot(ETNA_TIMESTAMP, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );

        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        _anchor.anchorV4(_checkpoint(uint48(VALID_PROOF_BLOCK_ID + 1), 123, 123));
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        _signalService.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID + 1));
    }

    function test_verifySignalReceived_RevertWhen_AppOrChainIdTampered() external {
        bytes memory proof = _stateRootProof(ETNA_TIMESTAMP);
        vm.expectRevert();
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, Alice, VALID_SIGNAL, proof);
        vm.expectRevert();
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID + 1, REMOTE_APP, VALID_SIGNAL, proof);
    }

    function test_verifySignalReceived_RevertWhen_SignalTampered() external {
        vm.expectRevert();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, bytes32(uint256(123)), _stateRootProof(ETNA_TIMESTAMP)
        );
    }

    function test_verifySignalReceived_RevertWhen_RemoteSignalServiceTampered() external {
        SignalService wrongRemote = _deployEtna(false, Alice);

        vm.expectRevert();
        wrongRemote.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );
    }

    function test_verifySignalReceived_RevertWhen_AccountProofTampered() external {
        ISignalServiceEtna.StateRootProof memory proof = _proofData(ETNA_TIMESTAMP);
        proof.accountProof[0][3] ^= bytes1(uint8(1));

        vm.expectRevert();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _encodeStateRootProof(proof)
        );
    }

    function test_verifySignalReceived_RevertWhen_StorageProofTampered() external {
        ISignalServiceEtna.StateRootProof memory proof = _proofData(ETNA_TIMESTAMP);
        proof.storageProof[0][3] ^= bytes1(uint8(1));

        vm.expectRevert();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _encodeStateRootProof(proof)
        );
    }

    function test_verifySignalReceived_RevertWhen_StateRootProofAccountProofEmpty() external {
        ISignalServiceEtna.StateRootProof memory proof = _proofData(ETNA_TIMESTAMP);
        proof.accountProof = new bytes[](0);

        vm.expectRevert(SignalService.SS_EMPTY_PROOF.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _encodeStateRootProof(proof)
        );
    }

    function test_verifySignalReceived_RevertWhen_StateRootProofStorageProofEmpty() external {
        ISignalServiceEtna.StateRootProof memory proof = _proofData(ETNA_TIMESTAMP);
        proof.storageProof = new bytes[](0);

        vm.expectRevert(SignalService.SS_EMPTY_PROOF.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _encodeStateRootProof(proof)
        );
    }

    function test_verifySignalReceived_RevertWhen_StateRootProofMagicWrong() external {
        bytes memory proof = _stateRootProof(ETNA_TIMESTAMP);
        proof[0] ^= bytes1(uint8(1));

        vm.expectRevert();
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);
    }

    function test_verifySignalReceived_RevertWhen_StateRootProofEncodingTruncated() external {
        vm.expectRevert();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID,
            REMOTE_APP,
            VALID_SIGNAL,
            abi.encodePacked(bytes4(keccak256("TAIKO_STATE_ROOT_PROOF_V1")))
        );
        vm.expectRevert();
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, hex"010203");
    }

    function test_verifySignalReceived_RevertWhen_AppOrSignalZero() external {
        bytes memory proof = _stateRootProof(ETNA_TIMESTAMP);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, address(0), VALID_SIGNAL, proof);
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, bytes32(0), proof);
    }

    function test_stateRootProof_RevertWhen_Paused() external {
        bytes memory proof = _stateRootProof(ETNA_TIMESTAMP);
        _signalService.pause();

        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);
        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        _signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);
    }

    function test_stateRootProof_DesignatedPauserCanPauseAndUnpause() external {
        SignalService service = _deployEtna(false, REMOTE_SIGNAL_SERVICE, Alice);
        bytes memory proof = _stateRootProof(ETNA_TIMESTAMP);
        assertEq(service.pauser(), Alice);

        vm.prank(Alice);
        service.pause();
        assertTrue(service.paused());

        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        service.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);
        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        service.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);

        vm.prank(Alice);
        service.unpause();
        assertFalse(service.paused());
        service.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);
        service.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);
        service.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    function test_verifySignalReceived_AcceptsOldHopProofWithoutCaching() external {
        _saveCheckpoint(_signalService, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );

        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    function test_proveSignalReceived_AcceptsOldHopProofAndCaches() external {
        _saveCheckpoint(_signalService, VALID_PROOF_STATE_ROOT);
        _signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );

        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        assertEq(vm.load(address(_signalService), _cacheSlot(false)), bytes32(uint256(1)));
    }

    function test_versionedMode_RevertWhen_OnlyDeprecatedRecordsExist() external {
        _storeCheckpoint(address(_signalService), true, VALID_PROOF_STATE_ROOT);
        vm.store(address(_signalService), _cacheSlot(true), bytes32(uint256(1)));

        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        _signalService.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        _signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        _signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    function test_versionedMode_UsesVersionedRecordWhenDeprecatedRecordConflicts() external {
        _storeCheckpoint(address(_signalService), true, bytes32(uint256(123)));
        _saveCheckpoint(_signalService, VALID_PROOF_STATE_ROOT);

        assertEq(
            _signalService.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID)).stateRoot,
            VALID_PROOF_STATE_ROOT
        );
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
    }

    function test_legacyMode_ProxyUpgradePreservesCheckpointCacheAndSentSignal() external {
        LegacySignalService legacy = _deployLegacy();
        vm.prank(address(_anchor));
        legacy.saveCheckpoint(
            _checkpoint(
                uint48(VALID_PROOF_BLOCK_ID),
                uint256(VALID_BLOCK_HASH),
                uint256(VALID_PROOF_STATE_ROOT)
            )
        );
        legacy.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF);
        bytes32 localSignal = keccak256("local signal");
        legacy.sendSignal(localSignal);

        SignalService upgraded = _upgradeLegacy(legacy, true);

        _assertStorageMode(upgraded, true);
        assertEq(upgraded.owner(), address(this));
        assertEq(
            upgraded.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID)).stateRoot, VALID_PROOF_STATE_ROOT
        );
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        assertTrue(upgraded.isSignalSent(address(this), localSignal));
        assertEq(vm.load(address(upgraded), _cacheSlot(false)), bytes32(0));
    }

    function test_legacyMode_ProxyUpgradeAcceptsOldHopProofAndCachesAtOldSlot() external {
        LegacySignalService legacy = _deployLegacy();
        vm.prank(address(_anchor));
        legacy.saveCheckpoint(
            _checkpoint(
                uint48(VALID_PROOF_BLOCK_ID),
                uint256(VALID_BLOCK_HASH),
                uint256(VALID_PROOF_STATE_ROOT)
            )
        );
        SignalService upgraded = _upgradeLegacy(legacy, true);

        upgraded.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF);

        assertEq(vm.load(address(upgraded), _cacheSlot(true)), bytes32(uint256(1)));
        assertEq(vm.load(address(upgraded), _cacheSlot(false)), bytes32(0));
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    function test_legacyMode_StateRootProofWritesCacheAtOldSlot() external {
        SignalService legacy = _deployEtna(true, REMOTE_SIGNAL_SERVICE);

        legacy.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );

        assertEq(vm.load(address(legacy), _cacheSlot(true)), bytes32(uint256(1)));
        assertEq(vm.load(address(legacy), _cacheSlot(false)), bytes32(0));
        legacy.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    function test_legacyMode_NewCheckpointWritesUseOldSlotsAfterUpgrade() external {
        SignalService upgraded = _upgradeLegacy(_deployLegacy(), true);

        _saveCheckpoint(upgraded, VALID_PROOF_STATE_ROOT);

        bytes32 oldSlot = _checkpointSlot(true);
        assertEq(vm.load(address(upgraded), oldSlot), VALID_BLOCK_HASH);
        assertEq(vm.load(address(upgraded), bytes32(uint256(oldSlot) + 1)), VALID_PROOF_STATE_ROOT);
        assertEq(vm.load(address(upgraded), _checkpointSlot(false)), bytes32(0));
        assertEq(
            upgraded.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID)).stateRoot, VALID_PROOF_STATE_ROOT
        );
    }

    function test_legacyMode_RevertWhen_OnlyVersionedRecordsExist() external {
        SignalService legacy = _deployEtna(true, REMOTE_SIGNAL_SERVICE);
        _storeCheckpoint(address(legacy), false, VALID_PROOF_STATE_ROOT);
        vm.store(address(legacy), _cacheSlot(false), bytes32(uint256(1)));

        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        legacy.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        legacy.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    function test_legacyMode_UsesOldRecordWhenVersionedRecordConflicts() external {
        SignalService legacy = _deployEtna(true, REMOTE_SIGNAL_SERVICE);
        _storeCheckpoint(address(legacy), false, bytes32(uint256(123)));
        _saveCheckpoint(legacy, VALID_PROOF_STATE_ROOT);

        assertEq(
            legacy.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID)).stateRoot, VALID_PROOF_STATE_ROOT
        );
        legacy.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF);
    }

    function test_versionedMode_ProxyUpgradeRejectsOldRecordsAndUsesNewSlots() external {
        LegacySignalService legacy = _deployLegacy();
        vm.prank(address(_anchor));
        legacy.saveCheckpoint(
            _checkpoint(
                uint48(VALID_PROOF_BLOCK_ID),
                uint256(VALID_BLOCK_HASH),
                uint256(VALID_PROOF_STATE_ROOT)
            )
        );
        legacy.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF);
        SignalService upgraded = _upgradeLegacy(legacy, false);

        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        upgraded.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");

        _saveCheckpoint(upgraded, VALID_PROOF_STATE_ROOT);
        upgraded.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF);
        assertEq(vm.load(address(upgraded), _cacheSlot(false)), bytes32(uint256(1)));
        assertEq(vm.load(address(upgraded), _checkpointSlot(false)), VALID_BLOCK_HASH);
    }

    function test_versionedMode_ProxyUpgradePreservesVersionOneRecordsAndSentSignal() external {
        SignalService implementation =
            new SignalService(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0));
        SignalService versionOne = SignalService(
            address(
                new ERC1967Proxy(
                    address(implementation), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
        assertEq(versionOne.VERSION(), 1);
        _saveCheckpoint(versionOne, VALID_PROOF_STATE_ROOT);
        versionOne.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        bytes32 localSignal = keccak256("version one signal");
        versionOne.sendSignal(localSignal);

        SignalServiceEtna etnaImplementation =
            new SignalServiceEtna(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), false);
        versionOne.upgradeTo(address(etnaImplementation));
        SignalService upgraded = SignalService(address(versionOne));

        _assertStorageMode(upgraded, false);
        assertEq(upgraded.owner(), address(this));
        ICheckpointStore.Checkpoint memory stored =
            upgraded.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
        assertEq(stored.blockNumber, VALID_PROOF_BLOCK_ID);
        assertEq(stored.blockHash, VALID_BLOCK_HASH);
        assertEq(stored.stateRoot, VALID_PROOF_STATE_ROOT);
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        upgraded.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        assertTrue(upgraded.isSignalSent(address(this), localSignal));
        assertEq(vm.load(address(upgraded), _cacheSlot(false)), bytes32(uint256(1)));
        assertEq(vm.load(address(upgraded), _cacheSlot(true)), bytes32(0));
    }

    function test_legacyMode_ProxyUpgradePreservesPausedState() external {
        LegacySignalService legacy = _deployLegacy();
        legacy.pause();
        SignalService upgraded = _upgradeLegacy(legacy, true);

        assertTrue(upgraded.paused());
        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        upgraded.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );
        upgraded.unpause();
        upgraded.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _stateRootProof(ETNA_TIMESTAMP)
        );
    }

    function test_saveCheckpoint_RevertWhen_LegacyModeUnauthorizedOrInvalid() external {
        SignalService legacy = _deployEtna(true, REMOTE_SIGNAL_SERVICE);
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1, 1, 1);
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        legacy.saveCheckpoint(checkpoint);
        vm.prank(address(_anchor));
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        legacy.saveCheckpoint(_checkpoint(1, 1, 0));
        vm.prank(address(_anchor));
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        legacy.saveCheckpoint(_checkpoint(1, 0, 1));
    }

    function _assertStorageMode(SignalService _service, bool _legacy) private view {
        (bool ok, bytes memory result) =
            address(_service).staticcall(abi.encodeWithSignature("usesLegacyStorage()"));
        assertTrue(ok, "storage mode getter reverted");
        assertEq(abi.decode(result, (bool)), _legacy);
        (ok, result) = address(_service).staticcall(abi.encodeWithSignature("stateRootProvider()"));
        assertTrue(ok, "state root provider getter reverted");
        assertEq(abi.decode(result, (address)), address(_anchor));
    }

    function _deployEtna(bool _legacy, address _remote) private returns (SignalService) {
        return _deployEtna(_legacy, _remote, address(0));
    }

    function _deployEtna(
        bool _legacy,
        address _remote,
        address _pauser
    )
        private
        returns (SignalService)
    {
        SignalServiceEtna implementation =
            new SignalServiceEtna(address(_anchor), _remote, _pauser, _legacy);
        return SignalService(
            address(
                new ERC1967Proxy(
                    address(implementation), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
    }

    function _deployLegacy() private returns (LegacySignalService) {
        LegacySignalService implementation =
            new LegacySignalService(address(_anchor), REMOTE_SIGNAL_SERVICE);
        return LegacySignalService(
            address(
                new ERC1967Proxy(
                    address(implementation),
                    abi.encodeCall(LegacySignalService.init, (address(this)))
                )
            )
        );
    }

    function _upgradeLegacy(
        LegacySignalService _legacy,
        bool _useLegacy
    )
        private
        returns (SignalService)
    {
        SignalServiceEtna implementation =
            new SignalServiceEtna(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), _useLegacy);
        _legacy.upgradeTo(address(implementation));
        return SignalService(address(_legacy));
    }

    function _saveCheckpoint(SignalService _service, bytes32 _root) private {
        vm.prank(address(_anchor));
        _service.saveCheckpoint(
            _checkpoint(uint48(VALID_PROOF_BLOCK_ID), uint256(VALID_BLOCK_HASH), uint256(_root))
        );
    }

    function _stateRootProof(uint64 _timestamp) private pure returns (bytes memory) {
        return _encodeStateRootProof(_proofData(_timestamp));
    }

    function _proofData(uint64 _timestamp)
        private
        pure
        returns (ISignalServiceEtna.StateRootProof memory)
    {
        ISignalService.HopProof[] memory proofs =
            abi.decode(VALID_SIGNAL_PROOF, (ISignalService.HopProof[]));
        return ISignalServiceEtna.StateRootProof({
            l2Timestamp: _timestamp,
            accountProof: proofs[0].accountProof,
            storageProof: proofs[0].storageProof
        });
    }

    function _encodeStateRootProof(ISignalServiceEtna.StateRootProof memory _proof)
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(bytes4(keccak256("TAIKO_STATE_ROOT_PROOF_V1")), abi.encode(_proof));
    }

    function _cacheSlot(bool _legacy) private view returns (bytes32) {
        bytes32 signalSlot = _signalService.getSignalSlot(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL);
        bytes32 namespaceSlot =
            _legacy ? bytes32(uint256(253)) : keccak256(abi.encode(uint256(1), uint256(253)));
        return keccak256(abi.encode(signalSlot, namespaceSlot));
    }

    function _checkpointSlot(bool _legacy) private pure returns (bytes32) {
        bytes32 namespaceSlot =
            _legacy ? bytes32(uint256(254)) : keccak256(abi.encode(uint256(1), uint256(254)));
        return keccak256(abi.encode(uint256(VALID_PROOF_BLOCK_ID), namespaceSlot));
    }

    function _storeCheckpoint(address _service, bool _legacy, bytes32 _root) private {
        bytes32 slot = _checkpointSlot(_legacy);
        vm.store(_service, slot, VALID_BLOCK_HASH);
        vm.store(_service, bytes32(uint256(slot) + 1), _root);
    }
}
