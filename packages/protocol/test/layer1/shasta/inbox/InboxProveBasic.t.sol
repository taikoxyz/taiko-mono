// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/layer1/shasta/libs/LibDecoder.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxProveBasic
/// @notice Tests for basic proof submission functionality
/// @dev Tests cover single and multiple proof submissions, claim record storage, and events
contract InboxProveBasic is CommonTest {
    using LibDecoder for bytes;

    TestInboxProve internal inbox;

    // Mock dependencies
    address internal bondToken;
    address internal syncedBlockManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // Events
    event Proved(IInbox.Proposal proposal, IInbox.ClaimRecord claimRecord);
    event BondInstructed(LibBonds.BondInstruction[] instructions);

    function setUp() public virtual override {
        super.setUp();

        // Create mock addresses
        bondToken = makeAddr("bondToken");
        syncedBlockManager = makeAddr("syncedBlockManager");
        forcedInclusionStore = makeAddr("forcedInclusionStore");
        proofVerifier = makeAddr("proofVerifier");
        proposerChecker = makeAddr("proposerChecker");

        // Deploy and initialize inbox
        TestInboxProve impl = new TestInboxProve();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), address(this), GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        inbox = TestInboxProve(address(proxy));

        // Set config on the inbox
        IInbox.Config memory config = IInbox.Config({
            bondToken: bondToken,
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            ringBufferSize: 100,
            basefeeSharingPctg: 10,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });
        inbox.setTestConfig(config);

        // Fund test accounts
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
        vm.deal(Carol, 100 ether);

        // Setup blob hashes
        setupBlobHashes();
    }

    function setupBlobHashes() internal {
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i < 10) {
                hashes[i] = keccak256(abi.encode("blob", i));
            }
        }
        vm.blobhashes(hashes);
    }

    /// @notice Test proving a single claim successfully
    function test_prove_single_claim() public {
        // First, create and store a proposal
        uint48 proposalId = 1;
        IInbox.Proposal memory proposal = createValidProposal(proposalId);
        bytes32 proposalHash = keccak256(abi.encode(proposal));
        inbox.exposed_setProposalHash(proposalId, proposalHash);

        // Create a claim for the proposal
        bytes32 parentClaimHash = bytes32(uint256(999));
        IInbox.Claim memory claim = createValidClaim(proposal, parentClaimHash);

        // Create arrays for prove data
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;

        // Setup proof verification mock
        mockProofVerification(true);

        // Expected claim record (without bond fields since we're not testing bonds)
        IInbox.ClaimRecord memory expectedClaimRecord = IInbox.ClaimRecord({
            claim: claim,
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        // Expect Proved event
        vm.expectEmit(true, true, true, true);
        emit Proved(proposal, expectedClaimRecord);

        // Submit proof
        bytes memory data = abi.encode(proposals, claims);
        bytes memory proof = bytes("valid_proof");

        vm.prank(Alice);
        inbox.prove(data, proof);

        // Verify claim record is stored
        bytes32 storedClaimHash = inbox.getClaimRecordHash(proposalId, parentClaimHash);
        assertEq(storedClaimHash, keccak256(abi.encode(expectedClaimRecord)));
    }

    /// @notice Test proving multiple claims in one transaction
    function test_prove_multiple_claims() public {
        uint256 numClaims = 3;
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numClaims);
        IInbox.Claim[] memory claims = new IInbox.Claim[](numClaims);

        // Create and store proposals
        for (uint48 i = 0; i < numClaims; i++) {
            proposals[i] = createValidProposal(i + 1);
            bytes32 proposalHash = keccak256(abi.encode(proposals[i]));
            inbox.exposed_setProposalHash(i + 1, proposalHash);

            // Create claims with different parent hashes
            claims[i] = createValidClaim(proposals[i], bytes32(uint256(i * 100)));
        }

        // Setup proof verification mock
        mockProofVerification(true);

        // Submit proof for all claims
        bytes memory data = abi.encode(proposals, claims);
        bytes memory proof = bytes("valid_proof");

        vm.prank(Alice);
        inbox.prove(data, proof);

        // Verify all claim records are stored
        for (uint48 i = 0; i < numClaims; i++) {
            bytes32 storedClaimHash = inbox.getClaimRecordHash(i + 1, bytes32(uint256(i * 100)));
            assertTrue(storedClaimHash != bytes32(0));
        }
    }

    /// @notice Test proving claims for sequential proposals
    function test_prove_sequential_proposals() public {
        // Create a chain of proposals
        uint48 startId = 5;
        uint48 count = 4;

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](count);
        IInbox.Claim[] memory claims = new IInbox.Claim[](count);
        bytes32 parentClaimHash = bytes32(uint256(1000));

        for (uint48 i = 0; i < count; i++) {
            // Create and store proposal
            proposals[i] = createValidProposal(startId + i);
            bytes32 proposalHash = keccak256(abi.encode(proposals[i]));
            inbox.exposed_setProposalHash(startId + i, proposalHash);

            // Create claim with chained parent hashes
            claims[i] = createValidClaim(proposals[i], parentClaimHash);

            // Next claim's parent is this claim's hash
            parentClaimHash = keccak256(abi.encode(claims[i]));
        }

        // Setup proof verification mock
        mockProofVerification(true);

        // Submit proof
        bytes memory data = abi.encode(proposals, claims);
        bytes memory proof = bytes("valid_proof");

        vm.prank(Alice);
        inbox.prove(data, proof);

        // Verify the chain is stored correctly
        parentClaimHash = bytes32(uint256(1000));
        for (uint48 i = 0; i < count; i++) {
            bytes32 storedClaimHash = inbox.getClaimRecordHash(startId + i, parentClaimHash);
            assertTrue(storedClaimHash != bytes32(0));
            parentClaimHash = keccak256(abi.encode(claims[i]));
        }
    }

    /// @notice Test that proof verification is called with correct parameters
    function test_prove_verification_called() public {
        // Create and store a proposal
        IInbox.Proposal memory proposal = createValidProposal(1);
        bytes32 proposalHash = keccak256(abi.encode(proposal));
        inbox.exposed_setProposalHash(1, proposalHash);

        // Create a claim
        IInbox.Claim memory claim = createValidClaim(proposal, bytes32(0));

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;

        // Calculate expected claims hash
        bytes32 expectedClaimsHash = keccak256(abi.encode(claims));
        bytes memory proof = bytes("test_proof_data");

        // Expect verifyProof to be called with correct parameters
        vm.expectCall(
            proofVerifier,
            abi.encodeWithSelector(IProofVerifier.verifyProof.selector, expectedClaimsHash, proof)
        );

        // Mock successful verification
        mockProofVerification(true);

        // Submit proof
        bytes memory data = abi.encode(proposals, claims);

        vm.prank(Alice);
        inbox.prove(data, proof);
    }

    /// @notice Test claim record storage and retrieval
    function test_prove_claim_record_storage() public {
        // Create and store multiple proposals
        uint256 numProposals = 3;

        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.Proposal memory proposal = createValidProposal(i);
            bytes32 proposalHash = keccak256(abi.encode(proposal));
            inbox.exposed_setProposalHash(i, proposalHash);

            // Create multiple claims per proposal with different parent hashes
            for (uint256 j = 0; j < 2; j++) {
                bytes32 parentClaimHash = bytes32(uint256(i * 1000 + j));
                IInbox.Claim memory claim = createValidClaim(proposal, parentClaimHash);

                IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
                proposals[0] = proposal;
                IInbox.Claim[] memory claims = new IInbox.Claim[](1);
                claims[0] = claim;

                // Setup proof verification mock
                mockProofVerification(true);

                // Submit proof
                bytes memory data = abi.encode(proposals, claims);
                bytes memory proof = bytes("valid_proof");

                vm.prank(Alice);
                inbox.prove(data, proof);

                // Verify storage
                bytes32 storedHash = inbox.getClaimRecordHash(i, parentClaimHash);
                assertTrue(storedHash != bytes32(0));
            }
        }

        // Verify all records are still accessible
        for (uint48 i = 1; i <= numProposals; i++) {
            for (uint256 j = 0; j < 2; j++) {
                bytes32 parentClaimHash = bytes32(uint256(i * 1000 + j));
                bytes32 storedHash = inbox.getClaimRecordHash(i, parentClaimHash);
                assertTrue(storedHash != bytes32(0));
            }
        }
    }

    /// @notice Test proving with invalid proof reverts
    function test_prove_invalid_proof_reverts() public {
        // Create and store a proposal
        IInbox.Proposal memory proposal = createValidProposal(1);
        bytes32 proposalHash = keccak256(abi.encode(proposal));
        inbox.exposed_setProposalHash(1, proposalHash);

        // Create a claim
        IInbox.Claim memory claim = createValidClaim(proposal, bytes32(0));

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;

        // Mock proof verification to fail
        mockProofVerification(false);

        // Submit proof - should revert
        bytes memory data = abi.encode(proposals, claims);
        bytes memory proof = bytes("invalid_proof");

        vm.expectRevert("Invalid proof");
        vm.prank(Alice);
        inbox.prove(data, proof);
    }

    // Helper functions

    function createValidProposal(uint48 _id) internal view returns (IInbox.Proposal memory) {
        bytes32[] memory blobHashes = new bytes32[](0); // Empty to avoid blob validation

        return IInbox.Proposal({
            id: _id,
            proposer: Alice,
            originTimestamp: 1,
            originBlockNumber: 1,
            isForcedInclusion: false,
            basefeeSharingPctg: 10,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes, offset: 0, timestamp: 1 })
        });
    }

    function createValidClaim(
        IInbox.Proposal memory _proposal,
        bytes32 _parentClaimHash
    )
        internal
        pure
        returns (IInbox.Claim memory)
    {
        return IInbox.Claim({
            proposalHash: keccak256(abi.encode(_proposal)),
            parentClaimHash: _parentClaimHash,
            endBlockNumber: _proposal.id * 100,
            endBlockHash: keccak256(abi.encode(_proposal.id, "endBlockHash")),
            endStateRoot: keccak256(abi.encode(_proposal.id, "stateRoot")),
            designatedProver: _proposal.proposer,
            actualProver: _proposal.proposer
        });
    }

    function mockProofVerification(bool _valid) internal {
        if (_valid) {
            vm.mockCall(
                proofVerifier,
                abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
                abi.encode()
            );
        } else {
            vm.mockCallRevert(
                proofVerifier,
                abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
                bytes("Invalid proof")
            );
        }
    }
}

// Test contract that exposes internal functions
contract TestInboxProve is Inbox {
    IInbox.Config private testConfig;

    function setTestConfig(IInbox.Config memory _config) external {
        testConfig = _config;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return testConfig;
    }

    function exposed_setProposalHash(uint48 _proposalId, bytes32 _hash) external {
        uint256 slot = _proposalId % testConfig.ringBufferSize;
        proposalRingBuffer[slot].proposalHash = _hash;
    }

    function exposed_setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        external
    {
        uint256 slot = _proposalId % testConfig.ringBufferSize;
        proposalRingBuffer[slot].claimHashLookup[_parentClaimHash].claimRecordHash =
            _claimRecordHash;
    }
}
