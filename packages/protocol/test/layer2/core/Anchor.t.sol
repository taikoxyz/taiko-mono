// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { IL2FeeVault } from "src/layer2/core/IL2FeeVault.sol";
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

contract MockFeeVault is IL2FeeVault {
    uint256 public count;
    uint48 public lastProposalId;
    address public lastProposer;

    function importProposalFee(ProposalFeeData calldata _fee) external override {
        count += 1;
        lastProposalId = _fee.proposalId;
        lastProposer = _fee.proposer;
    }
}

contract AnchorTest is Test {
    uint64 private constant SHASTA_FORK_HEIGHT = 100;
    uint64 private constant L1_CHAIN_ID = 1;
    address private constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
    address private constant PROPOSER = address(0xB0B);

    Anchor internal anchor;
    MockCheckpointStore internal checkpointStore;
    MockFeeVault internal feeVault;

    function setUp() external {
        checkpointStore = new MockCheckpointStore();
        feeVault = new MockFeeVault();

        Anchor anchorImpl = new Anchor(checkpointStore, L1_CHAIN_ID, feeVault);
        anchor = Anchor(
            address(
                new ERC1967Proxy(address(anchorImpl), abi.encodeCall(Anchor.init, (address(this))))
            )
        );
    }

    function test_anchorV4_importsFeeData() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint, 1, _feeData(1, true));

        assertEq(feeVault.count(), 1, "fee count");
        assertEq(feeVault.lastProposalId(), 1, "fee id");
        assertEq(feeVault.lastProposer(), PROPOSER, "fee proposer");
    }

    function test_anchorV4_savesCheckpointAndUpdatesState() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint, 1, _feeData(1, true));

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
        anchor.anchorV4(checkpoint, 1, _feeData(1, true));

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(checkpoint, 1, _feeData(1, false));

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, checkpoint.blockNumber);
        assertEq(feeVault.count(), 1, "fee data only imported once per proposal");
    }

    function test_anchorV4_rejectsInvalidSender() external {
        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.expectRevert(Anchor.InvalidSender.selector);
        anchor.anchorV4(checkpoint, 1, _feeData(1, true));
    }

    function test_anchorV4_ignoresStaleCheckpoint() external {
        ICheckpointStore.Checkpoint memory freshCheckpoint = _checkpoint(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(freshCheckpoint, 1, _feeData(1, true));

        ICheckpointStore.Checkpoint memory staleCheckpoint = _checkpoint(999, 0xAAAA, 0xBBBB);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(staleCheckpoint, 1, _feeData(1, false));

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, freshCheckpoint.blockNumber);
        assertEq(checkpointStore.getCheckpoint(staleCheckpoint.blockNumber).blockNumber, 0);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

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

    function _feeData(
        uint48 _proposalId,
        bool _includeFee
    )
        private
        pure
        returns (IL2FeeVault.ProposalFeeData memory feeData_)
    {
        if (_includeFee) {
            feeData_ = IL2FeeVault.ProposalFeeData({
                proposalId: _proposalId,
                proposer: PROPOSER,
                l1GasUsed: 10,
                numBlobs: 1,
                l1Basefee: 2,
                l1BlobBasefee: 3,
                l2BasefeeRevenue: 100
            });
        }
    }
}
