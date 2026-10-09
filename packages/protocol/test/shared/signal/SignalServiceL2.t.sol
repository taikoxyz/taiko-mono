// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LegacySignalService } from "./LegacySignalService.sol";
import { SignalServiceProofFixture } from "./SignalServiceProofFixture.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceL2 } from "src/shared/signal/SignalServiceL2.sol";
import { AnchorTestBase } from "test/layer2/core/Anchor.t.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract TestSignalServiceL2 is CommonTest, AnchorTestBase, SignalServiceProofFixture {
    Anchor private _anchor;
    SignalService private _signalService;

    function setUp() public override {
        vm.chainId(167_001);
        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        _deployPair(ETNA_TIMESTAMP);
        _recordBeaconRoot(ETNA_TIMESTAMP, VALID_PROOF_STATE_ROOT);
    }

    function test_verifySignalReceived_UsesHopProofTimestampAtEtnaWithoutCheckpoint() external {
        vm.warp(ETNA_TIMESTAMP);
        ISignalService.HopProof[] memory proofs =
            abi.decode(VALID_SIGNAL_PROOF, (ISignalService.HopProof[]));
        proofs[0].blockId = ETNA_TIMESTAMP;

        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    function test_verifySignalReceived_CheckpointProofMustBeRegeneratedAtEtna() external {
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
        _signalService.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );

        ISignalService.HopProof[] memory proofs =
            abi.decode(VALID_SIGNAL_PROOF, (ISignalService.HopProof[]));
        proofs[0].blockId += uint64(1) << 48;
        vm.expectRevert(Anchor.InvalidL1BlockNumber.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );

        vm.warp(ETNA_TIMESTAMP);
        // The wire format is unchanged, but blockId is now interpreted as an L2 timestamp.
        vm.expectRevert(Anchor.EtnaNotActive.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIMESTAMP)
        );

        _recordBeaconRoot(ETNA_TIMESTAMP + 1, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIMESTAMP + 1)
        );
    }

    function test_proveSignalReceived_CacheSurvivesOracleExpiryAndUnavailableProvider() external {
        assertEq(
            _signalService.proveSignalReceived(
                SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIMESTAMP)
            ),
            0
        );
        assertEq(vm.load(address(_signalService), _cacheSlot(false)), bytes32(uint256(1)));
        assertEq(vm.load(address(_signalService), _cacheSlot(true)), bytes32(0));
        _recordBeaconRoot(ETNA_TIMESTAMP + 8191, bytes32(uint256(123)));

        vm.expectRevert(Anchor.L1StateRootNotFound.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIMESTAMP)
        );

        // An empty proof must bypass the provider, even after its oracle entry expires.
        vm.etch(address(_anchor), hex"5f5ffd");
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        _signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    function test_verifySignalReceived_RevertWhen_OracleRootMissingOrZero() external {
        vm.expectRevert(Anchor.L1StateRootNotFound.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIMESTAMP + 1)
        );

        _recordBeaconRoot(ETNA_TIMESTAMP, bytes32(0));
        vm.expectRevert(Anchor.L1StateRootNotFound.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIMESTAMP)
        );
    }

    function test_verifySignalReceived_RevertWhen_RootHashDiffersFromOracleRoot() external {
        _recordBeaconRoot(ETNA_TIMESTAMP, bytes32(uint256(123)));

        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIMESTAMP)
        );
    }

    function test_verifySignalReceived_RevertWhen_MerkleProofTampered() external {
        ISignalService.HopProof[] memory proofs =
            abi.decode(_timestampProof(ETNA_TIMESTAMP), (ISignalService.HopProof[]));
        proofs[0].storageProof[0][3] ^= bytes1(uint8(1));

        vm.expectRevert();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    function test_verifySignalReceived_UsesFullUint64TimestampWithoutTruncation() external {
        uint64 timestamp = ETNA_TIMESTAMP + (uint64(1) << 48);
        // Different roots make accidental uint48 truncation select an invalid root.
        _recordBeaconRoot(ETNA_TIMESTAMP, bytes32(uint256(123)));
        _recordBeaconRoot(timestamp, VALID_PROOF_STATE_ROOT);

        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(timestamp)
        );
    }

    function test_verifySignalReceived_RespectsGenesisAndNeverEtnaConfiguration() external {
        _deployPair(0);
        _recordBeaconRoot(1, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(1)
        );

        _deployPair(type(uint64).max);
        vm.warp(ETNA_TIMESTAMP);
        _saveCheckpoint(_signalService, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
    }

    function test_proxyUpgrade_IgnoresDeprecatedRecordsAndReprovesOldSignal() external {
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
        bytes32 localSignal = keccak256("historical sent signal");
        legacy.sendSignal(localSignal);
        legacy.pause();
        assertEq(vm.load(address(legacy), _checkpointSlot(true)), VALID_BLOCK_HASH);
        assertEq(vm.load(address(legacy), _cacheSlot(true)), bytes32(uint256(1)));

        SignalService upgraded = _upgradeLegacy(legacy);

        assertEq(upgraded.owner(), address(this));
        assertTrue(upgraded.paused());
        assertTrue(upgraded.isSignalSent(address(this), localSignal));
        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        upgraded.unpause();
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        upgraded.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        assertEq(vm.load(address(upgraded), _cacheSlot(false)), bytes32(0));

        uint64 freshTimestamp = ETNA_TIMESTAMP + 1;
        _recordBeaconRoot(freshTimestamp, VALID_PROOF_STATE_ROOT);
        vm.record();
        upgraded.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(freshTimestamp)
        );

        (, bytes32[] memory writes) = vm.accesses(address(upgraded));
        assertEq(writes.length, 1);
        assertEq(writes[0], _cacheSlot(false));
        assertEq(vm.load(address(upgraded), _cacheSlot(false)), bytes32(uint256(1)));
        assertEq(vm.load(address(upgraded), _cacheSlot(true)), bytes32(uint256(1)));
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        upgraded.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
    }

    function test_proxyUpgrade_PreservesVersionOneRecordsOwnerPausedStateAndSentSignal() external {
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
        versionOne.pause();

        SignalServiceL2 etnaImplementation =
            new SignalServiceL2(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0));
        versionOne.upgradeTo(address(etnaImplementation));
        SignalService upgraded = SignalService(address(versionOne));

        assertEq(upgraded.VERSION(), 1);
        assertEq(upgraded.owner(), address(this));
        assertTrue(upgraded.paused());
        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        upgraded.unpause();
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

    function _deployPair(uint64 _etnaTimestamp) private {
        // Deploy real Anchor and SignalService proxies with reciprocal immutable addresses.
        address signalServiceProxy =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        _anchor = _deployAnchor(ICheckpointStore(signalServiceProxy), _etnaTimestamp);
        SignalServiceL2 implementation =
            new SignalServiceL2(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0));
        _signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(implementation), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
        assertEq(address(_signalService), signalServiceProxy);
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

    function _upgradeLegacy(LegacySignalService _legacy) private returns (SignalService) {
        SignalServiceL2 implementation =
            new SignalServiceL2(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0));
        _legacy.upgradeTo(address(implementation));
        return SignalService(address(_legacy));
    }

    function _saveCheckpoint(SignalService _service, bytes32 _root) private {
        vm.prank(address(_anchor));
        _service.saveCheckpoint(
            _checkpoint(uint48(VALID_PROOF_BLOCK_ID), uint256(VALID_BLOCK_HASH), uint256(_root))
        );
    }

    function _timestampProof(uint64 _timestamp) private pure returns (bytes memory) {
        ISignalService.HopProof[] memory proofs =
            abi.decode(VALID_SIGNAL_PROOF, (ISignalService.HopProof[]));
        proofs[0].blockId = _timestamp;
        return abi.encode(proofs);
    }

    function _cacheSlot(bool _deprecated) private view returns (bytes32) {
        bytes32 signalSlot = _signalService.getSignalSlot(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL);
        bytes32 namespaceSlot =
            _deprecated ? bytes32(uint256(253)) : keccak256(abi.encode(uint256(1), uint256(253)));
        return keccak256(abi.encode(signalSlot, namespaceSlot));
    }

    function _checkpointSlot(bool _deprecated) private pure returns (bytes32) {
        bytes32 namespaceSlot =
            _deprecated ? bytes32(uint256(254)) : keccak256(abi.encode(uint256(1), uint256(254)));
        return keccak256(abi.encode(uint256(VALID_PROOF_BLOCK_ID), namespaceSlot));
    }
}
