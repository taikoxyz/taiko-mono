// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

contract OutOfQuotaManager is IQuotaManager {
    function consumeQuota(address, uint256) external pure {
        revert("out of quota");
    }
}

contract TestBridge2_processMessage is TestBridge2Base {
    function getQuotaManager() internal override returns (address) {
        return address(new OutOfQuotaManager());
    }

    function test_bridge2_processMessage__no_ether_quota()
        public
        dealEther(Bob)
        dealEther(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        vm.prank(Bob);
        vm.expectRevert(Bridge.B_OUT_OF_ETH_QUOTA.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        vm.prank(Alice);
        vm.expectRevert(Bridge.B_OUT_OF_ETH_QUOTA.selector);
        eBridge.processMessage(message, FAKE_PROOF);
    }

    function test_bridge2_processMessage_and_retryMessage_malicious_way()
        public
        dealEther(Bob)
        dealEther(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        bytes32 hashOfMaliciousMessage =
            0x3c6e0b8a9c15224b7f0a1e5f4c8f7683d5a0a4e32a34c6c7c7e1f4d9a9d9f6b4;
        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(eBridge);
        message.data = abi.encodeWithSignature("sendSignal(bytes32)", hashOfMaliciousMessage);

        vm.prank(Alice);
        vm.expectRevert(Bridge.B_OUT_OF_ETH_QUOTA.selector);
        eBridge.processMessage(message, FAKE_PROOF);
    }
}
