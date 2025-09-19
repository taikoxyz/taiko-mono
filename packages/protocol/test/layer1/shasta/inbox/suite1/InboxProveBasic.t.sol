// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTest.sol";
import "./InboxMockContracts.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxProveBasic
/// @notice Tests for basic proof submission functionality
/// @dev This test suite covers proof submission and verification:
///      - Single and multiple proof submissions
///      - Transition record storage and retrieval
///      - Proof verification integration with mock verifier
///      - Sequential proof chaining with parent relationships
///      - Error handling for invalid proofs
/// @custom:security-contact security@taiko.xyz
contract InboxProveBasic is InboxTest {
    using InboxTestLib for *;

    function setUp() public virtual override {
        super.setUp();
    }

    /// @notice Test proving a single transition successfully
    /// @dev Validates the complete proof submission flow
    function test_prove_single_transition() public {
        // Arrange: Submit a proposal that can be proven
        IInbox.Proposal memory proposal = submitProposal(SINGLE_PROPOSAL, Alice);
        bytes32 parentTransitionHash = getGenesisTransitionHash();

        // Act: Submit proof with parent transition hash
        proveProposal(proposal, Bob, parentTransitionHash);

        // Assert: Verify transition record was stored with correct parent relationship
        assertTransitionRecordStored(SINGLE_PROPOSAL, parentTransitionHash);
    }

    /// @notice Test proving multiple transitions in one transaction
    /// @dev Validates batch proof submission capabilities
    function test_prove_multiple_transitions() public {
        // Arrange: Submit all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](FEW_PROPOSALS);
        for (uint48 i = 1; i <= FEW_PROPOSALS; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Act & Assert: Prove each proposal with chained parent hashes
        bytes32 parentTransitionHash = getGenesisTransitionHash();
        for (uint48 i = 1; i <= FEW_PROPOSALS; i++) {
            proveProposal(proposals[i - 1], Bob, parentTransitionHash);
            assertTransitionRecordStored(i, parentTransitionHash);
            // Update parent hash for next iteration
            IInbox.Transition memory transition =
                InboxTestLib.createTransition(proposals[i - 1], parentTransitionHash, address(0));
            parentTransitionHash = InboxTestLib.hashTransition(transition);
        }
    }

    /// @notice Test proving transitions for sequential proposals
    /// @dev Validates linked proof chain construction
    function test_prove_sequential_proposals() public {
        uint48 count = 4;
        bytes32 parentHash = getGenesisTransitionHash();

        // Submit all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](count);
        for (uint48 i = 0; i < count; i++) {
            proposals[i] = submitProposal(i + 1, Alice);
        }

        // Prove sequentially with linked parent relationships
        for (uint48 i = 0; i < count; i++) {
            uint48 proposalId = i + 1;

            // Prove with current parent hash
            proveProposal(proposals[i], Bob, parentHash);
            assertTransitionRecordStored(proposalId, parentHash);

            // Update parent hash for chain progression
            IInbox.Transition memory transition =
                InboxTestLib.createTransition(proposals[i], parentHash, address(0));
            parentHash = InboxTestLib.hashTransition(transition);
        }
    }

    /// @notice Test that proof submission works with mocked verification
    /// @dev Validates proof submission flow integration
    function test_prove_submission_flow() public {
        // Arrange: Create proposal and transition data
        IInbox.Proposal memory proposal = submitProposal(SINGLE_PROPOSAL, Alice);
        bytes32 parentTransitionHash = getGenesisTransitionHash();
        IInbox.Transition memory transition =
            InboxTestLib.createTransition(proposal, parentTransitionHash, address(0));

        bytes memory proof = bytes("test_proof_data");

        // Act: Submit proof with standard mocking
        setupProofMocks(true);
        vm.prank(Bob);
        inbox.prove(
            InboxTestAdapter.encodeProveInput(inboxType, _toArray(proposal), _toArray(transition)),
            proof
        );

        // Assert: Verify proof submission was successful
        assertTransitionRecordStored(SINGLE_PROPOSAL, parentTransitionHash);
    }

    /// @dev Helper to convert single item to array
    function _toArray(IInbox.Proposal memory _item)
        private
        pure
        returns (IInbox.Proposal[] memory arr)
    {
        arr = new IInbox.Proposal[](1);
        arr[0] = _item;
    }

    /// @dev Helper to convert single item to array
    function _toArray(IInbox.Transition memory _item)
        private
        pure
        returns (IInbox.Transition[] memory arr)
    {
        arr = new IInbox.Transition[](1);
        arr[0] = _item;
    }

    /// @notice Test transition record storage and retrieval
    /// @dev Validates persistent transition record storage with multiple proofs per proposal
    function test_prove_transition_record_storage() public {
        uint48 numProposals = FEW_PROPOSALS;
        uint256 proofsPerProposal = 2;

        // Submit all proposals first
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);
        for (uint48 i = 1; i <= numProposals; i++) {
            proposals[i - 1] = submitProposal(i, Alice);
        }

        // Prove each proposal multiple times with different parent hashes
        // For testing multiple proofs per proposal, we use genesis as parent for first proof,
        // and a custom parent for second proof
        for (uint48 i = 1; i <= numProposals; i++) {
            for (uint256 j = 0; j < proofsPerProposal; j++) {
                bytes32 parentTransitionHash =
                    j == 0 ? getGenesisTransitionHash() : keccak256(abi.encode("parent", i, j));
                proveProposal(proposals[i - 1], Bob, parentTransitionHash);
                assertTransitionRecordStored(i, parentTransitionHash);
            }
        }

        // Verify persistent storage of all records
        for (uint48 i = 1; i <= numProposals; i++) {
            for (uint256 j = 0; j < proofsPerProposal; j++) {
                bytes32 parentTransitionHash =
                    j == 0 ? getGenesisTransitionHash() : keccak256(abi.encode("parent", i, j));
                assertTransitionRecordStored(i, parentTransitionHash);
            }
        }
    }

    /// @notice Test proving with mocked proof verification
    /// @dev Validates that proof verification can be mocked for testing
    function test_prove_with_mock_verification() public {
        // Arrange: Create valid proposal and transition data
        IInbox.Proposal memory proposal = submitProposal(SINGLE_PROPOSAL, Alice);
        bytes32 parentTransitionHash = getGenesisTransitionHash();
        IInbox.Transition memory transition =
            InboxTestLib.createTransition(proposal, parentTransitionHash, address(0));

        // Configure: Set up mock to succeed
        setupProofMocks(true);

        // Act: Submit proof with mock verification
        vm.prank(Bob);
        inbox.prove(
            InboxTestAdapter.encodeProveInput(inboxType, _toArray(proposal), _toArray(transition)),
            bytes("test_proof")
        );

        // Assert: Verify transition record was stored successfully
        assertTransitionRecordStored(SINGLE_PROPOSAL, parentTransitionHash);
    }
}
