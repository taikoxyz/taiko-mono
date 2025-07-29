// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../shared/CommonTest.sol";
import "src/layer1/forced-inclusion/ForcedInclusionStore.sol";
import "src/layer1/based2/IInbox.sol";

contract ForcedInclusionStoreForTest is ForcedInclusionStore {
    constructor(
        uint8 _inclusionDelay,
        uint64 _feeInGwei,
        IInbox _inbox
    )
        ForcedInclusionStore(_inclusionDelay, _feeInGwei, _inbox)
    { }

    function _blobHash(uint8 blobIndex) internal view virtual override returns (bytes32) {
        // Return 0 for blobIndex 255 to test BlobNotFound error
        if (blobIndex == 255) return bytes32(0);
        return bytes32(uint256(blobIndex + 1));
    }
}

contract MockInbox is IInbox {
    uint64 public nextBatchId;

    constructor() {
        nextBatchId = 1;
    }

    function setNextBatchId(uint64 _nextBatchId) external {
        nextBatchId = _nextBatchId;
    }

    function validateSummary(Summary memory _summary) external view {
        // Mock validation - just check that nextBatchId matches
        require(_summary.nextBatchId == nextBatchId, "Invalid summary");
    }

    // Implement other required IInbox functions with empty bodies
    function propose4(bytes calldata) external {}
    function prove4(bytes calldata, bytes calldata) external {}
}

abstract contract ForcedInclusionStoreTestBase is CommonTest {
    address internal storeOwner = Alice;
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
                        inclusionDelay, feeInGwei, IInbox(address(mockInbox))
                    )
                ),
                data: abi.encodeCall(ForcedInclusionStore.init, (storeOwner))
            })
        );
    }
}

contract ForcedInclusionStoreTest is ForcedInclusionStoreTestBase {
    /*//////////////////////////////////////////////////////////////
                               TEST CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 internal constant DEFAULT_BLOB_INDEX = 0;
    uint32 internal constant DEFAULT_BLOB_OFFSET = 0;
    uint32 internal constant DEFAULT_BLOB_SIZE = 1024;
    uint64 internal constant TEST_BATCH_ID = 100;

    /*//////////////////////////////////////////////////////////////
                             HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _createSummary(uint64 _nextBatchId) internal pure returns (IInbox.Summary memory) {
        return IInbox.Summary({
            nextBatchId: uint48(_nextBatchId),
            lastSyncedBlockId: 0,
            lastSyncedAt: 0,
            lastVerifiedBatchId: 0,
            lastVerifiedBlockId: 0,
            gasIssuanceUpdatedAt: 0,
            gasIssuancePerSecond: 0,
            lastVerifiedBlockHash: bytes32(0),
            lastBatchMetaHash: bytes32(0)
        });
    }

    function _getFeeInWei() internal view returns (uint256) {
        return store.feeInGwei() * 1 gwei;
    }

    function _storeForcedInclusion(
        address _prankAs,
        uint8 _blobIndex,
        uint32 _blobOffset,
        uint32 _blobSize,
        uint64 _batchId
    )
        internal
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        vm.prank(_prankAs);
        store.storeForcedInclusion{ value: _getFeeInWei() }(
            _blobIndex,
            _blobOffset,
            _blobSize,
            _createSummary(_batchId)
        );

        return store.getForcedInclusion(store.tail() - 1);
    }
    
    function _storeForcedInclusionWithoutPrank(
        uint8 _blobIndex,
        uint32 _blobOffset,
        uint32 _blobSize,
        uint64 _batchId
    )
        internal
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        store.storeForcedInclusion{ value: _getFeeInWei() }(
            _blobIndex,
            _blobOffset,
            _blobSize,
            _createSummary(_batchId)
        );

        return store.getForcedInclusion(store.tail() - 1);
    }

    function _storeDefaultForcedInclusion(address _prankAs, uint64 _batchId)
        internal
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        return _storeForcedInclusion(
            _prankAs, DEFAULT_BLOB_INDEX, DEFAULT_BLOB_OFFSET, DEFAULT_BLOB_SIZE, _batchId
        );
    }
    
    function _storeDefaultForcedInclusionWithoutPrank(uint64 _batchId)
        internal
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        return _storeForcedInclusionWithoutPrank(
            DEFAULT_BLOB_INDEX, DEFAULT_BLOB_OFFSET, DEFAULT_BLOB_SIZE, _batchId
        );
    }

    function _assertForcedInclusion(
        IForcedInclusionStore.ForcedInclusion memory _inclusion,
        bytes32 _expectedBlobHash,
        uint64 _expectedBatchId,
        uint32 _expectedOffset,
        uint32 _expectedSize
    )
        internal
        view
    {
        assertEq(_inclusion.blobHash, _expectedBlobHash);
        assertEq(_inclusion.createdAtBatchId, _expectedBatchId);
        assertEq(_inclusion.feeInGwei, store.feeInGwei());
        assertEq(_inclusion.blobByteOffset, _expectedOffset);
        assertEq(_inclusion.blobByteSize, _expectedSize);
        assertEq(_inclusion.blobCreatedIn, uint64(block.number));
    }

    function _setMockInboxBatchId(uint64 _batchId) internal {
        mockInbox.setNextBatchId(_batchId);
    }

    /*//////////////////////////////////////////////////////////////
                        STOREFORCEDINCUSION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_storeForcedInclusion_only_once_per_tx() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        uint64 currentBatchId = mockInbox.nextBatchId();
        IForcedInclusionStore.ForcedInclusion memory inclusion =
            _storeDefaultForcedInclusionWithoutPrank(currentBatchId);

        _assertForcedInclusion(
            inclusion,
            bytes32(uint256(1)), // blobIndex + 1
            currentBatchId,
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE
        );

        vm.expectRevert(IForcedInclusionStore.MultipleCallsInOneTx.selector);
        store.storeForcedInclusion{ value: 0 }(
            DEFAULT_BLOB_INDEX,
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE,
            _createSummary(currentBatchId)
        );
    }

    function test_storeForcedInclusion_incorrectFee() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        uint64 currentBatchId = mockInbox.nextBatchId();
        IInbox.Summary memory summary = _createSummary(currentBatchId);
        uint256 correctFee = _getFeeInWei();

        // Test with fee too low
        vm.expectRevert(IForcedInclusionStore.IncorrectFee.selector);
        store.storeForcedInclusion{ value: correctFee - 1 }(
            DEFAULT_BLOB_INDEX,
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE,
            summary
        );

        // Test with fee too high
        vm.expectRevert(IForcedInclusionStore.IncorrectFee.selector);
        store.storeForcedInclusion{ value: correctFee + 1 }(
            DEFAULT_BLOB_INDEX,
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE,
            summary
        );
    }

    /*//////////////////////////////////////////////////////////////
                   CONSUMEOLDESTFORCEDINCUSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_storeConsumeForcedInclusion_success() public {
        vm.deal(Alice, 1 ether);

        _setMockInboxBatchId(TEST_BATCH_ID);
        _storeDefaultForcedInclusion(Alice, TEST_BATCH_ID);

        assertEq(store.head(), 0);
        assertEq(store.tail(), 1);

        vm.prank(address(mockInbox));
        IForcedInclusionStore.ForcedInclusion memory inclusion =
            store.consumeOldestForcedInclusion(Bob, TEST_BATCH_ID + 1);

        _assertForcedInclusion(
            inclusion,
            bytes32(uint256(1)), // blobIndex + 1
            TEST_BATCH_ID,
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE
        );
        assertEq(Bob.balance, _getFeeInWei());
        assertEq(store.lastProcessedAtBatchId(), TEST_BATCH_ID + 1);
    }

    function test_storeConsumeForcedInclusion_notInbox() public {
        vm.deal(Alice, 1 ether);

        _setMockInboxBatchId(TEST_BATCH_ID);
        _storeDefaultForcedInclusion(Alice, TEST_BATCH_ID);

        assertEq(store.head(), 0);
        assertEq(store.tail(), 1);

        vm.prank(Carol);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        store.consumeOldestForcedInclusion(Bob, TEST_BATCH_ID + 1);
    }

    function test_storeConsumeForcedInclusion_noEligibleInclusion() public {
        vm.prank(address(mockInbox));
        vm.expectRevert(IForcedInclusionStore.NoForcedInclusionFound.selector);
        store.consumeOldestForcedInclusion(Bob, 1);
    }

    function test_storeConsumeForcedInclusion_beforeWindowExpires() public {
        vm.deal(Alice, 1 ether);

        _setMockInboxBatchId(TEST_BATCH_ID);
        _storeDefaultForcedInclusion(Alice, TEST_BATCH_ID);

        // Verify the stored request is correct
        IForcedInclusionStore.ForcedInclusion memory inclusion = store.getForcedInclusion(0);
        _assertForcedInclusion(
            inclusion,
            bytes32(uint256(1)), // blobIndex + 1
            TEST_BATCH_ID,
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE
        );

        vm.prank(address(mockInbox));
        // head request should be consumable
        inclusion = store.consumeOldestForcedInclusion(Bob, TEST_BATCH_ID + 1);
        _assertForcedInclusion(
            inclusion,
            bytes32(uint256(1)), // blobIndex + 1
            TEST_BATCH_ID,
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE
        );

        // the head request should have been deleted
        vm.expectRevert(IForcedInclusionStore.InvalidIndex.selector);
        inclusion = store.getForcedInclusion(0);
    }

    function test_getOldestForcedInclusionDeadline_emptyQueue() public view {
        uint256 deadline = store.getOldestForcedInclusionDeadline();
        assertEq(deadline, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                  GETOLDESTFORCEDINCLUSIONDEADLINE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getOldestForcedInclusionDeadline_withInclusion() public {
        vm.deal(Alice, 1 ether);

        _setMockInboxBatchId(TEST_BATCH_ID);
        _storeDefaultForcedInclusion(Alice, TEST_BATCH_ID);

        uint256 deadline = store.getOldestForcedInclusionDeadline();
        // Should be createdAtBatchId + inclusionDelay
        assertEq(deadline, TEST_BATCH_ID + inclusionDelay);
    }

    function test_getOldestForcedInclusionDeadline_afterProcessing() public {
        vm.deal(Alice, 1 ether);

        _setMockInboxBatchId(TEST_BATCH_ID);
        _storeDefaultForcedInclusion(Alice, TEST_BATCH_ID);

        uint64 processBatchId = TEST_BATCH_ID + 5;
        // Process at later batch
        vm.prank(address(mockInbox));
        store.consumeOldestForcedInclusion(Bob, processBatchId);

        // After processing, with empty queue, deadline should be max uint256
        uint256 deadline = store.getOldestForcedInclusionDeadline();
        assertEq(deadline, type(uint256).max);
        
        // Verify lastProcessedAtBatchId was updated
        assertEq(store.lastProcessedAtBatchId(), processBatchId);
    }

    /*//////////////////////////////////////////////////////////////
                     ISOLDESTFORCEDINCLUSIONDUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isOldestForcedInclusionDue() public {
        vm.deal(Alice, 1 ether);

        _setMockInboxBatchId(TEST_BATCH_ID);
        _storeDefaultForcedInclusion(Alice, TEST_BATCH_ID);

        uint64 deadline = TEST_BATCH_ID + inclusionDelay;
        
        // Not due yet
        assertFalse(store.isOldestForcedInclusionDue(deadline - 1));
        
        // Due at exactly the deadline
        assertTrue(store.isOldestForcedInclusionDue(deadline));
        
        // Due after the deadline
        assertTrue(store.isOldestForcedInclusionDue(deadline + 1));
    }

    function test_isOldestForcedInclusionDue_emptyQueue() public view {
        // Should return false when queue is empty
        assertFalse(store.isOldestForcedInclusionDue(1000));
    }

    /*//////////////////////////////////////////////////////////////
                              ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_storeForcedInclusion_blobNotFound() public {
        vm.deal(Alice, 1 ether);

        uint64 currentBatchId = mockInbox.nextBatchId();
        uint256 fee = _getFeeInWei();

        // blobIndex 255 returns 0 in our test contract
        vm.prank(Alice);
        vm.expectRevert(IForcedInclusionStore.BlobNotFound.selector);
        store.storeForcedInclusion{ value: fee }(
            255, // blobIndex that returns 0
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE,
            _createSummary(currentBatchId)
        );
    }

    function test_storeForcedInclusion_invalidSummary() public {
        vm.deal(Alice, 1 ether);

        // Don't set mockInbox batch id, it defaults to 1
        // Create a summary with wrong nextBatchId
        IInbox.Summary memory invalidSummary = _createSummary(200);
        uint256 fee = store.feeInGwei() * 1 gwei;
        
        vm.prank(Alice);
        vm.expectRevert(bytes("Invalid summary"));
        store.storeForcedInclusion{ value: fee }(
            DEFAULT_BLOB_INDEX,
            DEFAULT_BLOB_OFFSET,
            DEFAULT_BLOB_SIZE,
            invalidSummary
        );
    }
}
