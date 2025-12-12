// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { BondManager } from "src/layer2/core/BondManager.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

contract AnchorTest is Test {
    uint256 private constant LIVENESS_BOND = 5 ether;
    uint64 private constant SHASTA_FORK_HEIGHT = 100;
    uint64 private constant L1_CHAIN_ID = 1;
    address private constant L1_INBOX = address(0xBEEF);
    address private constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
    uint256 private constant INITIAL_PROPOSER_BOND = 100 ether;
    uint256 private constant INITIAL_PROVER_BOND = 50 ether;

    bytes32 private constant PROVER_AUTH_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant PROVER_AUTH_TYPEHASH =
        keccak256("ProverAuth(uint48 proposalId,address proposer,uint256 provingFee)");
    bytes32 private constant PROVER_AUTH_DOMAIN_NAME_HASH = keccak256("TaikoAnchorProverAuth");
    bytes32 private constant PROVER_AUTH_DOMAIN_VERSION_HASH = keccak256("1");

    Anchor internal anchor;
    BondManager internal bondManager;
    SignalService internal signalService;
    TestERC20 internal token;

    address internal proposer;
    address internal proverCandidate;
    uint256 internal proverKey;

    function setUp() external {
        token = new TestERC20("Mock", "MOCK");

        SignalService signalServiceImpl = new SignalService(address(this), address(0x1234));
        signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(signalServiceImpl), abi.encodeCall(SignalService.init, (address(this)))
                )
            )
        );

        BondManager bondManagerImpl = new BondManager(
            address(token), 0, 0, address(this), signalService, L1_INBOX, L1_CHAIN_ID, LIVENESS_BOND
        );
        bondManager = BondManager(
            address(
                new ERC1967Proxy(
                    address(bondManagerImpl), abi.encodeCall(BondManager.init, (address(this)))
                )
            )
        );

        Anchor anchorImpl = new Anchor(signalService, bondManager, LIVENESS_BOND, L1_CHAIN_ID);
        anchor = Anchor(
            address(
                new ERC1967Proxy(address(anchorImpl), abi.encodeCall(Anchor.init, (address(this))))
            )
        );

        BondManager anchorBondManagerImpl = new BondManager(
            address(token),
            0,
            0,
            address(anchor),
            signalService,
            L1_INBOX,
            L1_CHAIN_ID,
            LIVENESS_BOND
        );
        bondManager.upgradeTo(address(anchorBondManagerImpl));

        SignalService anchorSignalServiceImpl = new SignalService(address(anchor), address(0x1234));
        signalService.upgradeTo(address(anchorSignalServiceImpl));

        proposer = address(0xA11CE);
        proverKey = 0xBEEF;
        proverCandidate = vm.addr(proverKey);

        token.mint(proposer, INITIAL_PROPOSER_BOND);
        vm.startPrank(proposer);
        token.approve(address(bondManager), type(uint256).max);
        bondManager.deposit(address(0), INITIAL_PROPOSER_BOND);
        vm.stopPrank();

        token.mint(proverCandidate, INITIAL_PROVER_BOND);
        vm.startPrank(proverCandidate);
        token.approve(address(bondManager), type(uint256).max);
        bondManager.deposit(address(0), INITIAL_PROVER_BOND);
        vm.stopPrank();
    }

    function test_anchorV4_processesFirstBlock() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, 1 ether);
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        Anchor.BlockState memory blockState = anchor.getBlockState();

        assertEq(proposalState.designatedProver, proverCandidate);
        assertFalse(proposalState.isLowBondProposal);
        assertEq(proposalState.proposalId, proposalParams.proposalId);
        assertEq(blockState.anchorBlockNumber, blockParams.anchorBlockNumber);
        assertTrue(blockState.ancestorsHash != bytes32(0));

        assertEq(bondManager.getBondBalance(proposer), INITIAL_PROPOSER_BOND - 1 ether);
        assertEq(bondManager.getBondBalance(proverCandidate), INITIAL_PROVER_BOND + 1 ether);

        ICheckpointStore.Checkpoint memory saved =
            signalService.getCheckpoint(blockParams.anchorBlockNumber);
        assertEq(saved.blockNumber, blockParams.anchorBlockNumber);
        assertEq(saved.blockHash, blockParams.anchorBlockHash);
        assertEq(saved.stateRoot, blockParams.anchorStateRoot);
    }

    function test_anchorV4_allowsMultipleBlocksWithoutExtraFees() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, 1 ether);
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        uint256 proposerBalanceAfterFirst = bondManager.getBondBalance(proposer);
        uint256 proverBalanceAfterFirst = bondManager.getBondBalance(proverCandidate);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        assertEq(proposalState.proposalId, proposalParams.proposalId);
        assertEq(bondManager.getBondBalance(proposer), proposerBalanceAfterFirst);
        assertEq(bondManager.getBondBalance(proverCandidate), proverBalanceAfterFirst);
    }

    function test_anchorV4_rejectsBackwardProposalId() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, 1 ether);
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalParams memory backwardProposal = _proposalParams(0, 1 ether);
        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.expectRevert(Anchor.ProposalIdMismatch.selector);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(backwardProposal, blockParams);
    }

    function test_anchorV4_switchesProposal() external {
        Anchor.ProposalParams memory firstProposal = _proposalParams(1, 1 ether);
        Anchor.BlockParams memory blockParams1 = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(firstProposal, blockParams1);

        Anchor.ProposalParams memory secondProposal = _proposalParams(2, 2 ether);
        Anchor.BlockParams memory blockParams2 = _blockParams(1010, 0xABCD, 0xEF01);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(secondProposal, blockParams2);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        Anchor.BlockState memory blockState = anchor.getBlockState();

        assertEq(proposalState.proposalId, 2);
        assertEq(proposalState.designatedProver, proverCandidate);
        assertEq(blockState.anchorBlockNumber, blockParams2.anchorBlockNumber);
        assertEq(bondManager.getBondBalance(proposer), INITIAL_PROPOSER_BOND - 3 ether);
        assertEq(bondManager.getBondBalance(proverCandidate), INITIAL_PROVER_BOND + 3 ether);
    }

    function test_anchorV4_fallsBackToProposerWhenAuthInvalid() external {
        Anchor.ProverAuth memory invalidAuth = Anchor.ProverAuth({
            proposalId: 1,
            proposer: proposer,
            provingFee: 5 ether,
            signature: "" // invalid
        });
        Anchor.ProposalParams memory proposalParams = Anchor.ProposalParams({
            proposalId: 1, proposer: proposer, proverAuth: abi.encode(invalidAuth)
        });
        Anchor.BlockParams memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        assertEq(proposalState.designatedProver, proposer);
        assertEq(bondManager.getBondBalance(proposer), INITIAL_PROPOSER_BOND);
        assertEq(bondManager.getBondBalance(proverCandidate), INITIAL_PROVER_BOND);
    }

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

        assertEq(signer, proverCandidate);
        assertEq(fee, provingFee);
    }

    function test_DOMAIN_SEPARATOR_returnsCorrectValue() external view {
        bytes32 domainSeparator = anchor.DOMAIN_SEPARATOR();
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                PROVER_AUTH_DOMAIN_TYPEHASH,
                PROVER_AUTH_DOMAIN_NAME_HASH,
                PROVER_AUTH_DOMAIN_VERSION_HASH,
                block.chainid,
                address(anchor)
            )
        );

        assertEq(domainSeparator, expectedDomainSeparator);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _proposalParams(
        uint48 _proposalId,
        uint256 _provingFee
    )
        internal
        view
        returns (Anchor.ProposalParams memory)
    {
        return Anchor.ProposalParams({
            proposalId: _proposalId,
            proposer: proposer,
            proverAuth: _buildProverAuth(_proposalId, _provingFee)
        });
    }

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
            anchorStateRoot: bytes32(_stateRoot)
        });
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

        bytes32 domainSeparator = keccak256(
            abi.encode(
                PROVER_AUTH_DOMAIN_TYPEHASH,
                PROVER_AUTH_DOMAIN_NAME_HASH,
                PROVER_AUTH_DOMAIN_VERSION_HASH,
                block.chainid,
                address(anchor)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(PROVER_AUTH_TYPEHASH, auth.proposalId, auth.proposer, auth.provingFee)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(proverKey, digest);
        auth.signature = abi.encodePacked(r, s, v);

        return abi.encode(auth);
    }
}
