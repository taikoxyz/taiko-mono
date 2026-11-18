// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LegacySignalService } from "./LegacySignalService.sol";
import { SignalServiceProofFixture } from "./SignalServiceProofFixture.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test } from "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

/// @dev The L2 SignalService across the Etna fork (Etna SPEC START-10-5, ANCHORLESS.md section 4):
/// a real `Anchor` proxy saves checkpoints into it until `beaconRootsFrom`, and from then on proofs
/// resolve their root only through the canonical EIP-4788 contract.
contract TestSignalServiceBeaconRoots is Test, SignalServiceProofFixture {
    uint64 private constant FORK_TIME = 1_800_000_000;
    uint64 private constant L1_CHAIN_ID = 1;
    uint256 private constant SHASTA_FORK_HEIGHT = 100;
    address private constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
    address private constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address private constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
    /// @dev Runtime code of the canonical EIP-4788 contract, as deployed on Ethereum mainnet.
    bytes private constant BEACON_ROOTS_CODE =
        hex"3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500";

    Anchor private _anchor;
    SignalService private _signalService;

    function setUp() public {
        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        _deployPair(FORK_TIME);
    }

    function test_beaconRootsFrom_ReadsTheCanonicalEip4788Contract() external view {
        assertEq(_signalService.beaconRootsFrom(), FORK_TIME);
        assertEq(_signalService.BEACON_ROOTS(), BEACON_ROOTS);
    }

    // ---------------------------------------------------------------
    // Checkpoint cutoff (vectors 5.w and 5.x)
    // ---------------------------------------------------------------

    function test_anchorV4_SavesCheckpointOneSecondBeforeBeaconRootsFrom() external {
        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(FORK_TIME - 1);
        vm.prank(GOLDEN_TOUCH);
        _anchor.anchorV4(_checkpoint(1000, VALID_PROOF_STATE_ROOT));

        assertEq(_signalService.getCheckpoint(1000).stateRoot, VALID_PROOF_STATE_ROOT);
        assertEq(_anchor.getBlockState().anchorBlockNumber, 1000);
    }

    /// @dev Rehearses the fork-time forgery: in the first anchorless block, the public golden touch
    /// key must not be able to save a forged checkpoint through the unchanged `Anchor`.
    function test_anchorV4_RevertWhen_ForgedAtBeaconRootsFrom() external {
        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(FORK_TIME - 1);
        vm.prank(GOLDEN_TOUCH);
        _anchor.anchorV4(_checkpoint(1000, VALID_PROOF_STATE_ROOT));

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.warp(FORK_TIME);
        vm.deal(GOLDEN_TOUCH, 1 ether);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(SignalService.SS_CHECKPOINTS_CLOSED.selector);
        _anchor.anchorV4(_checkpoint(2000, bytes32(uint256(0xbad))));

        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        _signalService.getCheckpoint(2000);
        assertEq(_anchor.getBlockState().anchorBlockNumber, 1000);
        // Pre-fork checkpoints stay readable, though no proof uses them.
        assertEq(_signalService.getCheckpoint(1000).stateRoot, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_ChecksTheSyncerBeforeTheCutoff() external {
        vm.warp(FORK_TIME + 1);
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        _signalService.saveCheckpoint(_checkpoint(1000, VALID_PROOF_STATE_ROOT));

        vm.prank(address(_anchor));
        vm.expectRevert(SignalService.SS_CHECKPOINTS_CLOSED.selector);
        _signalService.saveCheckpoint(_checkpoint(1000, VALID_PROOF_STATE_ROOT));
    }

    // ---------------------------------------------------------------
    // Root resolution (vectors 5.y and 5.z)
    // ---------------------------------------------------------------

    function test_verifySignalReceived_UsesCheckpointBeforeBeaconRootsFrom() external {
        // An EIP-4788 entry whose timestamp equals the proof's block number must not be used.
        _recordBeaconRoot(VALID_PROOF_BLOCK_ID, bytes32(uint256(123)));
        vm.warp(FORK_TIME - 1);
        _saveCheckpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT);

        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );

        ISignalService.HopProof[] memory proofs =
            abi.decode(VALID_SIGNAL_PROOF, (ISignalService.HopProof[]));
        proofs[0].blockId += uint64(1) << 48;
        vm.expectRevert(SignalService.SS_INVALID_BLOCK_ID.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    function test_verifySignalReceived_ResolvesEip4788RootFromBeaconRootsFrom() external {
        _recordBeaconRoot(FORK_TIME, VALID_PROOF_STATE_ROOT);
        _recordBeaconRoot(FORK_TIME + 12, VALID_PROOF_STATE_ROOT);

        vm.warp(FORK_TIME);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );
        vm.warp(FORK_TIME + 12);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME + 12)
        );
    }

    function test_verifySignalReceived_RevertWhen_ProofUsesPreForkCheckpointAfterFork() external {
        vm.warp(FORK_TIME - 1);
        _saveCheckpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );

        // The wire format is unchanged, but blockId is now an L2 timestamp.
        vm.warp(FORK_TIME);
        vm.expectRevert(SignalService.SS_INVALID_BLOCK_ID.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
    }

    function test_verifySignalReceived_NeverFallsBackToACheckpointAfterFork() external {
        // A pre-fork checkpoint whose number is also a post-fork timestamp holds the valid root.
        vm.warp(FORK_TIME - 1);
        _saveCheckpoint(uint48(FORK_TIME + 12), VALID_PROOF_STATE_ROOT);

        vm.warp(FORK_TIME + 12);
        vm.expectRevert(SignalService.SS_STATE_ROOT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME + 12)
        );

        _recordBeaconRoot(FORK_TIME + 12, bytes32(uint256(123)));
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME + 12)
        );
    }

    function test_verifySignalReceived_RevertWhen_Eip4788RootMissingOrZero() external {
        vm.warp(FORK_TIME + 1);
        vm.expectRevert(SignalService.SS_STATE_ROOT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME + 1)
        );

        _recordBeaconRoot(FORK_TIME, bytes32(0));
        vm.expectRevert(SignalService.SS_STATE_ROOT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );
    }

    function test_verifySignalReceived_RevertWhen_Eip4788SlotOverwritten() external {
        _recordBeaconRoot(FORK_TIME, VALID_PROOF_STATE_ROOT);
        _recordBeaconRoot(FORK_TIME + 8191, bytes32(uint256(123)));

        vm.expectRevert(SignalService.SS_STATE_ROOT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );
    }

    function test_verifySignalReceived_RevertWhen_Eip4788ReturnIsMalformed() external {
        vm.warp(FORK_TIME);
        bytes memory query = abi.encode(uint256(FORK_TIME));

        // A call to an address without code succeeds with no return data.
        vm.etch(BEACON_ROOTS, "");
        vm.expectRevert(SignalService.SS_STATE_ROOT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );

        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        vm.mockCall(BEACON_ROOTS, query, abi.encodePacked(bytes31(VALID_PROOF_STATE_ROOT)));
        vm.expectRevert(SignalService.SS_STATE_ROOT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );

        vm.mockCall(BEACON_ROOTS, query, abi.encode(VALID_PROOF_STATE_ROOT, bytes32(0)));
        vm.expectRevert(SignalService.SS_STATE_ROOT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );

        vm.mockCall(BEACON_ROOTS, query, abi.encode(VALID_PROOF_STATE_ROOT));
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );
    }

    function test_verifySignalReceived_RevertWhen_RootHashDiffersFromEip4788Root() external {
        _recordBeaconRoot(FORK_TIME, bytes32(uint256(123)));

        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );
    }

    function test_verifySignalReceived_RevertWhen_MerkleProofTampered() external {
        _recordBeaconRoot(FORK_TIME, VALID_PROOF_STATE_ROOT);
        ISignalService.HopProof[] memory proofs =
            abi.decode(_timestampProof(FORK_TIME), (ISignalService.HopProof[]));
        proofs[0].storageProof[0][3] ^= bytes1(uint8(1));

        vm.expectRevert();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    function test_verifySignalReceived_UsesFullUint64Timestamp() external {
        uint64 timestamp = FORK_TIME + (uint64(1) << 48);
        // Different roots make an accidental uint48 truncation select an invalid root.
        _recordBeaconRoot(FORK_TIME, bytes32(uint256(123)));
        _recordBeaconRoot(timestamp, VALID_PROOF_STATE_ROOT);

        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(timestamp)
        );
    }

    function test_proveSignalReceived_CacheSurvivesEip4788Expiry() external {
        _recordBeaconRoot(FORK_TIME, VALID_PROOF_STATE_ROOT);
        assertEq(
            _signalService.proveSignalReceived(
                SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
            ),
            0
        );
        assertEq(vm.load(address(_signalService), _cacheSlot(false)), bytes32(uint256(1)));
        assertEq(vm.load(address(_signalService), _cacheSlot(true)), bytes32(0));

        _recordBeaconRoot(FORK_TIME + 8191, bytes32(uint256(123)));
        vm.expectRevert(SignalService.SS_STATE_ROOT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME)
        );

        // An empty proof reads only the cache, even once EIP-4788 itself fails.
        vm.etch(BEACON_ROOTS, hex"5f5ffd");
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        _signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    // ---------------------------------------------------------------
    // Configurations (vectors 5.s and 5.aa)
    // ---------------------------------------------------------------

    /// @dev `beaconRootsFrom = 0` is the L1 configuration: the checkpoint store stays the only root
    /// source at every time.
    function test_beaconRootsFromZero_KeepsCheckpointsAsTheOnlyRootSource() external {
        _deployPair(0);
        _recordBeaconRoot(VALID_PROOF_BLOCK_ID, VALID_PROOF_STATE_ROOT);
        vm.warp(type(uint64).max - 1);
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );

        _saveCheckpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
    }

    /// @dev A new network whose L2 genesis timestamp is 0 uses `beaconRootsFrom = 1`, so every
    /// block after genesis is on the EIP-4788 path.
    function test_beaconRootsFromOne_UsesEip4788FromTheFirstBlock() external {
        _deployPair(1);
        vm.warp(1);
        vm.prank(address(_anchor));
        vm.expectRevert(SignalService.SS_CHECKPOINTS_CLOSED.selector);
        _signalService.saveCheckpoint(_checkpoint(1, VALID_PROOF_STATE_ROOT));

        _recordBeaconRoot(1, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(1)
        );
    }

    // ---------------------------------------------------------------
    // Proxy upgrade
    // ---------------------------------------------------------------

    function test_proxyUpgrade_PreservesVersionOneRecordsOwnerPausedStateAndSentSignal() external {
        // The pre-Etna L2 implementation: the same code with checkpoints always open.
        SignalService versionOne = SignalService(
            address(
                new ERC1967Proxy(
                    address(
                        new SignalService(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), 0)
                    ),
                    abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
        vm.warp(FORK_TIME - 1);
        vm.prank(address(_anchor));
        versionOne.saveCheckpoint(_checkpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT));
        versionOne.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        bytes32 localSignal = keccak256("version one signal");
        versionOne.sendSignal(localSignal);
        versionOne.pause();

        versionOne.upgradeTo(
            address(
                new SignalService(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), FORK_TIME)
            )
        );
        vm.warp(FORK_TIME);

        assertEq(versionOne.VERSION(), 1);
        assertEq(versionOne.beaconRootsFrom(), FORK_TIME);
        assertEq(versionOne.owner(), address(this));
        assertTrue(versionOne.paused());
        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        versionOne.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        versionOne.unpause();
        ICheckpointStore.Checkpoint memory stored =
            versionOne.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
        assertEq(stored.blockHash, VALID_BLOCK_HASH);
        assertEq(stored.stateRoot, VALID_PROOF_STATE_ROOT);
        versionOne.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        versionOne.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        assertTrue(versionOne.isSignalSent(address(this), localSignal));
        vm.expectRevert(SignalService.SS_INVALID_BLOCK_ID.selector);
        versionOne.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
    }

    function test_proxyUpgrade_IgnoresDeprecatedRecordsAndReprovesOldSignal() external {
        LegacySignalService legacy = LegacySignalService(
            address(
                new ERC1967Proxy(
                    address(new LegacySignalService(address(_anchor), REMOTE_SIGNAL_SERVICE)),
                    abi.encodeCall(LegacySignalService.init, (address(this)))
                )
            )
        );
        vm.prank(address(_anchor));
        legacy.saveCheckpoint(_checkpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT));
        legacy.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF);
        bytes32 localSignal = keccak256("historical sent signal");
        legacy.sendSignal(localSignal);
        legacy.pause();
        assertEq(vm.load(address(legacy), _checkpointSlot(true)), VALID_BLOCK_HASH);
        assertEq(vm.load(address(legacy), _cacheSlot(true)), bytes32(uint256(1)));

        legacy.upgradeTo(
            address(
                new SignalService(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), FORK_TIME)
            )
        );
        SignalService upgraded = SignalService(address(legacy));

        assertEq(upgraded.owner(), address(this));
        assertTrue(upgraded.paused());
        assertTrue(upgraded.isSignalSent(address(this), localSignal));
        upgraded.unpause();
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        upgraded.getCheckpoint(uint48(VALID_PROOF_BLOCK_ID));
        vm.expectRevert(SignalService.SS_SIGNAL_NOT_RECEIVED.selector);
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");

        _recordBeaconRoot(FORK_TIME + 1, VALID_PROOF_STATE_ROOT);
        vm.record();
        upgraded.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(FORK_TIME + 1)
        );
        (, bytes32[] memory writes) = vm.accesses(address(upgraded));
        assertEq(writes.length, 1);
        assertEq(writes[0], _cacheSlot(false));
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Deploys real `Anchor` and `SignalService` proxies that name each other.
    function _deployPair(uint64 _beaconRootsFrom) private {
        address signalServiceProxy =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        Anchor anchorImpl = new Anchor(ICheckpointStore(signalServiceProxy), L1_CHAIN_ID);
        _anchor = Anchor(
            address(
                new ERC1967Proxy(address(anchorImpl), abi.encodeCall(Anchor.init, (address(this))))
            )
        );
        SignalService implementation = new SignalService(
            address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), _beaconRootsFrom
        );
        _signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(implementation), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
        assertEq(address(_signalService), signalServiceProxy);
    }

    /// @dev Records `_root` for `_timestamp` the way the EIP-4788 system call does.
    function _recordBeaconRoot(uint64 _timestamp, bytes32 _root) private {
        vm.warp(_timestamp);
        vm.prank(SYSTEM_ADDRESS);
        (bool ok,) = BEACON_ROOTS.call(abi.encode(_root));
        assertTrue(ok, "beacon root not recorded");
    }

    function _saveCheckpoint(uint48 _blockNumber, bytes32 _root) private {
        vm.prank(address(_anchor));
        _signalService.saveCheckpoint(_checkpoint(_blockNumber, _root));
    }

    function _checkpoint(
        uint48 _blockNumber,
        bytes32 _root
    )
        private
        pure
        returns (ICheckpointStore.Checkpoint memory)
    {
        return ICheckpointStore.Checkpoint({
            blockNumber: _blockNumber, blockHash: VALID_BLOCK_HASH, stateRoot: _root
        });
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
