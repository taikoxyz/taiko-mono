// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "src/layer1/based/ForcedInclusionStore.sol";

abstract contract ForcedInclusionStoreTestBase is Layer1Test {
    ForcedInclusionStore internal store;
    address internal storeOwner;
    address internal operator;

    uint256 inclusionWindow;
    uint256 basePriorityFee;

    function setUpOnEthereum() internal virtual override {
        storeOwner = Alice;
        operator = Alice;
        inclusionWindow = 10;
        basePriorityFee = 100;

        vm.chainId(1);


        resolver.registerAddress(block.chainid, "taiko_forced_inclusion_inbox", operator);
        store = ForcedInclusionStore(
            deploy({
                name: "forced_inclusion_store",
                impl: address(new ForcedInclusionStore(address(resolver), inclusionWindow, basePriorityFee)),
                data: abi.encodeCall(ForcedInclusionStore.init, (storeOwner))
            })
        );
    }
}
