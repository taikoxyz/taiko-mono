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
/// with `usesBeaconRoots`, a real `Anchor` proxy saves checkpoints into it in every block whose own
/// EIP-4788 root is zero (every block before Etna) and in no other block, and proofs resolve their
/// root from a checkpoint first and from the canonical EIP-4788 contract otherwise. No contract
/// holds the fork time: a block is an Etna block because its pre-execution EIP-4788 call recorded
/// a nonzero root, so these tests make each block one or the other through the real system call.
contract TestSignalServiceBeaconRoots is Test, SignalServiceProofFixture {
    uint64 private constant L1_CHAIN_ID = 1;
    uint256 private constant SHASTA_FORK_HEIGHT = 100;
    /// @dev The timestamps of the last block before Etna and of the first Etna block.
    uint64 private constant UNZEN_TIME = 1_800_000_000;
    uint64 private constant ETNA_TIME = 1_800_000_012;
    /// @dev An Etna block's anchor state root that no proof here uses.
    bytes32 private constant ANCHOR_ROOT = bytes32(uint256(0xa1));
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
        _deployPair(true);
    }

    function test_usesBeaconRoots_ReadsTheCanonicalEip4788Contract() external view {
        assertTrue(_signalService.usesBeaconRoots());
        assertEq(_signalService.BEACON_ROOTS(), BEACON_ROOTS);
    }

    // ---------------------------------------------------------------
    // Checkpoint cutoff (vectors 5.w, 5.x and 5.aa)
    // ---------------------------------------------------------------

    /// @dev The store closes by the block's own EIP-4788 root, not by time: a block before Etna
    /// records a zero root and accepts a checkpoint at any timestamp.
    function test_saveCheckpoint_AcceptsInABlockWhoseOwnEip4788RootIsZero() external {
        _unzenBlock(UNZEN_TIME);
        _saveCheckpoint(1000, VALID_PROOF_STATE_ROOT);
        _unzenBlock(UNZEN_TIME + 1_000_000);
        _saveCheckpoint(1001, VALID_PROOF_STATE_ROOT);
        _unzenBlock(type(uint64).max);
        _saveCheckpoint(1002, VALID_PROOF_STATE_ROOT);

        assertEq(_signalService.getCheckpoint(1000).stateRoot, VALID_PROOF_STATE_ROOT);
        assertEq(_signalService.getCheckpoint(1001).stateRoot, VALID_PROOF_STATE_ROOT);
        assertEq(_signalService.getCheckpoint(1002).stateRoot, VALID_PROOF_STATE_ROOT);
    }

    /// @dev An Etna block records its anchor state root, so it accepts no checkpoint, whatever its
    /// timestamp.
    function test_saveCheckpoint_RevertWhen_OwnEip4788RootIsNonzero() external {
        _etnaBlock(1, ANCHOR_ROOT);
        _expectCheckpointsClosed();
        _etnaBlock(ETNA_TIME, ANCHOR_ROOT);
        _expectCheckpointsClosed();
    }

    /// @dev A failed read closes the store too, so a missing EIP-4788 contract or a missing system
    /// write fails closed.
    function test_saveCheckpoint_RevertWhen_Eip4788ReadFails() external {
        _unzenBlock(UNZEN_TIME);

        // No entry for this block's timestamp: the contract reverts.
        vm.warp(UNZEN_TIME + 1);
        _expectCheckpointsClosed();
        vm.warp(UNZEN_TIME);
        vm.etch(BEACON_ROOTS, hex"5f5ffd");
        _expectCheckpointsClosed();

        // A call to an address without code succeeds with no return data.
        vm.etch(BEACON_ROOTS, "");
        _expectCheckpointsClosed();

        // A return of the wrong length.
        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        bytes memory query = abi.encode(uint256(UNZEN_TIME));
        vm.mockCall(BEACON_ROOTS, query, abi.encodePacked(bytes31(0)));
        _expectCheckpointsClosed();
        vm.mockCall(BEACON_ROOTS, query, abi.encode(bytes32(0), bytes32(0)));
        _expectCheckpointsClosed();

        // The recorded zero root opens it again.
        vm.clearMockedCalls();
        _saveCheckpoint(1000, VALID_PROOF_STATE_ROOT);
        assertEq(_signalService.getCheckpoint(1000).stateRoot, VALID_PROOF_STATE_ROOT);
    }

    function test_saveCheckpoint_ChecksTheSyncerBeforeTheCutoff() external {
        _etnaBlock(ETNA_TIME, ANCHOR_ROOT);
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        _signalService.saveCheckpoint(_checkpoint(1000, VALID_PROOF_STATE_ROOT));

        vm.etch(BEACON_ROOTS, "");
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        _signalService.saveCheckpoint(_checkpoint(1000, VALID_PROOF_STATE_ROOT));

        _expectCheckpointsClosed();
    }

    /// @dev Vector 5.w: the real `Anchor` saves its checkpoint in a block before Etna.
    function test_anchorV4_SavesCheckpointInABlockBeforeEtna() external {
        vm.roll(SHASTA_FORK_HEIGHT);
        _unzenBlock(UNZEN_TIME);
        vm.prank(GOLDEN_TOUCH);
        _anchor.anchorV4(_checkpoint(1000, VALID_PROOF_STATE_ROOT));

        assertEq(_signalService.getCheckpoint(1000).stateRoot, VALID_PROOF_STATE_ROOT);
        assertEq(_anchor.getBlockState().anchorBlockNumber, 1000);
    }

    /// @dev Vector 5.x rehearses the fork-boundary forgery: the first Etna block has no anchor
    /// transaction, so an `anchorV4` sent with the public golden touch key as an ordinary
    /// transaction still passes the ancestors-hash check. If it advances the anchor it must revert;
    /// otherwise it only rewrites the `Anchor`'s own block state and forges nothing.
    function test_anchorV4_RevertWhen_ItAdvancesTheAnchorInAnEtnaBlock() external {
        vm.roll(SHASTA_FORK_HEIGHT);
        _unzenBlock(UNZEN_TIME);
        vm.prank(GOLDEN_TOUCH);
        _anchor.anchorV4(_checkpoint(1000, VALID_PROOF_STATE_ROOT));

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        _etnaBlock(ETNA_TIME, ANCHOR_ROOT);
        vm.deal(GOLDEN_TOUCH, 1 ether);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(SignalService.SS_CHECKPOINTS_CLOSED.selector);
        _anchor.anchorV4(_checkpoint(2000, bytes32(uint256(0xbad))));

        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        _signalService.getCheckpoint(2000);
        assertEq(_anchor.getBlockState().anchorBlockNumber, 1000);

        vm.prank(GOLDEN_TOUCH);
        _anchor.anchorV4(_checkpoint(1000, bytes32(uint256(0xbad))));
        assertEq(_signalService.getCheckpoint(1000).stateRoot, VALID_PROOF_STATE_ROOT);
        assertEq(_anchor.getBlockState().anchorBlockNumber, 1000);
    }

    /// @dev Vector 5.aa: on a new network every block after the L2 genesis block is an Etna block,
    /// so no checkpoint is accepted in any of them, and proofs use their EIP-4788 roots.
    function test_anchorV4_RevertWhen_NewNetworkBlockAfterGenesisAdvancesTheAnchor() external {
        vm.roll(1);
        _etnaBlock(1, VALID_PROOF_STATE_ROOT);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(SignalService.SS_CHECKPOINTS_CLOSED.selector);
        _anchor.anchorV4(_checkpoint(1, bytes32(uint256(0xbad))));
        _expectCheckpointsClosed();

        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(1)
        );
    }

    // ---------------------------------------------------------------
    // Root resolution (vectors 5.y and 5.z)
    // ---------------------------------------------------------------

    /// @dev Vector 5.z: after the fork, a proof whose `blockId` is an L1 block number with a
    /// checkpoint saved before the fork resolves its root from that checkpoint.
    function test_verifySignalReceived_UsesACheckpointSavedBeforeTheFork() external {
        _unzenBlock(UNZEN_TIME);
        _saveCheckpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );

        _etnaBlock(ETNA_TIME, ANCHOR_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        assertEq(
            _signalService.proveSignalReceived(
                SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
            ),
            0
        );
    }

    /// @dev Vector 5.y: an uncached proof whose `blockId` is the timestamp of an Etna block, for
    /// which no checkpoint is held, resolves its root through EIP-4788, in that block and later.
    function test_verifySignalReceived_ResolvesAnEtnaBlockRootThroughEip4788() external {
        _etnaBlock(ETNA_TIME, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIME)
        );

        _etnaBlock(ETNA_TIME + 12, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIME)
        );
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIME + 12)
        );
    }

    /// @dev A checkpoint answers first even when EIP-4788 holds a root for the same id: both
    /// stores hold only L1 state roots, so the proof is compared with the checkpoint's root alone.
    /// Only what the stores hold matters here, not when it was written.
    function test_verifySignalReceived_ChecksTheCheckpointBeforeEip4788() external {
        uint64 shadowed = UNZEN_TIME - 100;
        _recordBeaconRoot(VALID_PROOF_BLOCK_ID, bytes32(uint256(123)));
        _recordBeaconRoot(shadowed, VALID_PROOF_STATE_ROOT);
        _unzenBlock(UNZEN_TIME);
        _saveCheckpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT);
        _saveCheckpoint(uint48(shadowed), bytes32(uint256(123)));
        _etnaBlock(ETNA_TIME, ANCHOR_ROOT);

        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        ISignalService.HopProof[] memory proofs =
            abi.decode(VALID_SIGNAL_PROOF, (ISignalService.HopProof[]));
        proofs[0].rootHash = bytes32(uint256(123));
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );

        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(shadowed)
        );
    }

    /// @dev An id with no checkpoint and no live, nonzero EIP-4788 root rejects with
    /// `SS_CHECKPOINT_NOT_FOUND`, the error relayers treat as transient.
    function test_verifySignalReceived_RevertWhen_NeitherStoreHoldsTheId() external {
        _unzenBlock(UNZEN_TIME);
        _etnaBlock(ETNA_TIME, ANCHOR_ROOT);

        // A block before Etna recorded a zero root.
        _expectCheckpointNotFound(_timestampProof(UNZEN_TIME));
        // No EIP-4788 entry: a later timestamp, and timestamp 0, which the contract never serves.
        _expectCheckpointNotFound(_timestampProof(ETNA_TIME + 1));
        _expectCheckpointNotFound(_timestampProof(0));
        // An L1 block number with no checkpoint.
        _expectCheckpointNotFound(VALID_SIGNAL_PROOF);
    }

    function test_verifySignalReceived_RevertWhen_Eip4788EntryOverwritten() external {
        _etnaBlock(ETNA_TIME, VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIME)
        );

        _etnaBlock(ETNA_TIME + 8191, bytes32(uint256(123)));
        _expectCheckpointNotFound(_timestampProof(ETNA_TIME));
    }

    function test_verifySignalReceived_RevertWhen_Eip4788ReturnIsMalformed() external {
        _etnaBlock(ETNA_TIME, VALID_PROOF_STATE_ROOT);
        bytes memory proof = _timestampProof(ETNA_TIME);
        bytes memory query = abi.encode(uint256(ETNA_TIME));

        // A call to an address without code succeeds with no return data.
        vm.etch(BEACON_ROOTS, "");
        _expectCheckpointNotFound(proof);
        vm.etch(BEACON_ROOTS, hex"5f5ffd");
        _expectCheckpointNotFound(proof);

        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        vm.mockCall(BEACON_ROOTS, query, abi.encodePacked(bytes31(VALID_PROOF_STATE_ROOT)));
        _expectCheckpointNotFound(proof);
        vm.mockCall(BEACON_ROOTS, query, abi.encode(VALID_PROOF_STATE_ROOT, bytes32(0)));
        _expectCheckpointNotFound(proof);

        vm.clearMockedCalls();
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, proof);
    }

    function test_verifySignalReceived_RevertWhen_RootHashDiffersFromEip4788Root() external {
        _etnaBlock(ETNA_TIME, bytes32(uint256(123)));

        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIME)
        );
    }

    function test_verifySignalReceived_RevertWhen_MerkleProofTampered() external {
        _etnaBlock(ETNA_TIME, VALID_PROOF_STATE_ROOT);
        ISignalService.HopProof[] memory proofs =
            abi.decode(_timestampProof(ETNA_TIME), (ISignalService.HopProof[]));
        proofs[0].storageProof[0][3] ^= bytes1(uint8(1));

        vm.expectRevert();
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, abi.encode(proofs)
        );
    }

    /// @dev The `uint48` bound belongs only to the checkpoint lookup: an id above it reads
    /// EIP-4788 at the full `uint64` timestamp, never a checkpoint or an entry at its truncation.
    function test_verifySignalReceived_UsesFullUint64Timestamp() external {
        uint64 timestamp = ETNA_TIME + (uint64(1) << 48);
        _unzenBlock(UNZEN_TIME);
        _saveCheckpoint(uint48(ETNA_TIME), bytes32(uint256(123)));
        _etnaBlock(ETNA_TIME, bytes32(uint256(123)));
        _etnaBlock(timestamp, VALID_PROOF_STATE_ROOT);

        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(timestamp)
        );
    }

    function test_proveSignalReceived_CacheSurvivesEip4788Expiry() external {
        _etnaBlock(ETNA_TIME, VALID_PROOF_STATE_ROOT);
        assertEq(
            _signalService.proveSignalReceived(
                SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIME)
            ),
            0
        );
        assertEq(vm.load(address(_signalService), _cacheSlot(false)), bytes32(uint256(1)));
        assertEq(vm.load(address(_signalService), _cacheSlot(true)), bytes32(0));

        _etnaBlock(ETNA_TIME + 8191, bytes32(uint256(123)));
        _expectCheckpointNotFound(_timestampProof(ETNA_TIME));

        // An empty proof reads only the cache, even once EIP-4788 itself fails.
        vm.etch(BEACON_ROOTS, hex"5f5ffd");
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
        _signalService.proveSignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, "");
    }

    // ---------------------------------------------------------------
    // The L1 configuration (vectors 5.s and 5.t)
    // ---------------------------------------------------------------

    /// @dev With `usesBeaconRoots` false, as on L1, the checkpoint store never closes and is the
    /// only root source: EIP-4788 is never read, even when it holds a nonzero root for the current
    /// block or for the proof's id.
    function test_withoutBeaconRoots_CheckpointsNeverCloseAndEip4788IsNeverRead() external {
        _deployPair(false);
        assertFalse(_signalService.usesBeaconRoots());
        _recordBeaconRoot(ETNA_TIME, VALID_PROOF_STATE_ROOT);
        vm.expectCall(BEACON_ROOTS, "", 0);

        _saveCheckpoint(1000, VALID_PROOF_STATE_ROOT);
        _expectCheckpointNotFound(_timestampProof(ETNA_TIME));
        _expectCheckpointNotFound(VALID_SIGNAL_PROOF);

        _saveCheckpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT);
        _signalService.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        // An id above `uint48` names no checkpoint, not the one at its truncation.
        _expectCheckpointNotFound(_timestampProof(VALID_PROOF_BLOCK_ID + (uint64(1) << 48)));

        vm.etch(BEACON_ROOTS, "");
        vm.warp(type(uint64).max);
        _saveCheckpoint(1001, VALID_PROOF_STATE_ROOT);
        assertEq(_signalService.getCheckpoint(1001).stateRoot, VALID_PROOF_STATE_ROOT);
    }

    // ---------------------------------------------------------------
    // Proxy upgrade
    // ---------------------------------------------------------------

    function test_proxyUpgrade_PreservesVersionOneRecordsOwnerPausedStateAndSentSignal() external {
        // A `VERSION` 1 implementation without beacon roots, the L1 configuration.
        SignalService versionOne = SignalService(
            address(
                new ERC1967Proxy(
                    address(
                        new SignalService(
                            address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), false
                        )
                    ),
                    abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );
        vm.prank(address(_anchor));
        versionOne.saveCheckpoint(_checkpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT));
        versionOne.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        bytes32 localSignal = keccak256("version one signal");
        versionOne.sendSignal(localSignal);
        versionOne.pause();

        versionOne.upgradeTo(
            address(new SignalService(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), true))
        );
        _etnaBlock(ETNA_TIME, ANCHOR_ROOT);

        assertEq(versionOne.VERSION(), 1);
        assertTrue(versionOne.usesBeaconRoots());
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
        versionOne.verifySignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF
        );
        vm.prank(address(_anchor));
        vm.expectRevert(SignalService.SS_CHECKPOINTS_CLOSED.selector);
        versionOne.saveCheckpoint(_checkpoint(1000, VALID_PROOF_STATE_ROOT));
    }

    /// @dev The upgrade from the flat pre-Etna layout empties the checkpoint store and the cache;
    /// an uncached proof waits for the next anchor transaction that advances the anchor, or for an
    /// Etna block's EIP-4788 root.
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
            address(new SignalService(address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), true))
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
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF);

        // A block before Etna: the anchor's next checkpoint lands in the versioned store.
        _unzenBlock(UNZEN_TIME);
        vm.prank(address(_anchor));
        upgraded.saveCheckpoint(_checkpoint(uint48(VALID_PROOF_BLOCK_ID), VALID_PROOF_STATE_ROOT));
        assertEq(vm.load(address(upgraded), _checkpointSlot(false)), VALID_BLOCK_HASH);
        upgraded.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, VALID_SIGNAL_PROOF);

        _etnaBlock(ETNA_TIME, VALID_PROOF_STATE_ROOT);
        vm.record();
        upgraded.proveSignalReceived(
            SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _timestampProof(ETNA_TIME)
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
    function _deployPair(bool _usesBeaconRoots) private {
        address signalServiceProxy =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        Anchor anchorImpl = new Anchor(ICheckpointStore(signalServiceProxy), L1_CHAIN_ID);
        _anchor = Anchor(
            address(
                new ERC1967Proxy(address(anchorImpl), abi.encodeCall(Anchor.init, (address(this))))
            )
        );
        SignalService implementation = new SignalService(
            address(_anchor), REMOTE_SIGNAL_SERVICE, address(0), _usesBeaconRoots
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

    /// @dev Starts a block before Etna at `_timestamp`: its EIP-4788 call records a zero root.
    function _unzenBlock(uint64 _timestamp) private {
        _recordBeaconRoot(_timestamp, bytes32(0));
    }

    /// @dev Starts an Etna block at `_timestamp` whose anchor state root is `_root`.
    function _etnaBlock(uint64 _timestamp, bytes32 _root) private {
        assertTrue(_root != 0, "an Etna block has a nonzero root");
        _recordBeaconRoot(_timestamp, _root);
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

    /// @dev Expects the `Anchor`'s next checkpoint to be refused in the current block.
    function _expectCheckpointsClosed() private {
        vm.prank(address(_anchor));
        vm.expectRevert(SignalService.SS_CHECKPOINTS_CLOSED.selector);
        _signalService.saveCheckpoint(_checkpoint(1000, VALID_PROOF_STATE_ROOT));
    }

    function _expectCheckpointNotFound(bytes memory _proof) private {
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        _signalService.verifySignalReceived(SOURCE_CHAIN_ID, REMOTE_APP, VALID_SIGNAL, _proof);
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
