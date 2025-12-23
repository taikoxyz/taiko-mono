// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract AnchorTest is Test {
    uint64 private constant SHASTA_FORK_HEIGHT = 100;
    uint64 private constant L1_CHAIN_ID = 1;
    address private constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    Anchor internal anchor;
    SignalService internal signalService;

    address internal proposer;

    function setUp() external {
        SignalService signalServiceImpl = new SignalService(address(this), address(0x1234));
        signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(signalServiceImpl), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );

        Anchor anchorImpl = new Anchor(signalService, L1_CHAIN_ID);
        anchor = Anchor(
            address(
                new ERC1967Proxy(address(anchorImpl), abi.encodeCall(Anchor.init, (address(this))))
            )
        );

        signalService.upgradeTo(address(new SignalService(address(anchor), address(0x1234))));

        proposer = address(0xA11CE);
    }

    function test_anchorV4_processesFirstBlock() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1);
        ICheckpointStore.Checkpoint memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        Anchor.BlockState memory blockState = anchor.getBlockState();

        assertEq(proposalState.designatedProver, proposer);
        assertFalse(proposalState.isLowBondProposal);
        assertEq(proposalState.proposalId, proposalParams.proposalId);
        assertEq(blockState.anchorBlockNumber, blockParams.blockNumber);
        assertTrue(blockState.ancestorsHash != bytes32(0));

        ICheckpointStore.Checkpoint memory saved =
            signalService.getCheckpoint(blockParams.blockNumber);
        assertEq(saved.blockNumber, blockParams.blockNumber);
        assertEq(saved.blockHash, blockParams.blockHash);
        assertEq(saved.stateRoot, blockParams.stateRoot);
    }

    function test_anchorV4_allowsMultipleBlocksWithoutExtraStateChanges() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1);
        ICheckpointStore.Checkpoint memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalStateBefore = anchor.getProposalState();

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        assertEq(proposalState.proposalId, proposalStateBefore.proposalId);
        assertEq(proposalState.designatedProver, proposalStateBefore.designatedProver);
        assertEq(proposalState.isLowBondProposal, proposalStateBefore.isLowBondProposal);
    }

    function test_anchorV4_rejectsBackwardProposalId() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1);
        ICheckpointStore.Checkpoint memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalParams memory backwardProposal = _proposalParams(0);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.expectRevert(Anchor.ProposalIdMismatch.selector);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(backwardProposal, blockParams);
    }

    function test_anchorV4_switchesProposal() external {
        Anchor.ProposalParams memory firstProposal = _proposalParams(1);
        ICheckpointStore.Checkpoint memory blockParams1 = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(firstProposal, blockParams1);

        Anchor.ProposalParams memory secondProposal = _proposalParams(2);
        ICheckpointStore.Checkpoint memory blockParams2 = _blockParams(1010, 0xABCD, 0xEF01);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(secondProposal, blockParams2);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        Anchor.BlockState memory blockState = anchor.getBlockState();

        assertEq(proposalState.proposalId, 2);
        assertEq(proposalState.designatedProver, proposer);
        assertEq(blockState.anchorBlockNumber, blockParams2.blockNumber);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _proposalParams(uint48 _proposalId)
        internal
        view
        returns (Anchor.ProposalParams memory)
    {
        return Anchor.ProposalParams({ proposalId: _proposalId, proposer: proposer });
    }

    function _blockParams(
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
