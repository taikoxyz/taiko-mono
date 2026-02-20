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

    function importProposalFeeList(ProposalFeeData[] calldata _fees) external override {
        uint256 feesLength = _fees.length;
        count += feesLength;
        if (feesLength == 0) return;

        ProposalFeeData calldata lastFee = _fees[feesLength - 1];
        lastProposalId = lastFee.proposalId;
        lastProposer = lastFee.proposer;
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
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, _singleProposalIdList(1));
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        assertEq(feeVault.count(), 1, "fee count");
        assertEq(feeVault.lastProposalId(), 1, "fee id");
        assertEq(feeVault.lastProposer(), PROPOSER, "fee proposer");
    }

    function test_anchorV4_savesCheckpointAndUpdatesState() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, _singleProposalIdList(1));
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
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, _singleProposalIdList(1));
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(_proposalParams(1, _emptyProposalIdList()), blockParams);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, blockParams.anchorBlockNumber);
    }

    function test_anchorV4_rejectsInvalidSender() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, _singleProposalIdList(1));
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.expectRevert(Anchor.InvalidSender.selector);
        anchor.anchorV4(proposalParams, blockParams);
    }

    function test_anchorV4_ignoresStaleCheckpoint() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, _singleProposalIdList(1));
        Anchor.BlockParams memory freshBlockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, freshBlockParams);

        Anchor.BlockParams memory staleBlockParams = _blockParams(999, 0xAAAA, 0xBBBB);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(_proposalParams(1, _emptyProposalIdList()), staleBlockParams);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, freshBlockParams.anchorBlockNumber);
        assertEq(checkpointStore.getCheckpoint(staleBlockParams.anchorBlockNumber).blockNumber, 0);
    }

    function test_anchorV4_importsMultipleFeeDataInOneBlock() external {
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        uint48[] memory feeProposalIds = new uint48[](3);
        feeProposalIds[0] = 1;
        feeProposalIds[1] = 2;
        feeProposalIds[2] = 3;

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(_proposalParams(3, feeProposalIds), blockParams);

        assertEq(feeVault.count(), 3, "fee count");
        assertEq(feeVault.lastProposalId(), 3, "last imported fee proposal");
    }

    function test_anchorV4_importsCatchupFeeDataAcrossBlocks() external {
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(_proposalParams(3, _singleProposalIdList(1)), blockParams);

        uint48[] memory catchupFeeProposalIds = new uint48[](2);
        catchupFeeProposalIds[0] = 2;
        catchupFeeProposalIds[1] = 3;

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(_proposalParams(3, catchupFeeProposalIds), blockParams);

        assertEq(feeVault.count(), 3, "all fee proposals imported");
        assertEq(feeVault.lastProposalId(), 3, "last imported fee proposal");
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

    function _proposalParams(uint48 _proposalId, uint48[] memory _feeProposalIds)
        private
        pure
        returns (Anchor.ProposalParams memory)
    {
        IL2FeeVault.ProposalFeeData[] memory feeDataList =
            new IL2FeeVault.ProposalFeeData[](_feeProposalIds.length);
        for (uint256 i; i < _feeProposalIds.length; ++i) {
            feeDataList[i] = IL2FeeVault.ProposalFeeData({
                proposalId: _feeProposalIds[i],
                proposer: PROPOSER,
                l1GasUsed: 10,
                numBlobs: 1,
                l1Basefee: 2,
                l1BlobBasefee: 3,
                l2BasefeeRevenue: 100
            });
        }

        return Anchor.ProposalParams({
            proposalId: _proposalId,
            submissionWindowEnd: 0,
            feeDataList: feeDataList
        });
    }

    function _singleProposalIdList(uint48 _proposalId) private pure returns (uint48[] memory ids_) {
        ids_ = new uint48[](1);
        ids_[0] = _proposalId;
    }

    function _emptyProposalIdList() private pure returns (uint48[] memory ids_) {
        ids_ = new uint48[](0);
    }
}
