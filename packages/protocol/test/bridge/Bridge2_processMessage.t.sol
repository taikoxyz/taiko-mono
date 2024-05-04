// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./Bridge2.t.sol";

contract BridgeTest2_processMessage is BridgeTest2 {
    function test_bridge2_processMessage_basic() public {
        vm.deal(Alice, 100 ether);

        IBridge.Message memory message;

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        vm.prank(Alice);
        bridge.processMessage(message, fakeProof);

        // message.destChainId = uint64(block.chainid);
        // vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        // vm.prank(Alice);
        // bridge.processMessage(message, fakeProof);

        // message.gasLimit = 1_000_000;
        // vm.expectRevert(); // RESOLVER_ZERO_ADDR src bridge not registered
        // vm.prank(Alice);
        // bridge.processMessage(message, fakeProof);

        // message.srcChainId = remoteChainId;
        // address srcBridge = vm.addr(0x2000);

        // vm.prank(owner);
        // addressManager.setAddress(remoteChainId, "bridge", srcBridge);

        // vm.prank(Alice);
        // bridge.processMessage(message, fakeProof);
    }
}
