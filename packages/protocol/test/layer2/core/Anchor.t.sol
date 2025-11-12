// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { BondManager } from "src/layer2/core/BondManager.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

contract AnchorTest is Test {
    // Bond configuration
    uint256 private constant LIVENESS_BOND = 5 ether;
    uint256 private constant PROVABILITY_BOND = 7 ether;

    // Test setup constants
    uint64 private constant SHASTA_FORK_HEIGHT = 100;
    uint64 private constant L1_CHAIN_ID = 1;
    address private constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
    uint256 private constant INITIAL_PROPOSER_BOND = 100 ether;
    uint256 private constant INITIAL_PROVER_BOND = 50 ether;

    // EIP-712 constants (must match Anchor.sol)
    bytes32 private constant PROVER_AUTH_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant PROVER_AUTH_TYPEHASH =
        keccak256("ProverAuth(uint48 proposalId,address proposer,uint256 provingFee)");
    bytes32 private constant PROVER_AUTH_DOMAIN_NAME_HASH = keccak256("TaikoAnchorProverAuth");
    bytes32 private constant PROVER_AUTH_DOMAIN_VERSION_HASH = keccak256("1");

    // Contract instances
    Anchor internal anchor;
    BondManager internal bondManager;
    SignalService internal checkpointStore;
    TestERC20 internal token;

    // Test actors
    address internal proposer;
    address internal proverCandidate;
    uint256 internal proverKey;

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

        vm.roll(SHASTA_FORK_HEIGHT);
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

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.expectRevert(Anchor.InvalidSender.selector);
        anchor.anchorV4(proposalParams, blockParams);
    }

    function test_anchorV4_AllowsSubsequentBlocksWithSameProposal() external {
        (Anchor.ProposalParams memory proposalParams, Anchor.BlockParams memory blockParams) =
            _prepareAnchorCall();

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        vm.roll(SHASTA_FORK_HEIGHT + 1);

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

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        vm.roll(SHASTA_FORK_HEIGHT + 1);

        Anchor.ProposalParams memory backwardProposal = proposalParams;
        backwardProposal.proposalId = 0;

        vm.expectRevert(Anchor.ProposalIdMismatch.selector);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(backwardProposal, blockParams);
    }

    function test_anchorV4_AllowsTransitionToNewProposal() external {
        (Anchor.ProposalParams memory proposalParams1, Anchor.BlockParams memory blockParams1) =
            _prepareAnchorCall();

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams1, blockParams1);

        Anchor.ProposalState memory stateAfterFirstProposal = anchor.getProposalState();
        assertEq(stateAfterFirstProposal.proposalId, 1);
        assertEq(stateAfterFirstProposal.designatedProver, proverCandidate);
        bytes32 previousBondHash = stateAfterFirstProposal.bondInstructionsHash;

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams1, blockParams1);

        vm.roll(SHASTA_FORK_HEIGHT + 2);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams1, blockParams1);

        vm.roll(SHASTA_FORK_HEIGHT + 3);

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

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        uint256 proposerBalanceAfterFirst = bondManager.getBondBalance(proposer);
        uint256 proverBalanceAfterFirst = bondManager.getBondBalance(proverCandidate);
        Anchor.ProposalState memory stateAfterFirst = anchor.getProposalState();

        vm.roll(SHASTA_FORK_HEIGHT + 1);
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

        vm.roll(SHASTA_FORK_HEIGHT + 2);
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

    function test_anchorV4_IgnoresProverAuthWithInvalidSignature() external {
        uint48 proposalId = 1;
        (LibBonds.BondInstruction[] memory instructions, bytes32 expectedHash) =
            _buildBondInstructions(proposalId);

        uint256 provingFee = 5 ether;
        uint256 proposerBalanceBefore = bondManager.getBondBalance(proposer);
        uint256 proverBalanceBefore = bondManager.getBondBalance(proverCandidate);

        // Create ProverAuth with invalid (empty) signature
        Anchor.ProverAuth memory invalidAuth = Anchor.ProverAuth({
            proposalId: proposalId,
            proposer: proposer,
            provingFee: provingFee,
            signature: "" // Invalid empty signature
        });

        Anchor.ProposalParams memory proposalParams = Anchor.ProposalParams({
            proposalId: proposalId,
            proposer: proposer,
            proverAuth: abi.encode(invalidAuth),
            bondInstructionsHash: expectedHash,
            bondInstructions: instructions
        });

        Anchor.BlockParams memory blockParams = Anchor.BlockParams({
            anchorBlockNumber: 1000,
            anchorBlockHash: bytes32(uint256(0x1234)),
            anchorStateRoot: bytes32(uint256(0x5678))
        });

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        // Key security property: Invalid signature should not transfer proving fee
        // Prover candidate should not receive any funds
        uint256 proverBalanceAfter = bondManager.getBondBalance(proverCandidate);
        assertEq(
            proverBalanceAfter,
            proverBalanceBefore,
            "Prover candidate should not receive fee with invalid signature"
        );

        // Proposer should only pay liveness and provability bonds
        uint256 proposerBalanceAfter = bondManager.getBondBalance(proposer);
        assertEq(
            proposerBalanceAfter,
            proposerBalanceBefore - LIVENESS_BOND - PROVABILITY_BOND,
            "Proposer should only pay liveness/provability bonds, not proving fee"
        );

        // Proposer should be designated as prover (fallback behavior)
        Anchor.ProposalState memory state = anchor.getProposalState();
        assertEq(
            state.designatedProver, proposer, "Should fall back to proposer as designated prover"
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

    function test_validateProverAuth_AcceptsValidEIP712Signature() external view {
        uint48 proposalId = 42;
        uint256 provingFee = 3 ether;
        bytes memory proverAuth = _buildProverAuth(proposalId, provingFee);

        (address signer, uint256 fee) = anchor.validateProverAuth(proposalId, proposer, proverAuth);

        assertEq(signer, proverCandidate, "Should recover prover candidate address");
        assertEq(fee, provingFee, "Should return correct proving fee");
    }

    function test_validateProverAuth_RejectsSignatureFromWrongChain() external view {
        uint48 proposalId = 42;
        uint256 provingFee = 3 ether;

        // Create signature with wrong chain ID (simulating cross-chain replay attempt)
        // Foundry default chainId is 31337, so use 1 (Ethereum mainnet) as the wrong chainId
        uint256 wrongChainId = 1;
        bytes memory proverAuth = _buildProverAuthWithChainId(proposalId, provingFee, wrongChainId);

        (address signer, uint256 fee) = anchor.validateProverAuth(proposalId, proposer, proverAuth);

        // Signature should be invalid - recovered address won't match proverCandidate
        assertTrue(signer != proverCandidate, "Should reject signature from wrong chain");
        assertEq(fee, provingFee, "Fee should still be extracted from struct");
    }

    function test_validateProverAuth_RejectsSignatureForWrongProposal() external view {
        uint48 proposalId = 42;
        uint256 provingFee = 3 ether;
        bytes memory proverAuth = _buildProverAuth(proposalId, provingFee);

        // Try to use signature for different proposal ID
        (address signer, uint256 fee) =
            anchor.validateProverAuth(proposalId + 1, proposer, proverAuth);

        assertEq(signer, proposer, "Should reject signature for wrong proposal ID");
        assertEq(fee, 0, "Should return zero fee when context mismatch");
    }

    function test_validateProverAuth_RejectsSignatureForWrongProposer() external view {
        uint48 proposalId = 42;
        uint256 provingFee = 3 ether;
        bytes memory proverAuth = _buildProverAuth(proposalId, provingFee);

        // Try to use signature with different proposer
        address wrongProposer = address(0xBAD);
        (address signer, uint256 fee) =
            anchor.validateProverAuth(proposalId, wrongProposer, proverAuth);

        assertEq(signer, wrongProposer, "Should reject signature for wrong proposer");
        assertEq(fee, 0, "Should return zero fee when context mismatch");
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

    /// @dev Builds a properly signed ProverAuth using EIP-712 structured data signing.
    /// @param proposalId The proposal ID to authorize.
    /// @param provingFee The fee the prover will receive.
    /// @return Encoded ProverAuth with valid EIP-712 signature.
    function _buildProverAuth(
        uint48 proposalId,
        uint256 provingFee
    )
        internal
        view
        returns (bytes memory)
    {
        return _buildProverAuthWithChainId(proposalId, provingFee, block.chainid);
    }

    /// @dev Builds a ProverAuth with a custom chainId for testing cross-chain replay protection.
    /// @param proposalId The proposal ID to authorize.
    /// @param provingFee The fee the prover will receive.
    /// @param chainId The chain ID to use in the domain separator.
    /// @return Encoded ProverAuth with signature for the specified chain.
    function _buildProverAuthWithChainId(
        uint48 proposalId,
        uint256 provingFee,
        uint256 chainId
    )
        internal
        view
        returns (bytes memory)
    {
        // Build the ProverAuth struct (without signature initially)
        Anchor.ProverAuth memory auth = Anchor.ProverAuth({
            proposalId: proposalId, proposer: proposer, provingFee: provingFee, signature: ""
        });

        // Compute EIP-712 struct hash
        bytes32 structHash =
            keccak256(abi.encode(PROVER_AUTH_TYPEHASH, proposalId, proposer, provingFee));

        // Compute EIP-712 domain separator
        bytes32 domainSeparator = keccak256(
            abi.encode(
                PROVER_AUTH_DOMAIN_TYPEHASH,
                PROVER_AUTH_DOMAIN_NAME_HASH,
                PROVER_AUTH_DOMAIN_VERSION_HASH,
                chainId,
                address(anchor)
            )
        );

        // Compute final EIP-712 digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Sign the digest with prover's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(proverKey, digest);
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
