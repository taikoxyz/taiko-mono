// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Bridge2.t.sol";

contract BridgeTest2_sendMessage is BridgeTest2 {
    function test_bridge2_sendMessage_invalid_message()
        public
        transactedBy(Carol)
        assertSameTotalBalance
    {
        // init an all-zero message
        IBridge.Message memory message;

        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        bridge.sendMessage(message);

        message.srcOwner = Alice;
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        bridge.sendMessage(message);

        message.destOwner = Bob;
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.sendMessage(message);

        message.destChainId = taikoChainId + 1;
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.sendMessage(message);

        message.destChainId = ethereumChainId;
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.sendMessage(message);

        // an bridge has been registered for destChainId
        message.destChainId = taikoChainId;
        bridge.sendMessage(message); // id = 0

        message.value = 10_000_000;
        message.gasLimit = 20_000_000;
        message.fee = 30_000_000;
        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);

        message.data = "hello";
        bridge.sendMessage(message);

        (bytes32 mhash, IBridge.Message memory m) = bridge.sendMessage{ value: 40_000_000 }(message);
        assertEq(m.id, 1);
        assertEq(m.srcOwner, Alice); // Not Carol
        assertEq(m.srcChainId, ethereumChainId);
        assertEq(mhash, bridge.hashMessage(m));

        m.id = 0;
        m.from = address(0);
        m.srcChainId = 0;
        assertEq(keccak256(abi.encode(message)), keccak256(abi.encode(m)));

        (bytes32 mhash2, IBridge.Message memory m2) =
            bridge.sendMessage{ value: 40_000_000 }(message);

        assertEq(m2.id, 2);
        assertTrue(mhash2 != mhash);
    }

    function test_bridge2_sendMessage_invocationGasLimit()
        public
        transactedBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.fee = 1;
        vm.expectRevert(Bridge.B_INVALID_FEE.selector);
        bridge.sendMessage(message);

        uint32 minGasLimit = bridge.getMessageMinGasLimit(message.data.length);
        console2.log("minGasLimit:", minGasLimit);

        message.gasLimit = minGasLimit - 1;
        vm.expectRevert(Bridge.B_INVALID_GAS_LIMIT.selector);
        bridge.sendMessage(message);

        message.gasLimit = minGasLimit;
        vm.expectRevert(Bridge.B_INVALID_GAS_LIMIT.selector);
        bridge.sendMessage(message);

        message.gasLimit = minGasLimit + 1;
        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);
        bridge.sendMessage(message);

        bridge.sendMessage{ value: message.fee }(message);

        message.fee = 0;
        bridge.sendMessage(message);
    }

    function test_bridge2_sendMessage_missing_local_signal_service()
        public
        dealEther(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;

        vm.prank(Alice);
        bridge.sendMessage(message);

        vm.prank(deployer);
        resolver.setAddress(ethereumChainId, "signal_service", address(0));

        vm.prank(Alice);
        vm.expectRevert();
        bridge.sendMessage(message);
    }
}
