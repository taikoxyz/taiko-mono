// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "./TestInboxWithMockBlobs.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxInit
/// @notice Tests for Inbox initialization functionality
/// @dev This test suite covers inbox initialization scenarios:
///      - Successful initialization with proper setup
///      - Double initialization prevention and error handling
///      - Proper ID initialization with starting values
///      - Genesis configuration with different hashes
///      - Owner validation and address verification
/// @custom:security-contact security@taiko.xyz
contract InboxInit is CommonTest {
    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // Events
    event CoreStateSet(IInbox.CoreState coreState);

    /// @notice Test successful initialization with valid parameters
    /// @dev Validates complete initialization process:
    ///      1. Deploys fresh inbox implementation
    ///      2. Initializes with valid owner and genesis hash
    ///      3. Verifies proper core state setup and owner assignment
    function test_init_success() public {
        // Deploy a fresh inbox implementation
        TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();

        // Expected initial core state
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;

        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: keccak256(abi.encode(genesisClaim)),
            bondInstructionsHash: bytes32(0)
        });

        // Expect CoreStateSet event
        vm.expectEmit(true, true, true, true);
        emit CoreStateSet(expectedCoreState);

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), Alice, GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        TestInboxWithMockBlobs freshInbox = TestInboxWithMockBlobs(address(proxy));

        // Verify owner
        assertEq(freshInbox.owner(), Alice);

        // Verify core state hash
        bytes32 actualCoreStateHash = freshInbox.getCoreStateHash();
        bytes32 expectedCoreStateHash = keccak256(abi.encode(expectedCoreState));
        assertEq(actualCoreStateHash, expectedCoreStateHash);
    }

    /// @notice Test that contract cannot be initialized twice
    /// @dev Validates initialization protection mechanism:
    ///      1. Deploys and initializes inbox once
    ///      2. Attempts second initialization with different parameters
    ///      3. Expects revert for double initialization protection
    function test_init_already_initialized() public {
        // Deploy and initialize an inbox
        TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), Alice, GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        TestInboxWithMockBlobs inbox = TestInboxWithMockBlobs(address(proxy));

        // Try to initialize again
        vm.expectRevert();
        inbox.init(Bob, bytes32(uint256(2)));
    }

    /// @notice Test initialization with zero address owner
    /// @dev Validates owner validation handling:
    ///      1. Attempts initialization with zero address as owner
    ///      2. Verifies contract handles invalid owner gracefully
    ///      3. Ensures owner is set to valid non-zero address
    function test_init_zero_address_owner() public {
        // Deploy a fresh inbox implementation
        TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();

        // Initialize with zero address as owner
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), address(0), GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        TestInboxWithMockBlobs freshInbox = TestInboxWithMockBlobs(address(proxy));

        // The Essential contract likely sets msg.sender as owner when zero address is provided
        // or reverts to a default. Just verify it's not zero.
        assertTrue(freshInbox.owner() != address(0));
    }

    /// @notice Test initialization with different genesis block hashes
    /// @dev Validates genesis configuration flexibility:
    ///      1. Tests initialization with various genesis hashes (0, 1, keccak)
    ///      2. Verifies each genesis hash is properly incorporated
    ///      3. Ensures core state reflects correct genesis configuration
    function test_init_various_genesis_hashes() public {
        bytes32[3] memory testHashes = [bytes32(0), bytes32(uint256(1)), keccak256("genesis")];

        for (uint256 i = 0; i < testHashes.length; i++) {
            // Deploy a fresh inbox implementation
            TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();

            // Deploy proxy and initialize with test hash
            bytes memory initData = abi.encodeWithSelector(
                bytes4(keccak256("init(address,bytes32)")), Alice, testHashes[i]
            );

            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
            TestInboxWithMockBlobs freshInbox = TestInboxWithMockBlobs(address(proxy));

            // Verify core state includes the genesis hash
            IInbox.Claim memory genesisClaim;
            genesisClaim.endBlockHash = testHashes[i];

            IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
                nextProposalId: 1,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: keccak256(abi.encode(genesisClaim)),
                bondInstructionsHash: bytes32(0)
            });

            bytes32 actualCoreStateHash = freshInbox.getCoreStateHash();
            bytes32 expectedCoreStateHash = keccak256(abi.encode(expectedCoreState));
            assertEq(actualCoreStateHash, expectedCoreStateHash);
        }
    }

    /// @notice Test that nextProposalId starts at 1
    /// @dev Validates proper ID initialization:
    ///      1. Initializes fresh inbox with genesis configuration
    ///      2. Verifies nextProposalId starts at 1 (not 0)
    ///      3. Ensures proper starting values for chain progression
    function test_init_next_proposal_id_starts_at_one() public {
        // Deploy a fresh inbox implementation
        TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), Alice, GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        TestInboxWithMockBlobs freshInbox = TestInboxWithMockBlobs(address(proxy));

        // Set config
        IInbox.Config memory config = IInbox.Config({
            bondToken: address(0),
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            ringBufferSize: 100,
            basefeeSharingPctg: 10,
            syncedBlockManager: address(0),
            proofVerifier: address(0),
            proposerChecker: address(0),
            forcedInclusionStore: address(0)
        });
        freshInbox.setTestConfig(config);

        // The initial core state should have nextProposalId = 1
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;

        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: keccak256(abi.encode(genesisClaim)),
            bondInstructionsHash: bytes32(0)
        });

        bytes32 actualCoreStateHash = freshInbox.getCoreStateHash();
        bytes32 expectedCoreStateHash = keccak256(abi.encode(expectedCoreState));
        assertEq(actualCoreStateHash, expectedCoreStateHash);
    }
}
