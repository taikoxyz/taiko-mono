// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../Layer1Test.sol";
import "src/layer1/preconf/impl/PreconfWhitelist2.sol";
import "../mocks/MockBeaconBlockRoot.sol";

contract TestPreconfWhitelist2 is Layer1Test {
    PreconfWhitelist2 internal whitelist;
    address internal whitelistOwner;
    BeaconBlockRootImpl internal beaconBlockRootImpl;

    function setUpOnEthereum() internal virtual override {
        whitelistOwner = Alice;
        whitelist = PreconfWhitelist2(
            deploy({
                name: "preconf_whitelist2",
                impl: address(new PreconfWhitelist2(address(resolver))),
                data: abi.encodeCall(PreconfWhitelist2.init, (whitelistOwner))
            })
        );

        vm.warp(LibPreconfConstants.SECONDS_IN_SLOT + LibPreconfConstants.SECONDS_IN_EPOCH);
    }

    function test_whitelist2_addThenRemoveOneOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

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

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        vm.prank(whitelistOwner);
        whitelist.removeOperator(Bob);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);

        uint256 oldActiveSince = activeSince;
        (activeSince, inactiveSince, index) = whitelist.operators(Bob);
        assertEq(activeSince, oldActiveSince);
        assertEq(inactiveSince, whitelist.epochTimestamp(2));
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
    }

    function test_whitelist2_addThenRemoveTwoOperators() external {
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

        (uint64 activeSince, uint64 inactiveSince, uint8 index) = whitelist.operators(Alice);
        assertEq(activeSince, whitelist.epochTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        (activeSince, inactiveSince, index) = whitelist.operators(Bob);
        assertEq(activeSince, whitelist.epochTimestamp(2));
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

        vm.prank(whitelistOwner);
        whitelist.removeOperator(Alice);
        vm.prank(whitelistOwner);
        whitelist.removeOperator(Bob);

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);

        (activeSince, inactiveSince, index) = whitelist.operators(Alice);
        assertTrue(activeSince != 0);
        assertEq(inactiveSince, whitelist.epochTimestamp(2));
        assertEq(index, 0);

        (activeSince, inactiveSince, index) = whitelist.operators(Bob);
        assertTrue(activeSince != 0);
        assertEq(inactiveSince, whitelist.epochTimestamp(2));
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
