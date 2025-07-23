// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../shared/CommonTest.sol";
import "src/layer1/forced-inclusion/ForcedInclusionStore.sol";

contract ForcedInclusionStoreForTest is ForcedInclusionStore {
    constructor(
        uint8 _inclusionDelay,
        uint64 _feeInGwei,
        address _taikoInbox,
        address _taikoInboxWrapper
    )
        ForcedInclusionStore(_inclusionDelay, _feeInGwei, _taikoInbox, _taikoInboxWrapper)
    { }

    function _blobHash(uint8 blobIndex) internal view virtual override returns (bytes32) {
        return bytes32(uint256(blobIndex + 1));
    }
}

contract MockInbox {
    uint64 public numBatches;

    constructor() {
        numBatches = 1;
    }

    function setNumBatches(uint64 _numBatches) external {
        numBatches = _numBatches;
    }

    function getSummary() external view returns (IInbox.Summary memory summary_) {
        summary_.nextBatchId = uint48(numBatches);
    }
}

abstract contract ForcedInclusionStoreTestBase is CommonTest {
    address internal storeOwner = Alice;
    address internal whitelistedProposer = Alice;
    uint8 internal constant inclusionDelay = 12;
    uint64 internal constant feeInGwei = 0.001 ether / 1 gwei;

    ForcedInclusionStore internal store;
    MockInbox internal mockInbox;

    function setUpOnEthereum() internal virtual override {
        mockInbox = new MockInbox();
        store = ForcedInclusionStore(
            deploy({
                name: "forced_inclusion_store",
                impl: address(
                    new ForcedInclusionStoreForTest(
                        inclusionDelay, feeInGwei, address(mockInbox), whitelistedProposer
                    )
                ),
                data: abi.encodeCall(ForcedInclusionStore.init, (storeOwner))
            })
        );
    }
}

contract ForcedInclusionStoreTest is ForcedInclusionStoreTestBase {
    function test_storeForcedInclusion_only_once_per_tx() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        uint64 _feeInGwei = store.feeInGwei();

        store.storeForcedInclusion{ value: _feeInGwei * 1 gwei }(0);

        IForcedInclusionStore.ForcedInclusion memory inclusion = store.getForcedInclusion(0);
        
        assertEq(inclusion.blobHash, bytes32(uint256(1)));
        assertEq(inclusion.feeInGwei, _feeInGwei);
        assertEq(inclusion.createdAtBatchId, 1);
        assertEq(inclusion.blobCreatedIn, uint64(block.number));

        // Second call in the same transaction should fail
        vm.expectRevert(IForcedInclusionStore.MultipleCallsInOneTx.selector);
        store.storeForcedInclusion{ value: _feeInGwei * 1 gwei }(1);
    }

    function test_storeForcedInclusion_blob_not_found() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        // Mock returns 0x0 for all indexes in the base test
        vm.expectRevert(IForcedInclusionStore.BlobNotFound.selector);
        store.storeForcedInclusion{ value: 0 }(255); // Out of range index
    }

    function test_storeForcedInclusion_incorrect_fee_zero() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        vm.expectRevert(IForcedInclusionStore.IncorrectFee.selector);
        store.storeForcedInclusion{ value: 0 }(0);
    }

    function test_storeForcedInclusion_incorrect_fee_less() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        vm.expectRevert(IForcedInclusionStore.IncorrectFee.selector);
        store.storeForcedInclusion{ value: feeInGwei * 1 gwei - 1 }(0);
    }

    function test_storeForcedInclusion_incorrect_fee_more() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        vm.expectRevert(IForcedInclusionStore.IncorrectFee.selector);
        store.storeForcedInclusion{ value: feeInGwei * 1 gwei + 1 }(0);
    }

    function test_consume_forced_inclusion() public transactBy(whitelistedProposer) {
        vm.deal(Alice, 1 ether);

        // Store a forced inclusion
        uint64 _feeInGwei = store.feeInGwei();
        vm.prank(Alice);
        store.storeForcedInclusion{ value: _feeInGwei * 1 gwei }(0);

        // Move forward by inclusion delay
        mockInbox.setNumBatches(uint64(inclusionDelay) + 1);

        uint256 balance = whitelistedProposer.balance;

        // Check if it's due
        assertTrue(store.isOldestForcedInclusionDue());

        // Get the oldest before consuming
        IForcedInclusionStore.ForcedInclusion memory oldest = store.getOldestForcedInclusion();
        assertEq(oldest.blobHash, bytes32(uint256(1)));

        // Consume it
        IForcedInclusionStore.ForcedInclusion memory consumed = store.consumeOldestForcedInclusion(whitelistedProposer);
        
        assertEq(consumed.blobHash, oldest.blobHash);
        assertEq(consumed.feeInGwei, _feeInGwei);
        assertEq(whitelistedProposer.balance - balance, _feeInGwei * 1 gwei);
    }

    function test_consume_forced_inclusion_not_whitelisted() public transactBy(Bob) {
        vm.deal(Alice, 1 ether);

        // Store a forced inclusion
        vm.prank(Alice);
        store.storeForcedInclusion{ value: feeInGwei * 1 gwei }(0);

        // Move forward by inclusion delay
        mockInbox.setNumBatches(uint64(inclusionDelay) + 1);

        // Try to consume from non-whitelisted address
        vm.expectRevert();
        store.consumeOldestForcedInclusion(Bob);
    }

    function test_getForcedInclusion_invalid_index() public {
        vm.expectRevert(IForcedInclusionStore.InvalidIndex.selector);
        store.getForcedInclusion(100);
    }

    function test_getOldestForcedInclusion_empty_queue() public {
        vm.expectRevert(IForcedInclusionStore.NoForcedInclusionFound.selector);
        store.getOldestForcedInclusion();
    }

    function test_isOldestForcedInclusionDue() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        // Initially no forced inclusion is due
        assertFalse(store.isOldestForcedInclusionDue());

        // Store a forced inclusion
        store.storeForcedInclusion{ value: feeInGwei * 1 gwei }(0);

        // Still not due immediately
        assertFalse(store.isOldestForcedInclusionDue());

        // Move forward by inclusion delay - 1
        mockInbox.setNumBatches(uint64(inclusionDelay));
        assertFalse(store.isOldestForcedInclusionDue());

        // Move forward by inclusion delay
        mockInbox.setNumBatches(uint64(inclusionDelay) + 1);
        assertTrue(store.isOldestForcedInclusionDue());
    }

    function test_getOldestForcedInclusionDeadline() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        // Initially returns max uint256
        assertEq(store.getOldestForcedInclusionDeadline(), type(uint256).max);

        // Store a forced inclusion
        store.storeForcedInclusion{ value: feeInGwei * 1 gwei }(0);

        // Check deadline
        uint256 deadline = store.getOldestForcedInclusionDeadline();
        assertEq(deadline, 1 + inclusionDelay);
    }
}