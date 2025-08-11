// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";
import "contracts/layer1/shasta/impl/InboxWithSlotOptimization.sol";

/// @title InboxDefaultSlotCollision
/// @notice Tests for the edge case where parent claim hash equals _DEFAULT_SLOT_HASH
/// @dev Verifies that the optimization handles this extremely unlikely collision correctly
contract InboxDefaultSlotCollision is ShastaInboxTestBase {
    // The default slot hash used in the optimization
    bytes32 constant DEFAULT_SLOT_HASH = bytes32(uint256(1));

    TestInboxOptimized inboxOptimized;

    function setUp() public override {
        super.setUp();

        // Deploy optimized inbox for testing
        inboxOptimized = new TestInboxOptimized();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), address(this), GENESIS_BLOCK_HASH
        );
        inboxOptimized = TestInboxOptimized(deployProxy(address(inboxOptimized), initData));
        inboxOptimized.setConfig(defaultConfig);
    }

    /// @notice Test that setting a claim with parent hash equal to DEFAULT_SLOT_HASH reverts
    /// @dev This protects against the extremely unlikely collision
    function test_default_slot_collision_reverts() public {
        uint48 proposalId = 1;
        bytes32 claimRecordHash = keccak256("test_claim");

        // First set the proposal hash
        inboxOptimized.exposed_setProposalHash(proposalId, keccak256("test_proposal"));

        // Try to set a claim with parent hash equal to DEFAULT_SLOT_HASH
        // This should revert with "Invalid parent claim hash"
        vm.expectRevert("Invalid parent claim hash");
        inboxOptimized.exposed_setClaimRecordHash(
            proposalId,
            DEFAULT_SLOT_HASH, // This is the collision case
            claimRecordHash
        );
    }

    /// @notice Test that getting a claim with parent hash equal to DEFAULT_SLOT_HASH returns 0
    /// @dev This ensures we don't accidentally return the optimization data
    function test_default_slot_collision_get_returns_zero() public {
        uint48 proposalId = 1;

        // Set a normal claim first (this will use the default slot)
        bytes32 normalParentHash = keccak256("normal_parent");
        bytes32 normalClaimHash = keccak256("normal_claim");

        inboxOptimized.exposed_setProposalHash(proposalId, keccak256("test_proposal"));
        inboxOptimized.exposed_setClaimRecordHash(proposalId, normalParentHash, normalClaimHash);

        // Now try to get a claim with parent hash equal to DEFAULT_SLOT_HASH
        // This should return 0, not the data in the default slot
        bytes32 result = inboxOptimized.exposed_getClaimRecordHash(proposalId, DEFAULT_SLOT_HASH);

        assertEq(result, bytes32(0), "Should return zero for DEFAULT_SLOT_HASH query");

        // Verify the normal claim still works
        bytes32 normalResult =
            inboxOptimized.exposed_getClaimRecordHash(proposalId, normalParentHash);
        assertEq(normalResult, normalClaimHash, "Normal claim should still be retrievable");
    }

    /// @notice Test that the optimization works correctly with values close to DEFAULT_SLOT_HASH
    /// @dev Ensures no off-by-one errors or similar issues
    function test_values_near_default_slot_hash() public {
        uint48 proposalId = 1;

        // Test with values close to DEFAULT_SLOT_HASH
        bytes32[] memory testHashes = new bytes32[](3);
        testHashes[0] = bytes32(uint256(0)); // Zero
        testHashes[1] = bytes32(uint256(2)); // DEFAULT_SLOT_HASH + 1
        testHashes[2] = bytes32(uint256(type(uint256).max)); // Max value

        inboxOptimized.exposed_setProposalHash(proposalId, keccak256("test_proposal"));

        for (uint256 i = 0; i < testHashes.length; i++) {
            // These should all work fine (not equal to DEFAULT_SLOT_HASH)
            bytes32 claimHash = keccak256(abi.encode("claim", i));

            // Create a new proposal for each test to avoid multiple claims
            uint48 testProposalId = uint48(proposalId + i);
            inboxOptimized.exposed_setProposalHash(
                testProposalId, keccak256(abi.encode("proposal", i))
            );

            // Should not revert
            inboxOptimized.exposed_setClaimRecordHash(testProposalId, testHashes[i], claimHash);

            // Should be retrievable
            bytes32 retrieved =
                inboxOptimized.exposed_getClaimRecordHash(testProposalId, testHashes[i]);

            assertEq(retrieved, claimHash, "Claim should be retrievable");
        }
    }

    /// @notice Fuzz test to ensure DEFAULT_SLOT_HASH collision is handled for any proposal ID
    /// @param proposalId Random proposal ID to test
    /// @param claimRecordHash Random claim record hash to test
    function testFuzz_default_slot_collision(uint48 proposalId, bytes32 claimRecordHash) public {
        // Skip proposal ID 0 as it might have special behavior
        vm.assume(proposalId > 0);
        vm.assume(claimRecordHash != bytes32(0));

        // Set proposal hash
        inboxOptimized.exposed_setProposalHash(
            proposalId, keccak256(abi.encode("proposal", proposalId))
        );

        // Should always revert when trying to use DEFAULT_SLOT_HASH as parent
        vm.expectRevert("Invalid parent claim hash");
        inboxOptimized.exposed_setClaimRecordHash(proposalId, DEFAULT_SLOT_HASH, claimRecordHash);

        // Getting with DEFAULT_SLOT_HASH should always return 0
        bytes32 result = inboxOptimized.exposed_getClaimRecordHash(proposalId, DEFAULT_SLOT_HASH);
        assertEq(result, bytes32(0), "Should always return zero for DEFAULT_SLOT_HASH");
    }
}

// Test contract that exposes internal functions
contract TestInboxOptimized is InboxWithSlotOptimization {
    IInbox.Config private _config;

    function setConfig(IInbox.Config memory config) external {
        _config = config;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return _config;
    }

    function exposed_setClaimRecordHash(
        uint48 proposalId,
        bytes32 parentClaimHash,
        bytes32 claimRecordHash
    )
        external
    {
        _setClaimRecordHash(_config, proposalId, parentClaimHash, claimRecordHash);
    }

    function exposed_getClaimRecordHash(
        uint48 proposalId,
        bytes32 parentClaimHash
    )
        external
        view
        returns (bytes32)
    {
        return _getClaimRecordHash(_config, proposalId, parentClaimHash);
    }

    function exposed_setProposalHash(uint48 proposalId, bytes32 proposalHash) external {
        _setProposalHash(_config, proposalId, proposalHash);
    }
}
