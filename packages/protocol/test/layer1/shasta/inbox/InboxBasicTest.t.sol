// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Inbox, InvalidState, DeadlineExceeded } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxBasicTest
/// @notice Basic tests for the Inbox contract without slot reuse functionality
contract InboxBasicTest is InboxTestBase {
    function setUp() public virtual override {
        super.setUp();
    }

    // Override setupMockAddresses to use actual mock contracts instead of makeAddr
    function setupMockAddresses() internal override {
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());
    }

    /// @notice Test submitting a single valid proposal
    function test_propose_single_valid() public {
        // Re-setup blob hashes right before test
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i < 10) {
                hashes[i] = keccak256(abi.encode("blob", uint256(i)));
            }
        }
        vm.blobhashes(hashes);

        // Setup initial core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        bytes32 initialCoreStateHash = keccak256(abi.encode(coreState));
        inbox.exposed_setCoreStateHash(initialCoreStateHash);

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Create proposal data
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposalData(coreState, blobRef, claimRecords);

        // Expected proposal
        bytes32[] memory expectedBlobHashes = new bytes32[](1);
        expectedBlobHashes[0] = keccak256(abi.encode("blob", uint256(1)));

        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: 1,
            proposer: Alice,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: expectedBlobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        // Expected updated core state
        IInbox.CoreState memory expectedCoreState = coreState;
        expectedCoreState.nextProposalId = 2;

        // Expect Proposed event
        vm.expectEmit(true, true, true, true);
        emit Proposed(expectedProposal, expectedCoreState);

        // Submit proposal
        vm.prank(Alice);
        inbox.propose(bytes(""), data);

        // Verify proposal hash is stored
        bytes32 storedProposalHash = inbox.getProposalHash(uint48(1));
        bytes32 expectedProposalHash = keccak256(abi.encode(expectedProposal));
        assertEq(storedProposalHash, expectedProposalHash);

        // Verify core state is updated
        bytes32 newCoreStateHash = inbox.getCoreStateHash();
        assertEq(newCoreStateHash, keccak256(abi.encode(expectedCoreState)));
    }

    /// @notice Test submitting multiple proposals sequentially
    function test_propose_multiple_sequential() public {
        setupBlobHashes();
        uint48 numProposals = 5;

        for (uint48 i = 0; i < numProposals; i++) {
            // Setup core state for this iteration
            IInbox.CoreState memory coreState = createCoreState(i + 1, 0);
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

            // Setup mocks
            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            // Create proposal data
            LibBlobs.BlobReference memory blobRef = createValidBlobReference(i + 1);
            IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
            bytes memory data = encodeProposalData(coreState, blobRef, claimRecords);

            // Submit proposal
            vm.prank(Alice);
            inbox.propose(bytes(""), data);

            // Verify proposal is stored
            bytes32 proposalHash = inbox.getProposalHash(uint48(i + 1));
            assertTrue(proposalHash != bytes32(0));
        }

        // Verify all proposals are accessible
        for (uint48 i = 0; i < numProposals; i++) {
            bytes32 proposalHash = inbox.getProposalHash(uint48(i + 1));
            assertTrue(proposalHash != bytes32(0));
        }
    }

    /// @notice Test proposal with invalid state reverts
    function test_propose_invalid_state_reverts() public {
        // Setup initial core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Create proposal data with wrong core state
        IInbox.CoreState memory wrongCoreState = createCoreState(2, 0); // Wrong nextProposalId
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposalData(wrongCoreState, blobRef, claimRecords);

        // Expect revert with InvalidState error
        vm.expectRevert(InvalidState.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proposal with deadline exceeded reverts
    function test_propose_deadline_exceeded_reverts() public {
        setupBlobHashes();

        // Move time forward to ensure block.timestamp > 1
        vm.warp(1000);

        // Setup core state
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Setup mocks
        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        // Create proposal data with expired deadline
        uint64 deadline = uint64(block.timestamp - 1); // Expired deadline
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data =
            encodeProposalDataWithDeadline(deadline, coreState, blobRef, claimRecords);

        // Expect revert with DeadlineExceeded error
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proving a claim
    function test_prove_single_claim() public {
        setupBlobHashes();
        // First create a proposal
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Alice);
        mockForcedInclusionDue(false);

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory proposeData = encodeProposalData(coreState, blobRef, claimRecords);

        vm.prank(Alice);
        inbox.propose(bytes(""), proposeData);

        // Now prove the proposal
        mockProofVerification(true);

        IInbox.Proposal memory proposal = createValidProposal(1);
        IInbox.Claim memory claim = createValidClaim(proposal, bytes32(0));

        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](0);
        IInbox.ClaimRecord memory claimRecord =
            IInbox.ClaimRecord({ claim: claim, span: 1, bondInstructions: bondInstructions });

        // Prove expects arrays of proposals and claims
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;

        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;

        bytes memory proveData = abi.encode(proposals, claims);

        // Expect Proved event
        vm.expectEmit(true, true, true, true);
        emit Proved(proposal, claimRecord);

        // Submit proof
        vm.prank(Bob);
        inbox.prove(proveData, bytes("proof"));

        // Verify claim is stored
        bytes32 claimHash = inbox.getClaimRecordHash(uint48(1), bytes32(0));
        assertTrue(claimHash != bytes32(0));
    }
}

// Mock contracts
contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }
}

contract StubSyncedBlockManager {
    function saveSyncedBlock(uint48, bytes32, bytes32) external { }
}

contract StubForcedInclusionStore {
    function isOldestForcedInclusionDue() external pure returns (bool) {
        return false;
    }

    function consumeOldestForcedInclusion(address)
        external
        pure
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        revert("Not implemented");
    }
}

contract StubProofVerifier {
    function verifyProof(bytes calldata, bytes calldata) external pure { }
}

contract StubProposerChecker {
    function checkProposer(address) external pure { }
}
