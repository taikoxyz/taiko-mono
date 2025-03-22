// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../Layer1Test.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "../mocks/MockBeaconBlockRoot.sol";

contract TestPreconfWhitelist is Layer1Test {
    PreconfWhitelist internal whitelist;
    PreconfWhitelist internal whitelistNoDelay;
    address internal whitelistOwner;
    BeaconBlockRootImpl internal beaconBlockRootImpl;

    function setUpOnEthereum() internal virtual override {
        whitelistOwner = Alice;
        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 2))
            })
        );

        whitelistNoDelay = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist_nodelay",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 0))
            })
        );

        vm.warp(LibPreconfConstants.SECONDS_IN_SLOT + LibPreconfConstants.SECONDS_IN_EPOCH);
    }

    function test_whitelist_delay2epoch_addThenRemoveOneOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelist.operators(Bob);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        // Verify operator for current epoch
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        whitelist.consolidate();
        assertEq(whitelist.havingPerfectOperators(), true);

        vm.prank(whitelistOwner);
        whitelist.removeOperator(Bob);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        (activeSince, inactiveSince, index) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 0);

        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 0);
        assertEq(whitelist.operatorMapping(0), address(0));
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_delay2epoch_addThenRemoveTwoOperators() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        vm.prank(whitelistOwner);
        whitelist.addOperator(Alice);
        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob);

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelist.operators(Alice);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        (activeSince, inactiveSince, index) = whitelist.operators(Bob);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 1);

        // Verify operator for current epoch
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        vm.prank(whitelistOwner);
        whitelist.removeOperator(Alice);
        vm.prank(whitelistOwner);
        whitelist.removeOperator(Bob);

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        (activeSince, inactiveSince, index) = whitelist.operators(Alice);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 0);

        (activeSince, inactiveSince, index) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 1);

        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 0);
        assertEq(whitelist.operatorMapping(0), address(0));
        assertEq(whitelist.operatorMapping(1), address(0));
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_addOrRemoveTheSameOperatorTwiceWillRevert() external {
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice);
        vm.expectRevert(IPreconfWhitelist.OperatorAlreadyExists.selector);
        whitelist.addOperator(Alice);

        whitelist.removeOperator(Alice);
        vm.expectRevert(IPreconfWhitelist.OperatorAlreadyRemoved.selector);
        whitelist.removeOperator(Alice);
        vm.stopPrank();
    }

    function test_whitelist_addBackRemovedOperator() external {
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice);

        whitelist.removeOperator(Alice);

        whitelist.addOperator(Alice);
        vm.stopPrank();
    }

    function test_whitelist_selfRemoval() external {
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice);
        whitelist.addOperator(Bob);
        vm.stopPrank();

        vm.prank(Alice);
        whitelist.removeSelf();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        vm.prank(Bob);
        whitelist.removeSelf();

        assertEq(whitelist.operatorCount(), 0);

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 0);
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_removeNonExistingOperatorWillRevert() external {
        vm.startPrank(whitelistOwner);
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorAddress.selector);
        whitelist.removeOperator(Alice);
        vm.stopPrank();
    }

    function test_whitelist_consolidate_whenEmpty_not_revert() external {
        whitelist.consolidate();
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_noDelay_addThenRemoveOneOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        vm.prank(whitelistOwner);
        whitelistNoDelay.addOperator(Bob);

        assertEq(whitelistNoDelay.operatorCount(), 1);
        assertEq(whitelistNoDelay.operatorMapping(0), Bob);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelistNoDelay.operators(Bob);
        assertEq(activeSince, whitelistNoDelay.epochStartTimestamp(0));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        assertEq(whitelistNoDelay.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelistNoDelay.getOperatorForNextEpoch(), Bob);

        vm.prank(whitelistOwner);
        whitelistNoDelay.removeOperator(Bob);

        assertEq(whitelistNoDelay.operatorCount(), 0);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        whitelistNoDelay.consolidate();
        assertEq(whitelistNoDelay.operatorCount(), 0);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        assertEq(whitelistNoDelay.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelistNoDelay.getOperatorForNextEpoch(), address(0));
    }

    function test_whitelistNoDelay_consolidationPreservesOrder() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        vm.startPrank(whitelistOwner);
        whitelistNoDelay.addOperator(Alice);
        whitelistNoDelay.addOperator(Bob);
        whitelistNoDelay.addOperator(Carol);

        address[] memory candidates = whitelistNoDelay.getOperatorCandidatesForCurrentEpoch();
        assertEq(candidates.length, 3);
        assertEq(candidates[0], Alice);
        assertEq(candidates[1], Bob);
        assertEq(candidates[2], Carol);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        whitelistNoDelay.removeOperator(Alice);
        assertEq(whitelistNoDelay.havingPerfectOperators(), false);

        whitelistNoDelay.consolidate();
        candidates = whitelistNoDelay.getOperatorCandidatesForCurrentEpoch();
        assertEq(candidates.length, 2);
        assertEq(candidates[0], Bob);
        assertEq(candidates[1], Carol);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        vm.stopPrank();
    }

    function test_whitelistNoDelay_consolidationWillNotChangeCurrentEpochOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(5)));

        vm.startPrank(whitelistOwner);
        whitelistNoDelay.addOperator(Alice);
        whitelistNoDelay.addOperator(Bob);
        whitelistNoDelay.addOperator(Carol);
        whitelistNoDelay.addOperator(David);
        whitelistNoDelay.removeOperator(Alice);
        assertEq(whitelistNoDelay.havingPerfectOperators(), false);

        address operatorBeforeConsolidate = whitelistNoDelay.getOperatorForCurrentEpoch();

        whitelistNoDelay.consolidate();

        address operatorAfterConsolidate = whitelistNoDelay.getOperatorForCurrentEpoch();
        assertEq(operatorBeforeConsolidate, operatorAfterConsolidate);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        vm.stopPrank();
    }

    function _setBeaconBlockRoot(bytes32 _root) internal {
        vm.etch(
            LibPreconfConstants.getBeaconBlockRootContract(),
            address(new BeaconBlockRootImpl(_root)).code
        );
    }

    function _advanceOneEpoch() internal {
        vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
    }
}

contract BeaconBlockRootImpl {
    bytes32 private immutable root;

    constructor(bytes32 _root) {
        root = _root;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(input.length == 32, "Invalid calldata length");
        uint256 _timestamp;
        assembly {
            _timestamp := calldataload(0)
        }
        return abi.encode(root);
    }
}
