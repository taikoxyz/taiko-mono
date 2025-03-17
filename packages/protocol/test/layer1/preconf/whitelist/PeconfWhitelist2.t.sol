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
    }

    function test_whitelist2_addOperator() external {
        vm.warp(LibPreconfConstants.SECONDS_IN_SLOT + LibPreconfConstants.SECONDS_IN_EPOCH);

        _setBeaconBlockRoot(bytes32(uint256(1)));
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

        vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);
    }

    function _setBeaconBlockRoot(bytes32 _root) internal {
        vm.etch(
            LibPreconfConstants.getBeaconBlockRootContract(),
            address(new BeaconBlockRootImpl(_root)).code
        );
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
