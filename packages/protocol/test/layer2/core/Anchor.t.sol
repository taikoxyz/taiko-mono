// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract MockCheckpointStore is ICheckpointStore {
    mapping(uint48 blockNumber => Checkpoint checkpoint) private _checkpoints;

    function saveCheckpoint(Checkpoint calldata _checkpoint) external override {
        _checkpoints[_checkpoint.blockNumber] = _checkpoint;
    }

    function getCheckpoint(uint48 _blockNumber) external view override returns (Checkpoint memory) {
        return _checkpoints[_blockNumber];
    }
}

abstract contract AnchorTestBase is Test {
    uint64 internal constant L1_CHAIN_ID = 1;
    uint64 internal constant ETNA_TIMESTAMP = 1_800_000_000;
    address internal constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    function _deployAnchor(
        ICheckpointStore _checkpointStore,
        uint64 _etnaTimestamp
    )
        internal
        returns (Anchor)
    {
        Anchor anchorImpl = new Anchor(_checkpointStore, L1_CHAIN_ID, _etnaTimestamp);
        return Anchor(
            address(
                new ERC1967Proxy(address(anchorImpl), abi.encodeCall(Anchor.init, (address(this))))
            )
        );
    }

    function _checkpoint(
        uint48 _blockNumber,
        uint256 _blockHash,
        uint256 _stateRoot
    )
        internal
        pure
        returns (ICheckpointStore.Checkpoint memory)
    {
        return ICheckpointStore.Checkpoint({
            blockNumber: _blockNumber,
            blockHash: bytes32(_blockHash),
            stateRoot: bytes32(_stateRoot)
        });
    }
}

contract AnchorTest is AnchorTestBase {
    uint64 private constant SHASTA_FORK_HEIGHT = 100;

    Anchor internal anchor;
    MockCheckpointStore internal checkpointStore;

    function setUp() external {
        checkpointStore = new MockCheckpointStore();
        anchor = _deployAnchor(checkpointStore, type(uint64).max);
    }

    function test_anchorV4_savesCheckpointAndUpdatesState() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, checkpoint.blockNumber);
        assertTrue(blockState.ancestorsHash != bytes32(0));

        ICheckpointStore.Checkpoint memory saved =
            checkpointStore.getCheckpoint(checkpoint.blockNumber);
        assertEq(saved.blockNumber, checkpoint.blockNumber);
        assertEq(saved.blockHash, checkpoint.blockHash);
        assertEq(saved.stateRoot, checkpoint.stateRoot);

        assertEq(anchor.blockHashes(block.number - 1), blockhash(block.number - 1));
    }

    function test_anchorV4_allowsMultipleAnchorsAcrossBlocks() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, checkpoint.blockNumber);
    }

    function test_anchorV4_rejectsInvalidSender() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.expectRevert(Anchor.InvalidSender.selector);
        anchor.anchorV4(checkpoint);
    }

    function test_anchorV4_ignoresStaleCheckpoint() external {
        ICheckpointStore.Checkpoint memory freshCheckpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(freshCheckpoint);

        ICheckpointStore.Checkpoint memory staleCheckpoint = _checkpoint(999, 0xAAAA, 0xBBBB);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(staleCheckpoint);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, freshCheckpoint.blockNumber);
        assertEq(checkpointStore.getCheckpoint(staleCheckpoint.blockNumber).blockNumber, 0);
    }

    function test_anchorV4_succeedsBeforeEtna() external {
        Anchor etnaAnchor = _deployAnchor(checkpointStore, ETNA_TIMESTAMP);
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(ETNA_TIMESTAMP - 1);
        vm.prank(GOLDEN_TOUCH);
        etnaAnchor.anchorV4(checkpoint);

        assertEq(etnaAnchor.getBlockState().anchorBlockNumber, checkpoint.blockNumber);
        assertEq(etnaAnchor.etnaTimestamp(), ETNA_TIMESTAMP);
    }

    function test_anchorV4_RevertWhen_AtOrAfterEtna() external {
        Anchor etnaAnchor = _deployAnchor(checkpointStore, ETNA_TIMESTAMP);
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);
        vm.roll(SHASTA_FORK_HEIGHT);

        vm.warp(ETNA_TIMESTAMP);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        etnaAnchor.anchorV4(checkpoint);

        vm.warp(ETNA_TIMESTAMP + 1);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        etnaAnchor.anchorV4(checkpoint);
    }

    function test_anchorV4_RevertWhen_EtnaActiveFromGenesis() external {
        Anchor etnaAnchor = _deployAnchor(checkpointStore, 0);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(0);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        etnaAnchor.anchorV4(_checkpoint(1000, 0x1234, 0x5678));
    }

    function test_anchorV4_succeedsWhenEtnaNeverActivates() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(type(uint64).max - 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint);

        assertEq(anchor.getBlockState().anchorBlockNumber, checkpoint.blockNumber);
    }

    /// @dev Rehearses the fork-time forgery: in the first anchorless block, the public golden-touch
    /// key must not be able to anchor a forged checkpoint.
    function test_anchorV4_RevertWhen_ForgedInFirstEtnaBlock() external {
        Anchor etnaAnchor = _deployAnchor(checkpointStore, ETNA_TIMESTAMP);
        ICheckpointStore.Checkpoint memory lastCheckpoint = _checkpoint(1000, 0x1234, 0x5678);

        // The last pre-Etna block anchors normally.
        vm.roll(SHASTA_FORK_HEIGHT);
        vm.warp(ETNA_TIMESTAMP - 1);
        vm.prank(GOLDEN_TOUCH);
        etnaAnchor.anchorV4(lastCheckpoint);
        Anchor.BlockState memory stateBefore = etnaAnchor.getBlockState();

        // The first Etna block has no anchor transaction; a funded golden-touch call is rejected.
        ICheckpointStore.Checkpoint memory forged = _checkpoint(2000, 0xBAD, 0xBAD);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.warp(ETNA_TIMESTAMP);
        vm.deal(GOLDEN_TOUCH, 1 ether);
        vm.prank(GOLDEN_TOUCH);
        vm.expectRevert(Anchor.AnchorDisabled.selector);
        etnaAnchor.anchorV4(forged);

        assertEq(checkpointStore.getCheckpoint(forged.blockNumber).blockHash, bytes32(0));
        Anchor.BlockState memory stateAfter = etnaAnchor.getBlockState();
        assertEq(stateAfter.anchorBlockNumber, stateBefore.anchorBlockNumber);
        assertEq(stateAfter.ancestorsHash, stateBefore.ancestorsHash);
    }
}
