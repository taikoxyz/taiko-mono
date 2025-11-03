// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { BondManager } from "src/layer2/core/BondManager.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

contract AnchorTest is Test {
    uint256 private constant LIVENESS_BOND = 5 ether;
    uint256 private constant PROVABILITY_BOND = 7 ether;
    uint64 private constant BLOCK_HEIGHT = 100;
    uint64 private constant L1_CHAIN_ID = 1;

    Anchor internal anchor;
    BondManager internal bondManager;
    SignalService internal checkpointStore;
    TestERC20 internal token;

    address internal proposer;
    address internal proverCandidate;
    uint256 internal proverKey;

    address internal constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
    uint256 internal constant INITIAL_PROPOSER_BOND = 100 ether;
    uint256 internal constant INITIAL_PROVER_BOND = 50 ether;

    function setUp() external {
        token = new TestERC20("Mock", "MOCK");

        BondManager bondManagerImpl = new BondManager(address(this), address(token), 0, 0);
        bondManager = BondManager(
            address(
                new ERC1967Proxy(
                    address(bondManagerImpl), abi.encodeCall(BondManager.init, (address(this)))
                )
            )
        );

        SignalService signalServiceImpl = new SignalService(address(this), address(0x1234));
        checkpointStore = SignalService(
            address(
                new ERC1967Proxy(
                    address(signalServiceImpl), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );

        anchor = new Anchor(
            checkpointStore,
            bondManager,
            LIVENESS_BOND,
            PROVABILITY_BOND,
            L1_CHAIN_ID,
            address(this)
        );

        BondManager anchorBondManagerImpl = new BondManager(address(anchor), address(token), 0, 0);
        bondManager.upgradeTo(address(anchorBondManagerImpl));

        SignalService anchorSignalServiceImpl = new SignalService(address(anchor), address(0x1234));
        checkpointStore.upgradeTo(address(anchorSignalServiceImpl));

        proposer = address(0xA11CE);
        proverKey = 0xBEEF;
        proverCandidate = vm.addr(proverKey);

        token.mint(proposer, INITIAL_PROPOSER_BOND);
        vm.startPrank(proposer);
        token.approve(address(bondManager), type(uint256).max);
        bondManager.deposit(INITIAL_PROPOSER_BOND);
        vm.stopPrank();

        token.mint(proverCandidate, INITIAL_PROVER_BOND);
        vm.startPrank(proverCandidate);
        token.approve(address(bondManager), type(uint256).max);
        bondManager.deposit(INITIAL_PROVER_BOND);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // anchorV4
    // ---------------------------------------------------------------

    function test_anchorV4_ProcessesFirstBlock() external {
        (Anchor.ProposalParams memory proposalParams, Anchor.BlockParams memory blockParams) =
            _prepareAnchorCall();

        vm.roll(BLOCK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        Anchor.BlockState memory blockState = anchor.getBlockState();

        assertEq(proposalState.designatedProver, proverCandidate);
        assertFalse(proposalState.isLowBondProposal);
        assertEq(proposalState.proposalId, proposalParams.proposalId);
        assertEq(proposalState.bondInstructionsHash, proposalParams.bondInstructionsHash);

        assertEq(blockState.anchorBlockNumber, blockParams.anchorBlockNumber);
        assertTrue(blockState.ancestorsHash != bytes32(0));

        assertEq(
            bondManager.getBondBalance(proposer),
            INITIAL_PROPOSER_BOND - 1 ether - LIVENESS_BOND - PROVABILITY_BOND
        );
        assertEq(bondManager.getBondBalance(proverCandidate), INITIAL_PROVER_BOND + 1 ether);
        assertEq(bondManager.getBondBalance(address(0xCA1)), LIVENESS_BOND);
        assertEq(bondManager.getBondBalance(address(0xCA2)), PROVABILITY_BOND);

        ICheckpointStore.Checkpoint memory saved =
            checkpointStore.getCheckpoint(blockParams.anchorBlockNumber);
        assertEq(saved.blockNumber, blockParams.anchorBlockNumber);
        assertEq(saved.blockHash, blockParams.anchorBlockHash);
        assertEq(saved.stateRoot, blockParams.anchorStateRoot);
    }

    function test_anchorV4_RevertWhen_InvalidSender() external {
        (Anchor.ProposalParams memory proposalParams, Anchor.BlockParams memory blockParams) =
            _prepareAnchorCall();

        vm.roll(BLOCK_HEIGHT);
        vm.expectRevert(Anchor.InvalidSender.selector);
        anchor.anchorV4(proposalParams, blockParams);
    }

    function test_anchorV4_AllowsSubsequentBlocksWithSameProposal() external {
        (Anchor.ProposalParams memory proposalParams, Anchor.BlockParams memory blockParams) =
            _prepareAnchorCall();

        vm.roll(BLOCK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        vm.roll(BLOCK_HEIGHT + 1);

        Anchor.BlockParams memory secondBlockParams = Anchor.BlockParams({
            anchorBlockNumber: blockParams.anchorBlockNumber,
            anchorBlockHash: blockParams.anchorBlockHash,
            anchorStateRoot: blockParams.anchorStateRoot
        });

        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, secondBlockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        assertEq(proposalState.proposalId, proposalParams.proposalId);
    }

    function test_anchorV4_RevertWhen_ProposalIdGoesBackward() external {
        (Anchor.ProposalParams memory proposalParams, Anchor.BlockParams memory blockParams) =
            _prepareAnchorCall();

        vm.roll(BLOCK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        vm.roll(BLOCK_HEIGHT + 1);

        Anchor.ProposalParams memory backwardProposal = proposalParams;
        backwardProposal.proposalId = 0;

        vm.expectRevert(Anchor.ProposalIdMismatch.selector);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(backwardProposal, blockParams);
    }

    function test_anchorV4_AllowsTransitionToNewProposal() external {
        (Anchor.ProposalParams memory proposalParams1, Anchor.BlockParams memory blockParams1) =
            _prepareAnchorCall();

        vm.roll(BLOCK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams1, blockParams1);

        Anchor.ProposalState memory stateAfterFirstProposal = anchor.getProposalState();
        assertEq(stateAfterFirstProposal.proposalId, 1);
        assertEq(stateAfterFirstProposal.designatedProver, proverCandidate);
        bytes32 previousBondHash = stateAfterFirstProposal.bondInstructionsHash;

        vm.roll(BLOCK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams1, blockParams1);

        vm.roll(BLOCK_HEIGHT + 2);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams1, blockParams1);

        vm.roll(BLOCK_HEIGHT + 3);

        uint48 proposalId2 = 2;
        LibBonds.BondInstruction[] memory instructions2 = new LibBonds.BondInstruction[](2);

        instructions2[0] = LibBonds.BondInstruction({
            proposalId: proposalId2,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: address(0xCA1)
        });

        instructions2[1] = LibBonds.BondInstruction({
            proposalId: proposalId2,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: proposer,
            payee: address(0xCA2)
        });

        bytes32 expectedHash2 =
            LibBonds.aggregateBondInstruction(previousBondHash, instructions2[0]);
        expectedHash2 = LibBonds.aggregateBondInstruction(expectedHash2, instructions2[1]);

        uint256 provingFee2 = 2 ether;
        bytes memory proverAuth2 = _buildProverAuth(proposalId2, provingFee2);

        Anchor.ProposalParams memory proposalParams2 = Anchor.ProposalParams({
            proposalId: proposalId2,
            proposer: proposer,
            proverAuth: proverAuth2,
            bondInstructionsHash: expectedHash2,
            bondInstructions: instructions2
        });

        Anchor.BlockParams memory blockParams2 = Anchor.BlockParams({
            anchorBlockNumber: 1010,
            anchorBlockHash: bytes32(uint256(0xABCD)),
            anchorStateRoot: bytes32(uint256(0xEF01))
        });

        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams2, blockParams2);

        Anchor.ProposalState memory stateAfterSecondProposal = anchor.getProposalState();
        assertEq(stateAfterSecondProposal.proposalId, 2);
        assertEq(stateAfterSecondProposal.designatedProver, proverCandidate);
        assertEq(stateAfterSecondProposal.bondInstructionsHash, expectedHash2);
        assertFalse(stateAfterSecondProposal.isLowBondProposal);

        Anchor.BlockState memory blockState = anchor.getBlockState();
        assertEq(blockState.anchorBlockNumber, 1010);
    }

    function test_anchorV4_HandlesMultipleBlocksInProposal() external {
        (Anchor.ProposalParams memory proposalParams, Anchor.BlockParams memory blockParams) =
            _prepareAnchorCall();

        vm.roll(BLOCK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        uint256 proposerBalanceAfterFirst = bondManager.getBondBalance(proposer);
        uint256 proverBalanceAfterFirst = bondManager.getBondBalance(proverCandidate);
        Anchor.ProposalState memory stateAfterFirst = anchor.getProposalState();

        vm.roll(BLOCK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory stateAfterSecond = anchor.getProposalState();
        assertEq(stateAfterSecond.proposalId, stateAfterFirst.proposalId);
        assertEq(stateAfterSecond.designatedProver, stateAfterFirst.designatedProver);
        assertEq(stateAfterSecond.bondInstructionsHash, stateAfterFirst.bondInstructionsHash);
        assertEq(
            bondManager.getBondBalance(proposer),
            proposerBalanceAfterFirst,
            "Proposer balance should not change on second block"
        );
        assertEq(
            bondManager.getBondBalance(proverCandidate),
            proverBalanceAfterFirst,
            "Prover balance should not change on second block"
        );

        vm.roll(BLOCK_HEIGHT + 2);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory stateAfterThird = anchor.getProposalState();
        assertEq(stateAfterThird.proposalId, stateAfterFirst.proposalId);
        assertEq(stateAfterThird.designatedProver, stateAfterFirst.designatedProver);
        assertEq(stateAfterThird.bondInstructionsHash, stateAfterFirst.bondInstructionsHash);
        assertEq(
            bondManager.getBondBalance(proposer),
            proposerBalanceAfterFirst,
            "Proposer balance should not change on third block"
        );
        assertEq(
            bondManager.getBondBalance(proverCandidate),
            proverBalanceAfterFirst,
            "Prover balance should not change on third block"
        );
    }

    // ---------------------------------------------------------------
    // getDesignatedProver
    // ---------------------------------------------------------------

    function test_getDesignatedProver_ReturnsLowBondWhenInsufficient() external {
        bytes memory auth = _buildProverAuth(1, 5 ether);

        vm.prank(address(anchor));
        bondManager.debitBond(proposer, type(uint256).max);
        vm.prank(address(anchor));
        bondManager.creditBond(proposer, 1 ether);

        (bool isLowBond, address designated, uint256 provingFee) =
            anchor.getDesignatedProver(1, proposer, auth, proverCandidate);

        assertTrue(isLowBond);
        assertEq(designated, proverCandidate);
        assertEq(provingFee, 0);
    }

    // ---------------------------------------------------------------
    // validateProverAuth
    // ---------------------------------------------------------------

    function test_validateProverAuth_ReturnsProposerWhenSignatureInvalid() external view {
        Anchor.ProverAuth memory auth = Anchor.ProverAuth({
            proposalId: 1, proposer: proposer, provingFee: 1 ether, signature: new bytes(0)
        });

        (address signer, uint256 fee) = anchor.validateProverAuth(1, proposer, abi.encode(auth));
        assertEq(signer, proposer);
        assertEq(fee, 0);
    }

    // ---------------------------------------------------------------
    // withdraw
    // ---------------------------------------------------------------

    function test_withdraw_Ether_SendsToRecipient() external {
        vm.deal(address(anchor), 10 ether);
        address recipient = address(0xD1);
        uint256 beforeBal = recipient.balance;

        anchor.withdraw(address(0), recipient);

        assertEq(recipient.balance, beforeBal + 10 ether);
        assertEq(address(anchor).balance, 0);
    }

    function test_withdraw_Token_SendsBalance() external {
        token.mint(address(anchor), 1000 ether);
        address recipient = address(0xD2);

        anchor.withdraw(address(token), recipient);

        assertEq(token.balanceOf(recipient), 1000 ether);
        assertEq(token.balanceOf(address(anchor)), 0);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _buildBondInstructions(uint48 proposalId)
        internal
        view
        returns (LibBonds.BondInstruction[] memory instructions, bytes32 expectedHash)
    {
        instructions = new LibBonds.BondInstruction[](2);

        instructions[0] = LibBonds.BondInstruction({
            proposalId: proposalId,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: address(0xCA1)
        });

        instructions[1] = LibBonds.BondInstruction({
            proposalId: proposalId,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: proposer,
            payee: address(0xCA2)
        });

        expectedHash = LibBonds.aggregateBondInstruction(bytes32(0), instructions[0]);
        expectedHash = LibBonds.aggregateBondInstruction(expectedHash, instructions[1]);
    }

    function _buildProverAuth(
        uint48 proposalId,
        uint256 provingFee
    )
        internal
        view
        returns (bytes memory)
    {
        Anchor.ProverAuth memory auth = Anchor.ProverAuth({
            proposalId: proposalId, proposer: proposer, provingFee: provingFee, signature: ""
        });

        bytes32 messageHash = keccak256(abi.encode(proposalId, proposer, provingFee));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(proverKey, messageHash);
        auth.signature = abi.encodePacked(r, s, v);

        return abi.encode(auth);
    }

    function _prepareAnchorCall()
        internal
        view
        returns (Anchor.ProposalParams memory proposalParams, Anchor.BlockParams memory blockParams)
    {
        uint48 proposalId = 1;
        (LibBonds.BondInstruction[] memory instructions, bytes32 expectedHash) =
            _buildBondInstructions(proposalId);

        uint256 provingFee = 1 ether;
        bytes memory proverAuth = _buildProverAuth(proposalId, provingFee);

        proposalParams = Anchor.ProposalParams({
            proposalId: proposalId,
            proposer: proposer,
            proverAuth: proverAuth,
            bondInstructionsHash: expectedHash,
            bondInstructions: instructions
        });

        blockParams = Anchor.BlockParams({
            anchorBlockNumber: 1000,
            anchorBlockHash: bytes32(uint256(0x1234)),
            anchorStateRoot: bytes32(uint256(0x5678))
        });
    }
}
