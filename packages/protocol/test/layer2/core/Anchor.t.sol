// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { BondManager } from "src/layer2/core/BondManager.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AnchorTest is Test {
    uint256 private constant LIVENESS_BOND = 5 ether;
    uint256 private constant PROVABILITY_BOND = 7 ether;
    uint64 private constant SHASTA_FORK_HEIGHT = 100;
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
        uint256 nonce = vm.getNonce(address(this));
        address predictedAnchor = vm.computeCreateAddress(address(this), nonce + 4);

        token = new TestERC20("Mock", "MOCK");

        bondManager = new BondManager(predictedAnchor, address(token), 0, 0);

        checkpointStore = new SignalService(predictedAnchor, address(0x1234));

        Anchor impl = new Anchor(
            checkpointStore,
            bondManager,
            LIVENESS_BOND,
            PROVABILITY_BOND,
            SHASTA_FORK_HEIGHT,
            L1_CHAIN_ID
        );
        anchor = Anchor(
            address(
                new ERC1967Proxy(
                    address(impl),
                    abi.encodeCall(Anchor.init, (address(this)))
                )
            )
        );

        assertEq(address(anchor), predictedAnchor, "Anchor proxy address mismatch");

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

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        Anchor.BlockState memory blockState = anchor.getBlockState();

        assertEq(proposalState.designatedProver, proverCandidate);
        assertFalse(proposalState.isLowBondProposal);
        assertEq(proposalState.bondInstructionsHash, proposalParams.bondInstructionsHash);

        assertEq(blockState.anchorBlockNumber, blockParams.anchorBlockNumber);
        assertTrue(blockState.ancestorsHash != bytes32(0));

        assertEq(
            bondManager.getBondBalance(proposer),
            INITIAL_PROPOSER_BOND - 1 ether - LIVENESS_BOND - PROVABILITY_BOND
        );
        assertEq(
            bondManager.getBondBalance(proverCandidate),
            INITIAL_PROVER_BOND + 1 ether
        );
        assertEq(bondManager.getBondBalance(address(0xCA1)), LIVENESS_BOND);
        assertEq(bondManager.getBondBalance(address(0xCA2)), PROVABILITY_BOND);

        ICheckpointStore.Checkpoint memory saved = checkpointStore.getCheckpoint(
            blockParams.anchorBlockNumber
        );
        assertEq(saved.blockNumber, blockParams.anchorBlockNumber);
        assertEq(saved.blockHash, blockParams.anchorBlockHash);
        assertEq(saved.stateRoot, blockParams.anchorStateRoot);
    }

    function test_anchorV4_RevertWhen_InvalidSender() external {
        (Anchor.ProposalParams memory proposalParams, Anchor.BlockParams memory blockParams) =
            _prepareAnchorCall();

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.expectRevert(Anchor.InvalidSender.selector);
        anchor.anchorV4(proposalParams, blockParams);
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

        (bool isLowBond, address designated, uint256 provingFee) = anchor.getDesignatedProver(
            1,
            proposer,
            auth,
            proverCandidate
        );

        assertTrue(isLowBond);
        assertEq(designated, proverCandidate);
        assertEq(provingFee, 0);
    }

    // ---------------------------------------------------------------
    // validateProverAuth
    // ---------------------------------------------------------------

    function test_validateProverAuth_ReturnsProposerWhenSignatureInvalid() external view {
        Anchor.ProverAuth memory auth = Anchor.ProverAuth({
            proposalId: 1,
            proposer: proposer,
            provingFee: 1 ether,
            signature: new bytes(0)
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
        token.mint(address(anchor), 1_000 ether);
        address recipient = address(0xD2);

        anchor.withdraw(address(token), recipient);

        assertEq(token.balanceOf(recipient), 1_000 ether);
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

    function _buildProverAuth(uint48 proposalId, uint256 provingFee)
        internal
        view
        returns (bytes memory)
    {
        Anchor.ProverAuth memory auth = Anchor.ProverAuth({
            proposalId: proposalId,
            proposer: proposer,
            provingFee: provingFee,
            signature: ""
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
            blockIndex: 0,
            anchorBlockNumber: 1_000,
            anchorBlockHash: bytes32(uint256(0x1234)),
            anchorStateRoot: bytes32(uint256(0x5678))
        });
    }
}
