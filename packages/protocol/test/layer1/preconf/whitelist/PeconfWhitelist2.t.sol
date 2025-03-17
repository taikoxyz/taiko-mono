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

    function addOperators(address[] memory operators) internal {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.prank(whitelistOwner);
            whitelist.addOperator(operators[i]);
        }
    }

    function test_whitelist2_addOperator() external {
        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);

        (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelist.operators(Bob);
        assertEq(index, 0);
        assertEq(activeSince, whitelist.epochTimestamp(2));
        assertEq(inactiveSince, 0);

        // Verify operator for current epoch
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorCount.selector);
         whitelist.getOperatorForCurrentEpoch();
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorCount.selector);
        whitelist.getOperatorForNextEpoch();


        vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
         vm.expectRevert(IPreconfWhitelist.InvalidOperatorCount.selector);
         whitelist.getOperatorForCurrentEpoch();
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorCount.selector);
        whitelist.getOperatorForNextEpoch();

        //  vm.warp(block.timestamp +LibPreconfConstants.SECONDS_IN_EPOCH);
        //  assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        //  assertEq(whitelist.getOperatorForNextEpoch(), Bob);
    }
    

    function test_whitelist2_addOperator_onlyOwner() external {
        address operator = Bob;

        vm.expectRevert();
        vm.prank(Bob);
        whitelist.addOperator(operator);
    }

    function test_whitelist2_addOperator_invalidAddress() external {
        vm.prank(whitelistOwner);
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorAddress.selector);
        whitelist.addOperator(address(0));
    }

    function test_whitelist2_addOperator_alreadyAdded() external {
        address operator = Bob;

        vm.startPrank(whitelistOwner);
        whitelist.addOperator(operator);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), operator);
         (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelist.operators(operator);
        assertEq(activeSince, whitelist.epochTimestamp(2));

        vm.expectRevert(IPreconfWhitelist.OperatorAlreadyExists.selector);
        whitelist.addOperator(operator);

        vm.stopPrank();
    }

    function test_whitelist2_removeOperator() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;

        addOperators(operators);

        vm.prank(whitelistOwner);
        whitelist.removeOperator(0);

        assertEq(whitelist.operatorCount(), 3);
        (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelist.operators(Bob);
        assertEq(index, 0);
        assertEq(activeSince, whitelist.epochTimestamp(2));
        assertEq(inactiveSince, whitelist.epochTimestamp(3));
    }

    function test_whitelist2_addAndRemoveOperatorInOneTransaction() external {
        address operator = Bob;

        vm.startPrank(whitelistOwner);
        whitelist.addOperator(operator);
        whitelist.removeOperator(operator);
        vm.stopPrank();

        assertEq(whitelist.operatorCount(), 1);
        (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelist.operators(operator);
        assertEq(activeSince, whitelist.epochTimestamp(2));
        assertEq(inactiveSince, whitelist.epochTimestamp(2) + uint64(LibPreconfConstants.SECONDS_IN_EPOCH));
    }
}