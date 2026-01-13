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

contract AnchorTest is Test {
    uint64 private constant SHASTA_FORK_HEIGHT = 100;
    uint64 private constant L1_CHAIN_ID = 1;
    address private constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    Anchor internal anchor;
    MockCheckpointStore internal checkpointStore;

    function setUp() external {
        checkpointStore = new MockCheckpointStore();

        Anchor anchorImpl = new Anchor(checkpointStore, L1_CHAIN_ID);
        anchor = Anchor(
            address(
                new ERC1967Proxy(address(anchorImpl), abi.encodeCall(Anchor.init, (address(this))))
            )
        );
    }

    function test_anchorV4_savesCheckpointAndUpdatesState() external {
        Anchor.ProposalParams memory proposalParams =
            Anchor.ProposalParams({ submissionWindowEnd: 0 });
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, blockParams.anchorBlockNumber);
        assertTrue(blockState.ancestorsHash != bytes32(0));

        ICheckpointStore.Checkpoint memory saved =
            checkpointStore.getCheckpoint(blockParams.anchorBlockNumber);
        assertEq(saved.blockNumber, blockParams.anchorBlockNumber);
        assertEq(saved.blockHash, blockParams.anchorBlockHash);
        assertEq(saved.stateRoot, blockParams.anchorStateRoot);

        assertEq(anchor.blockHashes(block.number - 1), blockhash(block.number - 1));
    }

    function test_anchorV4_allowsMultipleAnchorsAcrossBlocks() external {
        Anchor.ProposalParams memory proposalParams =
            Anchor.ProposalParams({ submissionWindowEnd: 0 });
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, blockParams.anchorBlockNumber);
    }

    function test_anchorV4_rejectsInvalidSender() external {
        Anchor.ProposalParams memory proposalParams =
            Anchor.ProposalParams({ submissionWindowEnd: 0 });
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.expectRevert(Anchor.InvalidSender.selector);
        anchor.anchorV4(proposalParams, blockParams);
    }

    function test_anchorV4_ignoresStaleCheckpoint() external {
        Anchor.ProposalParams memory proposalParams =
            Anchor.ProposalParams({ submissionWindowEnd: 0 });
        Anchor.BlockParams memory freshBlockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, freshBlockParams);

        Anchor.BlockParams memory staleBlockParams = _blockParams(999, 0xAAAA, 0xBBBB);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, staleBlockParams);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, freshBlockParams.anchorBlockNumber);
        assertEq(checkpointStore.getCheckpoint(staleBlockParams.anchorBlockNumber).blockNumber, 0);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _blockParams(
        uint48 _blockNumber,
        uint256 _blockHash,
        uint256 _stateRoot
    )
        internal
        pure
        returns (Anchor.BlockParams memory)
    {
        return Anchor.BlockParams({
            anchorBlockNumber: _blockNumber,
            anchorBlockHash: bytes32(_blockHash),
            anchorStateRoot: bytes32(_stateRoot),
            rawTxListHash: bytes32(0)
        });
    }
}
