// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../shared/CommonTest.sol";
import "src/layer1/based/ForcedInclusionStore.sol";

contract ForcedInclusionStoreForTest is ForcedInclusionStore {
    constructor(
        address _resolver,
        uint256 _inclusionDelay,
        uint256 _fee
    )
        ForcedInclusionStore(_resolver, _inclusionDelay, _fee)
    { }

    function _blobHash(uint8 blobIndex) internal view virtual override returns (bytes32) {
        return bytes32(uint256(blobIndex + 1));
    }
}

abstract contract ForcedInclusionStoreTestBase is CommonTest {
    address internal storeOwner = Alice;
    address internal operator = Alice;
    uint64 internal constant inclusionDelay = 24 seconds;
    uint256 internal constant fee = 0.001 ether;

    ForcedInclusionStore internal store;

    function setUpOnEthereum() internal virtual override {
        register(LibStrings.B_TAIKO_FORCED_INCLUSION_INBOX, operator);

        store = ForcedInclusionStore(
            deploy({
                name: LibStrings.B_FORCED_INCLUSION_STORE,
                impl: address(new ForcedInclusionStoreForTest(address(resolver), inclusionDelay, fee)),
                data: abi.encodeCall(ForcedInclusionStore.init, (storeOwner))
            })
        );
    }
}

contract ForcedInclusionStoreTest is ForcedInclusionStoreTestBase {
    function test_storeForcedInclusion_success() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        uint256 _fee = store.fee();

        for (uint8 i; i < 5; ++i) {
            store.storeForcedInclusion{ value: _fee }({
                blobIndex: i,
                blobByteOffset: 0,
                blobByteSize: 1024
            });
            (
                bytes32 blobHash,
                uint256 fee,
                uint64 createdAt,
                uint32 blobByteOffset,
                uint32 blobByteSize
            ) = store.queue(store.tail() - 1);

            assertEq(blobHash, bytes32(uint256(i + 1))); //  = blobIndex + 1
            assertEq(createdAt, uint64(block.timestamp));
            assertEq(fee, _fee);
            assertEq(blobByteOffset, 0);
            assertEq(blobByteSize, 1024);
        }
    }

    function test_storeForcedInclusion_incorrectFee() public transactBy(Alice) {
        vm.deal(Alice, 1 ether);

        uint256 fee = store.fee();
        vm.expectRevert(IForcedInclusionStore.IncorrectFee.selector);
        store.storeForcedInclusion{ value: fee - 1 }({
            blobIndex: 0,
            blobByteOffset: 0,
            blobByteSize: 1024
        });

        vm.expectRevert(IForcedInclusionStore.IncorrectFee.selector);
        store.storeForcedInclusion{ value: fee + 1 }({
            blobIndex: 0,
            blobByteOffset: 0,
            blobByteSize: 1024
        });
    }

    function test_storeConsumeForcedInclusion_success() public {
        vm.deal(Alice, 1 ether);
        uint256 _fee = store.fee();

        vm.prank(Alice);
        store.storeForcedInclusion{ value: _fee }({
            blobIndex: 0,
            blobByteOffset: 0,
            blobByteSize: 1024
        });

        assertEq(store.head(), 0);
        assertEq(store.tail(), 1);

        uint256 createdAt = block.timestamp;
        vm.warp(createdAt + inclusionDelay);

        vm.prank(operator);
        IForcedInclusionStore.ForcedInclusion memory consumed = store.consumeForcedInclusion(Bob);

        assertEq(consumed.blobHash, bytes32(uint256(1)));
        assertEq(consumed.blobByteOffset, 0);
        assertEq(consumed.blobByteSize, 1024);
        assertEq(consumed.fee, _fee);
        assertEq(consumed.createdAt, createdAt);
        assertEq(Bob.balance, _fee);
    }

    function test_storeConsumeForcedInclusion_notOperator() public {
        vm.deal(Alice, 1 ether);
        uint256 _fee = store.fee();

        vm.prank(Alice);
        store.storeForcedInclusion{ value: _fee }({
            blobIndex: 0,
            blobByteOffset: 0,
            blobByteSize: 1024
        });

        assertEq(store.head(), 0);
        assertEq(store.tail(), 1);

        vm.warp(block.timestamp + inclusionDelay);

        vm.prank(Carol);
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        store.consumeForcedInclusion(Bob);
    }

    function test_storeConsumeForcedInclusion_noEligibleInclusion() public {
        vm.prank(operator);
        IForcedInclusionStore.ForcedInclusion memory inclusion = store.consumeForcedInclusion(Bob);
        assertEq(inclusion.blobHash, bytes32(0));
        assertEq(inclusion.blobByteOffset, 0);
        assertEq(inclusion.blobByteSize, 0);
        assertEq(inclusion.fee, 0);
    }

    function test_storeConsumeForcedInclusion_beforeWindowExpires() public {
        vm.deal(Alice, 1 ether);

        vm.prank(operator);
        store.storeForcedInclusion{ value: store.fee() }({
            blobIndex: 0,
            blobByteOffset: 0,
            blobByteSize: 1024
        });

        vm.warp(block.timestamp + inclusionDelay - 1);
        vm.prank(operator);
        IForcedInclusionStore.ForcedInclusion memory inclusion = store.consumeForcedInclusion(Bob);
        assertEq(inclusion.blobHash, bytes32(0));
        assertEq(inclusion.blobByteOffset, 0);
        assertEq(inclusion.blobByteSize, 0);
        assertEq(inclusion.fee, 0);
    }
}
