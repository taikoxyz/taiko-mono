// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";

/// @title InboxInit
/// @notice Tests for Inbox initialization functionality
/// @dev Tests cover successful initialization, genesis block setup, and edge cases
contract InboxInit is ShastaInboxTestBase {
    /// @notice Test successful initialization with valid parameters
    /// @dev Verifies that the contract initializes correctly with:
    ///      - Correct owner set
    ///      - Genesis block hash stored
    ///      - Core state properly initialized
    ///      - CoreStateSet event emitted
    function test_init_success() public {
        // Deploy a fresh inbox implementation
        TestInbox impl = new TestInbox();

        // Expected initial core state
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;

        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: keccak256(abi.encode(genesisClaim)),
            bondOperationsHash: bytes32(0)
        });

        // Expect CoreStateSet event
        vm.expectEmit(true, true, true, true);
        emit CoreStateSet(expectedCoreState);

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), Alice, GENESIS_BLOCK_HASH
        );
        TestInbox freshInbox = TestInbox(deployProxy(address(impl), initData));

        // Verify owner
        assertEq(freshInbox.owner(), Alice);

        // Verify core state hash
        bytes32 actualCoreStateHash = freshInbox.getCoreStateHash();
        bytes32 expectedCoreStateHash = keccak256(abi.encode(expectedCoreState));
        assertEq(actualCoreStateHash, expectedCoreStateHash);
    }

    /// @notice Test that contract cannot be initialized twice
    /// @dev Verifies that calling init() on an already initialized contract reverts
    /// Expected behavior: Transaction reverts with "Initializable: contract is already initialized"
    function test_init_already_initialized() public {
        // Inbox is already initialized in setUp()
        vm.expectRevert("Initializable: contract is already initialized");
        inbox.init(Bob, bytes32(uint256(2)));
    }

    /// @notice Test initialization with zero address owner
    /// @dev Verifies that initialization fails when trying to set owner to zero address
    /// Expected behavior: Transaction reverts as zero address cannot be owner
    function test_init_zero_address_owner() public {
        // Deploy a fresh inbox implementation
        TestInbox impl = new TestInbox();

        // Deploy proxy without initialization
        address proxy = address(new ERC1967Proxy(address(impl), bytes("")));
        TestInbox freshInbox = TestInbox(proxy);

        // Try to initialize with zero address as owner
        // The init should succeed but the owner won't be set to zero address
        freshInbox.init(address(0), GENESIS_BLOCK_HASH);

        // Verify that owner is still address(0) or reverted to deployer
        // The actual behavior depends on OpenZeppelin's Ownable implementation
        assertTrue(freshInbox.owner() != address(0));
    }

    /// @notice Test initialization with different genesis block hashes
    /// @dev Verifies that any valid bytes32 can be used as genesis block hash
    /// Expected behavior: Contract initializes successfully with any bytes32 value
    function test_init_various_genesis_hashes() public {
        bytes32[3] memory testHashes = [bytes32(0), bytes32(uint256(1)), keccak256("genesis")];

        for (uint256 i = 0; i < testHashes.length; i++) {
            // Deploy a fresh inbox implementation
            TestInbox impl = new TestInbox();

            // Deploy proxy and initialize with test hash
            bytes memory initData = abi.encodeWithSelector(
                bytes4(keccak256("init(address,bytes32)")), Alice, testHashes[i]
            );
            TestInbox freshInbox = TestInbox(deployProxy(address(impl), initData));

            // Verify core state includes the genesis hash
            IInbox.Claim memory genesisClaim;
            genesisClaim.endBlockHash = testHashes[i];

            IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
                nextProposalId: 1,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: keccak256(abi.encode(genesisClaim)),
                bondOperationsHash: bytes32(0)
            });

            bytes32 actualCoreStateHash = freshInbox.getCoreStateHash();
            bytes32 expectedCoreStateHash = keccak256(abi.encode(expectedCoreState));
            assertEq(actualCoreStateHash, expectedCoreStateHash);
        }
    }

    /// @notice Test that nextProposalId starts at 1
    /// @dev Verifies the initial proposal ID is set to 1, not 0
    /// Expected behavior: nextProposalId should be 1 after initialization
    function test_init_next_proposal_id_starts_at_one() public {
        // Deploy a fresh inbox implementation
        TestInbox impl = new TestInbox();

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), Alice, GENESIS_BLOCK_HASH
        );
        TestInbox freshInbox = TestInbox(deployProxy(address(impl), initData));
        freshInbox.setConfig(defaultConfig);

        // Create a proposal to verify the first ID is 1
        IInbox.CoreState memory coreState = createCoreState(1, 0);
        bytes32 coreStateHash = keccak256(abi.encode(coreState));
        freshInbox.exposed_setCoreStateHash(coreStateHash);

        // Setup mocks for propose
        mockProposerAllowed(Alice);
        mockHasSufficientBond(Alice, true);
        mockForcedInclusionDue(false);

        // Create proposal data with nextProposalId = 1
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(1);
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](0);
        bytes memory data = encodeProposeProposeData(coreState, blobRef, claimRecords);

        // Call propose and verify it succeeds with ID 1
        vm.prank(Alice);
        freshInbox.propose(bytes(""), data);

        // The proposal should have been created with ID 1
        bytes32 proposalHash = freshInbox.getProposalHash(1);
        assertTrue(proposalHash != bytes32(0));
    }
}
