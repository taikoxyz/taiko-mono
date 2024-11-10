// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

contract TestBridge2_sendMessage is TestBridge2Base {
    function test_bridge2_sendMessage_invalid_message()
        public
        transactBy(Carol)
        assertSameTotalBalance
    {
        // init an all-zero message
        IBridge.Message memory message;

        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        eBridge.sendMessage(message);

        message.srcOwner = Alice;
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        eBridge.sendMessage(message);

        message.destOwner = Bob;
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.sendMessage(message);

        message.destChainId = taikoChainId + 1;
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.sendMessage(message);

        message.destChainId = ethereumChainId;
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.sendMessage(message);

        // an bridge has been registered for destChainId
        message.destChainId = taikoChainId;
        eBridge.sendMessage(message); // id = 0

        message.value = 10_000_000;
        message.gasLimit = 20_000_000;
        message.fee = 30_000_000;
        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);

        message.data = "hello";
        eBridge.sendMessage(message);

        (bytes32 mhash, IBridge.Message memory m) =
            eBridge.sendMessage{ value: 40_000_000 }(message);
        assertEq(m.id, 1);
        assertEq(m.srcOwner, Alice); // Not Carol
        assertEq(m.srcChainId, ethereumChainId);
        assertEq(mhash, eBridge.hashMessage(m));

        m.id = 0;
        m.from = address(0);
        m.srcChainId = 0;
        assertEq(keccak256(abi.encode(message)), keccak256(abi.encode(m)));

        (bytes32 mhash2, IBridge.Message memory m2) =
            eBridge.sendMessage{ value: 40_000_000 }(message);

        assertEq(m2.id, 2);
        assertTrue(mhash2 != mhash);
    }

    function test_bridge2_sendMessage_invocationGasLimit()
        public
        transactBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.fee = 1;
        vm.expectRevert(Bridge.B_INVALID_FEE.selector);
        eBridge.sendMessage(message);

        uint32 minGasLimit = eBridge.getMessageMinGasLimit(message.data.length);
        console2.log("minGasLimit:", minGasLimit);

        message.gasLimit = minGasLimit - 1;
        vm.expectRevert(Bridge.B_INVALID_GAS_LIMIT.selector);
        eBridge.sendMessage(message);

        message.gasLimit = minGasLimit;
        vm.expectRevert(Bridge.B_INVALID_GAS_LIMIT.selector);
        eBridge.sendMessage(message);

        message.gasLimit = minGasLimit + 1;
        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);
        eBridge.sendMessage(message);

        eBridge.sendMessage{ value: message.fee }(message);

        message.fee = 0;
        eBridge.sendMessage(message);
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
        eBridge.sendMessage(message);

        vm.prank(deployer);
        resolver.setAddress(ethereumChainId, "signal_service", address(0));

        vm.prank(Alice);
        vm.expectRevert();
        eBridge.sendMessage(message);
    }
}
