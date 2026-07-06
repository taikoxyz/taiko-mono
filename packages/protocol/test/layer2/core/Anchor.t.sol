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
    // getPreconfMetadata
    // ---------------------------------------------------------------

    function test_getPreconfMetadata_returnsMetadataForRecordedBlock() external {
        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(
            Anchor.ProposalParams({ submissionWindowEnd: 42 }),
            _blockParamsWithTxList(1000, bytes32(uint256(0xBEEF)))
        );

        Anchor.PreconfMetadata memory metadata = anchor.getPreconfMetadata(block.number);
        assertTrue(metadata.exists);
        assertEq(metadata.anchorBlockNumber, 1000);
        assertEq(metadata.submissionWindowEnd, 42);
        assertEq(metadata.rawTxListHash, bytes32(uint256(0xBEEF)));
    }

    /// @dev Regression test: a block recorded with `anchorBlockNumber == 0` (anchoring skipped)
    /// must remain retrievable. Before the explicit existence flag, `getPreconfMetadata` treated
    /// `anchorBlockNumber == 0` as "never recorded" and reverted, blocking PreconfSlasherL2 from
    /// validating faults for that block or its predecessor.
    function test_getPreconfMetadata_returnsMetadataWhenAnchorBlockNumberIsZero() external {
        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(
            Anchor.ProposalParams({ submissionWindowEnd: 7 }),
            _blockParamsWithTxList(0, bytes32(uint256(0xC0FFEE)))
        );

        Anchor.PreconfMetadata memory metadata = anchor.getPreconfMetadata(block.number);
        assertTrue(metadata.exists);
        assertEq(metadata.anchorBlockNumber, 0);
        assertEq(metadata.submissionWindowEnd, 7);
        assertEq(metadata.rawTxListHash, bytes32(uint256(0xC0FFEE)));
    }

    function test_getPreconfMetadata_RevertWhen_BlockNeverRecorded() external {
        vm.expectRevert(Anchor.InvalidBlockNumber.selector);
        anchor.getPreconfMetadata(999_999);
    }

    function test_getPreconfMetadata_inheritsParentMetadataAcrossBlocks() external {
        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(
            Anchor.ProposalParams({ submissionWindowEnd: 10 }),
            _blockParamsWithTxList(1000, bytes32(uint256(0xAAAA)))
        );

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(
            Anchor.ProposalParams({ submissionWindowEnd: 20 }),
            _blockParamsWithTxList(1001, bytes32(uint256(0xBBBB)))
        );

        Anchor.PreconfMetadata memory childMeta = anchor.getPreconfMetadata(block.number);
        assertTrue(childMeta.exists);
        assertEq(childMeta.submissionWindowEnd, 20);
        assertEq(childMeta.rawTxListHash, bytes32(uint256(0xBBBB)));
        assertEq(childMeta.parentSubmissionWindowEnd, 10);
        assertEq(childMeta.parentRawTxListHash, bytes32(uint256(0xAAAA)));
    }

    /// @dev The parent-linkage counterpart of the zero-anchor regression: a parent recorded with
    /// `anchorBlockNumber == 0` must still propagate its `submissionWindowEnd` / `rawTxListHash`
    /// into the child's parent fields, which `PreconfSlasherL2` consumes.
    function test_getPreconfMetadata_inheritsMetadataThroughZeroAnchorParent() external {
        // Parent block skips anchoring (anchorBlockNumber == 0) but still carries metadata.
        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(
            Anchor.ProposalParams({ submissionWindowEnd: 15 }),
            _blockParamsWithTxList(0, bytes32(uint256(0xDEAD)))
        );

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(
            Anchor.ProposalParams({ submissionWindowEnd: 25 }),
            _blockParamsWithTxList(1001, bytes32(uint256(0xF00D)))
        );

        Anchor.PreconfMetadata memory childMeta = anchor.getPreconfMetadata(block.number);
        assertTrue(childMeta.exists);
        assertEq(childMeta.submissionWindowEnd, 25);
        assertEq(childMeta.parentSubmissionWindowEnd, 15);
        assertEq(childMeta.parentRawTxListHash, bytes32(uint256(0xDEAD)));
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

    function _blockParamsWithTxList(
        uint48 _anchorBlockNumber,
        bytes32 _rawTxListHash
    )
        internal
        pure
        returns (Anchor.BlockParams memory)
    {
        return Anchor.BlockParams({
            anchorBlockNumber: _anchorBlockNumber,
            anchorBlockHash: bytes32(0),
            anchorStateRoot: bytes32(0),
            rawTxListHash: _rawTxListHash
        });
    }
}
