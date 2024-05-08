// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestDelegateOwner is TaikoTest {
    function test_delegate_owner() public {
        // // Needs a compatible impl. contract
        // address newDelegateOwnerImp = address(new DelegateOwner());
        // bytes memory upgradeCall = abi.encodeCall(UUPSUpgradeable.upgradeTo,
        // (newDelegateOwnerImp));

        // IBridge.Message memory message = getDelegateOwnerMessage(
        //     address(mockDAO),
        //     abi.encodeCall(
        //         DelegateOwner.onMessageInvocation,
        //         abi.encode(0, address(delegateOwner), false, upgradeCall)
        //     )
        // );

        // // Mocking proof - but obviously it needs to be created in prod
        // // corresponding to the message
        // bytes memory proof = hex"00";

        // bytes32 msgHash = destChainBridge.hashMessage(message);

        // vm.chainId(destChainId);

        // vm.prank(Bob, Bob);
        // destChainBridge.processMessage(message, proof);

        // //Status is DONE,means a proper call
        // IBridge.Status status = destChainBridge.messageStatus(msgHash);
        // assertEq(status == IBridge.Status.DONE, true);
    }
}
