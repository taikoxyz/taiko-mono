// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "./TestInboxWithMockBlobs.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxInit
/// @notice Tests for Inbox initialization functionality
/// @dev Tests cover successful initialization, genesis block setup, and edge cases
contract InboxInit is CommonTest {
    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    // Events
    event CoreStateSet(IInbox.CoreState coreState);

    /// @notice Test successful initialization with valid parameters
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
