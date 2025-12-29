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

    bytes32 private constant PROVER_AUTH_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant PROVER_AUTH_TYPEHASH =
        keccak256("ProverAuth(uint48 proposalId,address proposer,uint256 provingFee)");
    bytes32 private constant PROVER_AUTH_DOMAIN_NAME_HASH = keccak256("TaikoAnchorProverAuth");
    bytes32 private constant PROVER_AUTH_DOMAIN_VERSION_HASH = keccak256("1");

    Anchor internal anchor;
    SignalService internal signalService;

    address internal proposer;
    address internal proverCandidate;
    uint256 internal proverKey;

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

        SignalService anchorSignalServiceImpl = new SignalService(address(anchor), address(0x1234));
        signalService.upgradeTo(address(anchorSignalServiceImpl));

        proposer = address(0xA11CE);
        proverKey = 0xBEEF;
        proverCandidate = vm.addr(proverKey);
    }

    function test_anchorV4_processesFirstBlock() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, 1 ether);
        ICheckpointStore.Checkpoint memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        Anchor.BlockState memory blockState = anchor.getBlockState();

        assertEq(proposalState.designatedProver, proverCandidate);
        assertEq(proposalState.proposalId, proposalParams.proposalId);
        assertEq(blockState.anchorBlockNumber, blockParams.blockNumber);
        assertTrue(blockState.ancestorsHash != bytes32(0));

        ICheckpointStore.Checkpoint memory saved =
            signalService.getCheckpoint(blockParams.blockNumber);
        assertEq(saved.blockNumber, blockParams.blockNumber);
        assertEq(saved.blockHash, blockParams.blockHash);
        assertEq(saved.stateRoot, blockParams.stateRoot);
    }

    function test_anchorV4_allowsMultipleBlocksWithoutExtraFees() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, 1 ether);
        ICheckpointStore.Checkpoint memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        assertEq(proposalState.proposalId, proposalParams.proposalId);
    }

    function test_anchorV4_rejectsBackwardProposalId() external {
        Anchor.ProposalParams memory proposalParams = _proposalParams(1, 1 ether);
        ICheckpointStore.Checkpoint memory blockParams = _blockParams(1000, 0x1234, 0x5678);

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
        ICheckpointStore.Checkpoint memory blockParams1 = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(firstProposal, blockParams1);

        Anchor.ProposalParams memory secondProposal = _proposalParams(2, 2 ether);
        ICheckpointStore.Checkpoint memory blockParams2 = _blockParams(1010, 0xABCD, 0xEF01);

        vm.roll(SHASTA_FORK_HEIGHT + 1);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(secondProposal, blockParams2);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        Anchor.BlockState memory blockState = anchor.getBlockState();

        assertEq(proposalState.proposalId, 2);
        assertEq(proposalState.designatedProver, proverCandidate);
        assertEq(blockState.anchorBlockNumber, blockParams2.blockNumber);
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
        ICheckpointStore.Checkpoint memory blockParams = _blockParams(1000, 0x1234, 0x5678);

        vm.roll(SHASTA_FORK_HEIGHT);
        vm.prank(GOLDEN_TOUCH);
        anchor.anchorV4(proposalParams, blockParams);

        Anchor.ProposalState memory proposalState = anchor.getProposalState();
        assertEq(proposalState.designatedProver, proposer);
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

    function test_validateProverAuth_FallsBackWhenTooShort() external view {
        // Too-short payload should cause decode to revert and fall back to proposer.
        bytes memory tooShort = new bytes(64);

        (address signer, uint256 fee) = anchor.validateProverAuth(1, proposer, tooShort);

        assertEq(signer, proposer);
        assertEq(fee, 0);
    }

    function test_validateProverAuth_ReturnsFallbackWhenDecodingFails() external view {
        // Non-ProverAuth encoding should also fall back.
        bytes memory malformed = abi.encode(uint256(123));

        (address signer, uint256 fee) = anchor.validateProverAuth(1, proposer, malformed);

        assertEq(signer, proposer);
        assertEq(fee, 0);
    }

    function test_validateProverAuth_RejectsOversizedPayload() external view {
        // Oversized payload should be short-circuited before ABI encoding to avoid gas blowups.
        bytes memory oversized = new bytes(4096 + 1);

        (address signer, uint256 fee) = anchor.validateProverAuth(1, proposer, oversized);

        assertEq(signer, proposer);
        assertEq(fee, 0);
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
        returns (ICheckpointStore.Checkpoint memory)
    {
        return ICheckpointStore.Checkpoint({
            blockNumber: _blockNumber,
            blockHash: bytes32(_blockHash),
            stateRoot: bytes32(_stateRoot)
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
