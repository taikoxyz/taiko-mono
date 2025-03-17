// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../Layer1Test.sol";
import "src/layer1/preconf/impl/PreconfWhitelist2.sol";
import "../mocks/MockBeaconBlockRoot.sol";

contract TestPreconfWhitelist2 is Layer1Test {
    PreconfWhitelist2 internal whitelist;
    address internal whitelistOwner;

    function setUpOnEthereum() internal virtual override {
        whitelistOwner = Alice;
        whitelist = PreconfWhitelist2(
            deploy({
                name: "preconf_whitelist2",
                impl: address(new PreconfWhitelist2(address(resolver))),
                data: abi.encodeCall(PreconfWhitelist2.init, (whitelistOwner))
            })
        );
    }

    function test_whitelist2_addOperator() external {
        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);

        (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelist.operators(Bob);
        assertEq(activeSince, whitelist.epochTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        // Verify operator for current epoch
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        uint256 timestamp = block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        vm.warp(timestamp);
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        timestamp += LibPreconfConstants.SECONDS_IN_EPOCH;
        vm.warp(timestamp);
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);
    }
}
