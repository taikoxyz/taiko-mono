// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/CommonTest.sol";
import "./InboxTestLib.sol";
import "./TestInboxWithMockBlobs.sol";
import "./InboxMockContracts.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxTest
/// @notice Consolidated base contract for all Inbox tests
/// @dev Single base class with all common functionality
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTest is CommonTest {
    using InboxTestLib for *;

    // ---------------------------------------------------------------
    // Test Contract Instance
    // ---------------------------------------------------------------

    TestInboxWithMockBlobs internal inbox;

    // ---------------------------------------------------------------
    // Mock Dependencies
    // ---------------------------------------------------------------

    address internal bondToken;
    address internal syncedBlockManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // ---------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------

    IInbox.Config internal defaultConfig;

    uint256 internal constant DEFAULT_RING_BUFFER_SIZE = 100;
    uint256 internal constant DEFAULT_MAX_FINALIZATION_COUNT = 10;
    uint48 internal constant DEFAULT_PROVING_WINDOW = 1 hours;
    uint48 internal constant DEFAULT_EXTENDED_PROVING_WINDOW = 2 hours;
    uint8 internal constant DEFAULT_BASEFEE_SHARING_PCTG = 10;
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event CoreStateSet(IInbox.CoreState coreState);
    event Proposed(IInbox.Proposal proposal, IInbox.CoreState coreState);
    event Proved(IInbox.Proposal proposal, IInbox.ClaimRecord claimRecord);
    event BondInstructed(LibBonds.BondInstruction[] instructions);

    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        setupMockAddresses();
        deployInbox();
        setupDefaultConfig();
        fundTestAccounts();
    }

    function setupMockAddresses() internal virtual {
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());
    }

    function deployInbox() internal virtual {
        TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), address(this), GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        inbox = TestInboxWithMockBlobs(address(proxy));
    }

    function setupDefaultConfig() internal virtual {
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

        inbox.setTestConfig(defaultConfig);
        inbox.setMockBlobValidation(true);
    }

    function fundTestAccounts() internal virtual {
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
        vm.deal(Carol, 100 ether);
    }

    // ---------------------------------------------------------------
    // Blob Hash Setup
    // ---------------------------------------------------------------

    function setupBlobHashes() internal virtual {
        setupBlobHashes(256);
    }

    function setupBlobHashes(uint256 _count) internal {
        bytes32[] memory hashes = InboxTestLib.generateBlobHashes(_count);
        vm.blobhashes(hashes);
    }

    // ---------------------------------------------------------------
    // Mock Helpers
    // ---------------------------------------------------------------

    function setupProposalMocks(address _proposer) internal {
        mockProposerAllowed(_proposer);
        mockForcedInclusionDue(false);
    }

    function setupProofMocks(bool _valid) internal {
        mockProofVerification(_valid);
    }

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
                bytes("Invalid proof")
            );
        }
    }

    function expectSyncedBlockSave(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        internal
    {
        vm.expectCall(
            syncedBlockManager,
            abi.encodeWithSelector(
                ISyncedBlockManager.saveSyncedBlock.selector, _blockNumber, _blockHash, _stateRoot
            )
        );
    }

    // ---------------------------------------------------------------
    // Common Test Scenarios
    // ---------------------------------------------------------------

    /// @dev Submits a proposal and returns it
    function submitProposal(
        uint48 _proposalId,
        address _proposer
    )
        internal
        returns (IInbox.Proposal memory proposal)
    {
        // Setup core state
        IInbox.CoreState memory coreState = InboxTestLib.createCoreState(_proposalId, 0);
        inbox.exposed_setCoreStateHash(coreState.hashCoreState());

        // Setup mocks
        setupProposalMocks(_proposer);

        // Create proposal
        proposal = InboxTestLib.createProposal(_proposalId, _proposer, DEFAULT_BASEFEE_SHARING_PCTG);

        // Create proposal data
        bytes memory data = InboxTestLib.encodeProposalData(
            coreState,
            InboxTestLib.createBlobReference(uint8(_proposalId)),
            new IInbox.ClaimRecord[](0)
        );

        // Submit proposal
        vm.prank(_proposer);
        inbox.propose(bytes(""), data);
    }

    /// @dev Proves a proposal and returns the claim
    function proveProposal(
        IInbox.Proposal memory _proposal,
        address _prover,
        bytes32 _parentClaimHash
    )
        internal
        returns (IInbox.Claim memory claim)
    {
        // Create claim
        claim = InboxTestLib.createClaim(_proposal, _parentClaimHash, _prover);

        // Setup proof verification
        setupProofMocks(true);

        // Prepare prove data
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposal;
        IInbox.Claim[] memory claims = new IInbox.Claim[](1);
        claims[0] = claim;

        // Submit proof
        vm.prank(_prover);
        inbox.prove(InboxTestLib.encodeProveData(proposals, claims), bytes("proof"));
    }

    /// @dev Creates and proves a chain of proposals
    function createProvenChain(
        uint48 _startId,
        uint48 _count,
        bytes32 _initialParentHash
    )
        internal
        returns (IInbox.Proposal[] memory proposals, IInbox.Claim[] memory claims)
    {
        InboxTestLib.ProposalChain memory chain = InboxTestLib.createProposalChain(
            _startId, _count, Alice, Bob, _initialParentHash, DEFAULT_BASEFEE_SHARING_PCTG
        );

        proposals = chain.proposals;
        claims = chain.claims;

        // Submit all proposals
        for (uint48 i = 0; i < _count; i++) {
            submitProposal(_startId + i, Alice);
        }

        // Prove all at once
        setupProofMocks(true);
        vm.prank(Bob);
        inbox.prove(InboxTestLib.encodeProveData(proposals, claims), bytes("proof"));
    }

    // ---------------------------------------------------------------
    // Assertions
    // ---------------------------------------------------------------

    function assertProposalStored(uint48 _proposalId) internal view {
        bytes32 storedHash = inbox.getProposalHash(_proposalId);
        assertTrue(storedHash != bytes32(0), "Proposal not stored");
    }

    function assertClaimRecordStored(uint48 _proposalId, bytes32 _parentClaimHash) internal view {
        bytes32 storedHash = inbox.getClaimRecordHash(_proposalId, _parentClaimHash);
        assertTrue(storedHash != bytes32(0), "Claim record not stored");
    }

    function assertProposalsStored(uint48 _startId, uint48 _count) internal view {
        for (uint48 i = 0; i < _count; i++) {
            assertProposalStored(_startId + i);
        }
    }

    function assertCoreState(
        uint48 _expectedNextProposalId,
        uint48 _expectedLastFinalizedId
    )
        internal
        view
    {
        IInbox.CoreState memory expected =
            InboxTestLib.createCoreState(_expectedNextProposalId, _expectedLastFinalizedId);
        bytes32 expectedHash = expected.hashCoreState();
        bytes32 actualHash = inbox.getCoreStateHash();
        assertEq(actualHash, expectedHash, "Core state mismatch");
    }

    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------

    function getGenesisClaimHash() internal pure returns (bytes32) {
        return InboxTestLib.getGenesisClaimHash(GENESIS_BLOCK_HASH);
    }

    function createValidProposal(uint48 _id) internal view returns (IInbox.Proposal memory) {
        return InboxTestLib.createProposal(_id, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
    }

    function createValidBlobReference(uint256 _seed)
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return InboxTestLib.createBlobReference(uint8(_seed % 256));
    }
}
