// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./WhitelistTestBase.sol";
import "../mocks/MockBeaconBlockRoot.sol";

contract WhitelistTest is WhitelistTestBase {
    function test_addOperator() external {
        address operator = Bob;

        vm.prank(whitelistOwner);
        whitelist.addOperator(operator);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorIndexToOperator(0), operator);
        assertEq(whitelist.isOperator(operator), true);
    }

    function test_addOperator_onlyOwner() external {
        address operator = Bob;

        vm.expectRevert();
        vm.prank(Bob);
        whitelist.addOperator(operator);
    }

    function test_addOperator_invalidAddress() external {
        vm.prank(whitelistOwner);
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorAddress.selector);
        whitelist.addOperator(address(0));
    }

    function test_addOperator_alreadyAdded() external {
        address operator = Bob;

        vm.startPrank(whitelistOwner);
        whitelist.addOperator(operator);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorIndexToOperator(0), operator);
        assertEq(whitelist.isOperator(operator), true);

        vm.expectRevert(IPreconfWhitelist.OperatorAlreadyExists.selector);
        whitelist.addOperator(operator);

        vm.stopPrank();
    }

    function test_removeOperator() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;

        addOperators(operators);

        vm.startPrank(whitelistOwner);

        whitelist.removeOperator(1);

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorIndexToOperator(0), Bob);
        assertEq(whitelist.operatorIndexToOperator(1), David);
        assertEq(whitelist.isOperator(Carol), false);

        vm.stopPrank();
    }

    function test_removeOperator_onlyOwner() external {
        address[] memory operators = new address[](1);
        operators[0] = Bob;

        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob);

        vm.expectRevert();
        vm.prank(Bob);
        whitelist.removeOperator(0);
    }

    function test_removeOperator_invalidIndex() external {
        vm.startPrank(whitelistOwner);

        // Try to remove from empty list
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorIndex.selector);
        whitelist.removeOperator(0);

        // Add one operator
        whitelist.addOperator(Bob);

        // Try to remove with invalid index
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorIndex.selector);
        whitelist.removeOperator(1);

        vm.stopPrank();
    }

    function test_getOperatorForCurrentEpoch_immediateRoot() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;

        addOperators(operators);

        vm.chainId(1); // Use ethereum's beacon genesis
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        // Current epoch
        uint256 epochTwoStart = epochOneStart + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Warp to arbitrary slot in epoch 2
        vm.warp(epochTwoStart + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Setup mock beacon block root contract
        MockBeaconBlockRoot mockBeacon = new MockBeaconBlockRoot();
        bytes32 mockRoot = bytes32(uint256(1));

        // Replace the beacon contract address with our mock
        address beaconBlockRootContract = LibPreconfConstants.getBeaconBlockRootContract();
        vm.etch(beaconBlockRootContract, address(mockBeacon).code);

        // Set root for second slot in epoch one (immediate hit)
        MockBeaconBlockRoot(payable(beaconBlockRootContract)).set(
            epochOneStart + LibPreconfConstants.SECONDS_IN_SLOT, mockRoot
        );

        address selectedOperator = whitelist.getOperatorForCurrentEpoch();
        assertEq(selectedOperator, Carol);
    }

    function test_getOperatorForCurrentEpoch_iteratedRoot() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;

        addOperators(operators);

        vm.chainId(1); // Use ethereum's beacon genesis
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        // Current epoch
        uint256 epochTwoStart = epochOneStart + LibPreconfConstants.SECONDS_IN_EPOCH;

        // Warp to arbitrary slot in epoch 2
        vm.warp(epochTwoStart + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Setup mock beacon block root contract
        MockBeaconBlockRoot mockBeacon = new MockBeaconBlockRoot();
        bytes32 mockRoot = bytes32(uint256(1));

        // Replace the beacon contract address with our mock
        address beaconBlockRootContract = LibPreconfConstants.getBeaconBlockRootContract();
        vm.etch(beaconBlockRootContract, address(mockBeacon).code);

        // Set root after 3 slots in epoch one to simulate missed slots
        MockBeaconBlockRoot(payable(beaconBlockRootContract)).set(
            epochOneStart + LibPreconfConstants.SECONDS_IN_SLOT * 3, mockRoot
        );

        address selectedOperator = whitelist.getOperatorForCurrentEpoch();
        assertEq(selectedOperator, Carol);
    }

    function test_getOperatorForCurrentEpoch_emptyList() external {
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorCount.selector);
        whitelist.getOperatorForCurrentEpoch();
    }
}
