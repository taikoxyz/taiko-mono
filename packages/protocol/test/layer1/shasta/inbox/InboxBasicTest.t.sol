// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";
import "test/shared/CommonTest.sol";
import "contracts/layer1/shasta/impl/Inbox.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/layer1/shasta/libs/LibDecoder.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxBasicTest
/// @notice Basic tests for the Inbox contract without slot reuse functionality
contract InboxBasicTest is CommonTest {
    using LibDecoder for bytes;

    // Test contract that exposes internal functions
    TestInbox internal inbox;

    // Mock dependencies
    address internal bondToken;
    address internal syncedBlockManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // Default configuration
    IInbox.Config internal defaultConfig;

    // Constants
    uint256 internal constant DEFAULT_RING_BUFFER_SIZE = 100;
    uint256 internal constant DEFAULT_MAX_FINALIZATION_COUNT = 10;
    uint48 internal constant DEFAULT_PROVING_WINDOW = 1 hours;
    uint48 internal constant DEFAULT_EXTENDED_PROVING_WINDOW = 2 hours;
    uint8 internal constant DEFAULT_BASEFEE_SHARING_PCTG = 10;
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // Events
    event CoreStateSet(IInbox.CoreState coreState);
    event Proposed(IInbox.Proposal proposal, IInbox.CoreState coreState);
    event Proved(IInbox.Proposal proposal, IInbox.ClaimRecord claimRecord);
    event BondInstructed(LibBonds.BondInstruction[] instructions);

    function setUp() public virtual override {
        super.setUp();

        // Create mock addresses
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());

        // Setup default configuration
        defaultConfig = IInbox.Config({
            bondToken: bondToken,
            provingWindow: DEFAULT_PROVING_WINDOW,
            extendedProvingWindow: DEFAULT_EXTENDED_PROVING_WINDOW,
            maxFinalizationCount: DEFAULT_MAX_FINALIZATION_COUNT,
            ringBufferSize: DEFAULT_RING_BUFFER_SIZE,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });

        // Deploy and initialize inbox
        TestInbox impl = new TestInbox();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), 
            address(this), 
            GENESIS_BLOCK_HASH
        );

        // Create proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        inbox = TestInbox(address(proxy));
        inbox.setConfig(defaultConfig);

        // Fund test accounts
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
        vm.deal(Carol, 100 ether);

        // Setup default blob hashes
        setupDefaultBlobHashes();
    }

    /// @notice Test submitting a single valid proposal
    function test_propose_single_valid() public {
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
        bytes memory data = encodeProposalDataWithDeadline(deadline, coreState, blobRef, claimRecords);

        // Expect revert with DeadlineExceeded error
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(Alice);
        inbox.propose(bytes(""), data);
    }

    /// @notice Test proving a claim
    function test_prove_single_claim() public {
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
        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            claim: claim,
            span: 1,
            bondInstructions: bondInstructions
        });

        bytes memory proveData = abi.encode(proposal, claimRecord);

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

    // Helper functions

    function mockProposerAllowed(address _proposer) internal {
        vm.mockCall(
            proposerChecker,
            abi.encodeWithSelector(IProposerChecker.checkProposer.selector, _proposer),
            abi.encode()
        );
    }

    function mockForcedInclusionDue(bool _isDue) internal {
        vm.mockCall(
            forcedInclusionStore,
            abi.encodeWithSelector(IForcedInclusionStore.isOldestForcedInclusionDue.selector),
            abi.encode(_isDue)
        );
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
                abi.encode("Invalid proof")
            );
        }
    }

    function setupDefaultBlobHashes() internal {
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            // Set non-zero hashes for all indices to avoid BlobNotFound errors
            hashes[i] = keccak256(abi.encode("blob", i));
        }
        vm.blobhashes(hashes);
    }

    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId
    ) internal pure returns (IInbox.CoreState memory) {
        return IInbox.CoreState({
            nextProposalId: _nextProposalId,
            lastFinalizedProposalId: _lastFinalizedProposalId,
            lastFinalizedClaimHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });
    }

    function createValidBlobReference(uint256 _seed) internal pure returns (LibBlobs.BlobReference memory) {
        return LibBlobs.BlobReference({
            blobStartIndex: uint48(_seed % 10),
            numBlobs: 1,
            offset: 0
        });
    }

    function createValidProposal(uint48 _id) internal view returns (IInbox.Proposal memory) {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", uint256(_id)));

        return IInbox.Proposal({
            id: _id,
            proposer: Alice,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });
    }

    function createValidClaim(
        IInbox.Proposal memory _proposal,
        bytes32 _parentClaimHash
    ) internal pure returns (IInbox.Claim memory) {
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

    function encodeProposalData(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    ) internal pure returns (bytes memory) {
        return abi.encode(uint64(0), _coreState, _blobRef, _claimRecords);
    }

    function encodeProposalDataWithDeadline(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    ) internal pure returns (bytes memory) {
        return abi.encode(_deadline, _coreState, _blobRef, _claimRecords);
    }
}

// Test contract that exposes internal functions
contract TestInbox is Inbox {
    Config private testConfig;

    function exposed_setCoreStateHash(bytes32 _hash) external {
        coreStateHash = _hash;
    }

    function setConfig(Config memory _config) external {
        testConfig = _config;
    }

    function getConfig() public view override returns (Config memory) {
        // Always return the configured testConfig
        return testConfig;
    }

    function getCoreStateHash() external view returns (bytes32) {
        return coreStateHash;
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

    function totalSupply() external pure returns (uint256) { return 0; }
    function balanceOf(address) external pure returns (uint256) { return 0; }
    function allowance(address, address) external pure returns (uint256) { return 0; }
}

contract StubSyncedBlockManager {
    function saveSyncedBlock(uint48, bytes32, bytes32) external { }
}

contract StubForcedInclusionStore {
    function isOldestForcedInclusionDue() external pure returns (bool) { return false; }
    function consumeOldestForcedInclusion(address) external pure returns (IForcedInclusionStore.ForcedInclusion memory) { 
        revert("Not implemented");
    }
}

contract StubProofVerifier {
    function verifyProof(bytes calldata, bytes calldata) external pure { }
}

contract StubProposerChecker {
    function checkProposer(address) external pure { }
}