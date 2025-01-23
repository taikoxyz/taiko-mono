// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./ForcedInclusionStoreTestBase.sol";
import "src/layer1/based/IForcedInclusionStore.sol";

contract ForcedInclusionStoreTest is ForcedInclusionStoreTestBase {

    function test_updateBasePriorityFee() public {
        // get original fee
        uint256 originalFee = store.basePriorityFee();
        vm.prank(storeOwner);
        store.updateBasePriorityFee(originalFee + 1);
        assertEq(store.basePriorityFee(), originalFee + 1);
    }

    function test_updateBasePriorityFee_onlyOwner() public {
        vm.prank(Carol);
        vm.expectRevert();
        store.updateBasePriorityFee(200);
    }

    function test_storeForcedInclusion_success() public {
        bytes32 blobHash = keccak256("test_blob");
        uint32 blobByteOffset = 0;
        uint32 blobByteSize = 1024;
        uint256 requiredFee = store.getRequiredPriorityFee();

        vm.prank(Alice);
        vm.deal(Alice, requiredFee);
        store.storeForcedInclusion{value: requiredFee}(blobHash, blobByteOffset, blobByteSize);

        IForcedInclusionStore.ForcedInclusion[] memory forcedInclusion = store.getForcedInclusions();

        assertEq(forcedInclusion.length, 1);
        assertEq(forcedInclusion[0].blobHash, blobHash);
        assertEq(forcedInclusion[0].blobByteOffset, blobByteOffset);
        assertEq(forcedInclusion[0].blobByteSize, blobByteSize);
        assertEq(forcedInclusion[0].priorityFee, requiredFee);
        assertEq(forcedInclusion[0].id, 1);
    }

    function test_storeForcedInclusion_insufficientFee() public {
        bytes32 blobHash = keccak256("test_blob");
        uint32 blobByteOffset = 0;
        uint32 blobByteSize = 1024;

        // get required fee
        uint256 requiredFee = store.getRequiredPriorityFee();
        emit log_named_uint("Required Fee", requiredFee);
        vm.prank(Alice);
        vm.deal(Alice, 1 ether);
        vm.expectRevert(IForcedInclusionStore.ForcedInclusionInsufficientPriorityFee.selector);
        store.storeForcedInclusion{value: requiredFee - 1}(blobHash, blobByteOffset, blobByteSize);

        IForcedInclusionStore.ForcedInclusion[] memory forcedInclusion = store.getForcedInclusions();
        assertEq(forcedInclusion.length, 0);
    }

    function test_storeForcedInclusion_multipleEntries() public {
        bytes32 blobHash1 = keccak256("test_blob_1");
        bytes32 blobHash2 = keccak256("test_blob_2");
        uint32 blobByteOffset = 0;
        uint32 blobByteSize = 512;
        uint256 requiredFee = store.getRequiredPriorityFee();

        vm.prank(Alice);
        vm.deal(Alice, 1 ether);
        store.storeForcedInclusion{value: requiredFee}(blobHash1, blobByteOffset, blobByteSize);

        requiredFee = store.getRequiredPriorityFee();
        store.storeForcedInclusion{value: requiredFee}(blobHash2, blobByteOffset, blobByteSize);

        IForcedInclusionStore.ForcedInclusion[] memory forcedInclusion = store.getForcedInclusions();

        assertEq(forcedInclusion.length, 2);
        assertEq(forcedInclusion[0].blobHash, blobHash1);
        assertEq(forcedInclusion[0].blobByteOffset, blobByteOffset);
        assertEq(forcedInclusion[0].blobByteSize, blobByteSize);
        assertEq(forcedInclusion[0].priorityFee, requiredFee);
        assertEq(forcedInclusion[0].id, 1);

        assertEq(forcedInclusion[1].blobHash, blobHash2);
        assertEq(forcedInclusion[1].blobByteOffset, blobByteOffset);
        assertEq(forcedInclusion[1].blobByteSize, blobByteSize);
        assertEq(forcedInclusion[1].priorityFee, requiredFee);
        assertEq(forcedInclusion[1].id, 2);
    }

    function test_consumeForcedInclusion_success() public {
        bytes32 blobHash = keccak256("test_blob");
        uint32 blobByteOffset = 0;
        uint32 blobByteSize = 1024;
        uint256 requiredFee = store.getRequiredPriorityFee();

        vm.prank(Alice);
        vm.deal(Alice, requiredFee);
        store.storeForcedInclusion{value: requiredFee}(blobHash, blobByteOffset, blobByteSize);

        vm.warp(block.timestamp + inclusionWindow + 1);

        vm.prank(operator);
        IForcedInclusionStore.ForcedInclusion memory consumed = store.consumeForcedInclusion();

        assertEq(consumed.blobHash, blobHash);
        assertEq(consumed.blobByteOffset, blobByteOffset);
        assertEq(consumed.blobByteSize, blobByteSize);
        assertEq(consumed.priorityFee, requiredFee);

        // Ensure the forcedInclusions array is empty after consumption
        IForcedInclusionStore.ForcedInclusion[] memory forcedInclusion = store.getForcedInclusions();
        assertEq(forcedInclusion.length, 0);
    }

    function test_consumeForcedInclusion_notOperator() public {
        bytes32 blobHash = keccak256("test_blob");
        uint32 blobByteOffset = 0;
        uint32 blobByteSize = 1024;
        uint256 requiredFee = store.getRequiredPriorityFee();

        vm.prank(operator);
        vm.deal(operator, requiredFee);
        store.storeForcedInclusion{value: requiredFee}(blobHash, blobByteOffset, blobByteSize);

        vm.warp(block.timestamp + inclusionWindow + 1);

        vm.prank(Carol);
        vm.expectRevert(IForcedInclusionStore.NotTaikoForcedInclusionInbox.selector);
        store.consumeForcedInclusion();
    }

    function test_consumeForcedInclusion_noEligibleInclusion() public {
        vm.prank(operator);
        IForcedInclusionStore.ForcedInclusion memory inclusion = store.consumeForcedInclusion();
        assertEq(inclusion.blobHash, bytes32(0));
        assertEq(inclusion.blobByteOffset, 0);
        assertEq(inclusion.blobByteSize, 0);
        assertEq(inclusion.priorityFee, 0);
        assertEq(inclusion.id, 0);
    }

    function test_consumeForcedInclusion_beforeWindowExpires() public {
        bytes32 blobHash = keccak256("test_blob");
        uint32 blobByteOffset = 0;
        uint32 blobByteSize = 1024;
        uint256 requiredFee = store.getRequiredPriorityFee();

        vm.prank(operator);
        vm.deal(Alice, requiredFee);
        store.storeForcedInclusion{value: requiredFee}(blobHash, blobByteOffset, blobByteSize);

        vm.prank(operator);
        IForcedInclusionStore.ForcedInclusion memory inclusion = store.consumeForcedInclusion();
        assertEq(inclusion.blobHash, bytes32(0));
        assertEq(inclusion.blobByteOffset, 0);
        assertEq(inclusion.blobByteSize, 0);
        assertEq(inclusion.priorityFee, 0);
        assertEq(inclusion.id, 0);
    }

}