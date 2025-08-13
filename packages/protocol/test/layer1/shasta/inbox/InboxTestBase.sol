// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/layer1/shasta/libs/LibDecoder.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./TestInboxWithMockBlobs.sol";
import "./InboxTestUtils.sol";

/// @title InboxTestBase
/// @notice Base contract for all inbox tests with common setup and helper functions
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTestBase is CommonTest {
    using LibDecoder for bytes;
    using InboxTestUtils for *;

    // Test inbox instance
    TestInboxWithMockBlobs internal inbox;

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

        // Setup mock addresses
        setupMockAddresses();

        // Deploy and initialize inbox
        deployInbox();

        // Setup default configuration
        setupDefaultConfig();

        // Fund test accounts
        fundTestAccounts();
    }

    function setupMockAddresses() internal virtual {
        bondToken = makeAddr("bondToken");
        syncedBlockManager = makeAddr("syncedBlockManager");
        forcedInclusionStore = makeAddr("forcedInclusionStore");
        proofVerifier = makeAddr("proofVerifier");
        proposerChecker = makeAddr("proposerChecker");
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

    function setupBlobHashes() internal virtual {
        setupBlobHashesWithCount(256);
    }

    function setupBlobHashesWithCount(uint256 _count) internal virtual {
        bytes32[] memory hashes = InboxTestUtils.generateBlobHashes(_count);
        vm.blobhashes(hashes);
    }

    // Common helper functions - delegating to utility library

    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId
    )
        internal
        pure
        returns (IInbox.CoreState memory)
    {
        return InboxTestUtils.createCoreState(_nextProposalId, _lastFinalizedProposalId);
    }

    function createCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedClaimHash
    )
        internal
        pure
        returns (IInbox.CoreState memory)
    {
        return InboxTestUtils.createCoreStateFull(
            _nextProposalId, _lastFinalizedProposalId, _lastFinalizedClaimHash, bytes32(0)
        );
    }

    function createValidBlobReference(uint256 _seed)
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return InboxTestUtils.createBlobReference(uint8(_seed % 10));
    }

    function createValidProposal(uint48 _id) internal view returns (IInbox.Proposal memory) {
        return InboxTestUtils.createProposal(_id, Alice, DEFAULT_BASEFEE_SHARING_PCTG);
    }

    function createValidClaim(
        IInbox.Proposal memory _proposal,
        bytes32 _parentClaimHash
    )
        internal
        pure
        returns (IInbox.Claim memory)
    {
        return InboxTestUtils.createClaim(_proposal, _parentClaimHash, _proposal.proposer);
    }

    function encodeProposalData(
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return InboxTestUtils.encodeProposalData(_coreState, _blobRef, _claimRecords);
    }

    function encodeProposalDataWithDeadline(
        uint64 _deadline,
        IInbox.CoreState memory _coreState,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        returns (bytes memory)
    {
        return InboxTestUtils.encodeProposalDataWithDeadline(
            _deadline, _coreState, _blobRef, _claimRecords
        );
    }

    // ---------------------------------------------------------------
    // Mock Helper Functions
    // ---------------------------------------------------------------

    /// @dev Sets up standard mocks for a valid proposal submission
    function setupStandardProposalMocks(address _proposer) internal {
        mockProposerAllowed(_proposer);
        mockForcedInclusionDue(false);
    }

    /// @dev Sets up standard mocks for a valid proof submission
    function setupStandardProofMocks(bool _valid) internal {
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

    /// @dev Batch setup for multiple synced block saves
    function expectMultipleSyncedBlockSaves(IInbox.Claim[] memory _claims) internal {
        for (uint256 i = 0; i < _claims.length; i++) {
            expectSyncedBlockSave(
                _claims[i].endBlockNumber,
                _claims[i].endBlockHash,
                _claims[i].endStateRoot
            );
        }
    }
}
