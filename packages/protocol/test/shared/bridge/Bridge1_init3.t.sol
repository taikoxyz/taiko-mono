// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

contract Init3Target is IMessageInvocable {
    function onMessageInvocation(bytes calldata) external payable {
        revert("failed");
    }
}

contract TestBridge1_init3 is TestBridge2Base {
    function test_init3_InvalidatesRetriableMessagesAsDone() public dealEther(Alice) {
        IBridge.Message memory message = _retriableMessage();
        bytes32 msgHash = eBridge.hashMessage(message);

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);
        assertEq(uint8(eBridge.messageStatus(msgHash)), uint8(IBridge.Status.RETRIABLE));

        bytes32[] memory msgHashes = new bytes32[](1);
        msgHashes[0] = msgHash;

        vm.expectEmit(true, false, false, true, address(eBridge));
        emit IBridge.MessageStatusChanged(msgHash, IBridge.Status.DONE);

        vm.prank(deployer);
        eBridge.init3(msgHashes);

        assertEq(uint8(eBridge.messageStatus(msgHash)), uint8(IBridge.Status.DONE));

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        eBridge.retryMessage(message, false);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        eBridge.failMessage(message);
    }

    function test_init3_RevertWhen_CallerNotOwner() public {
        bytes32[] memory msgHashes = new bytes32[](1);
        msgHashes[0] = keccak256("msgHash");

        vm.expectRevert();
        vm.prank(Alice);
        eBridge.init3(msgHashes);
    }

    function test_init3_RevertWhen_EmptyMessageList() public {
        vm.expectRevert(Bridge.B_INVALID_VALUE.selector);
        vm.prank(deployer);
        eBridge.init3(new bytes32[](0));
    }

    function test_init3_MarksNewMessageAsDone() public {
        bytes32[] memory msgHashes = new bytes32[](1);
        msgHashes[0] = keccak256("msgHash");

        assertEq(uint8(eBridge.messageStatus(msgHashes[0])), uint8(IBridge.Status.NEW));

        vm.expectEmit(true, false, false, true, address(eBridge));
        emit IBridge.MessageStatusChanged(msgHashes[0], IBridge.Status.DONE);

        vm.prank(deployer);
        eBridge.init3(msgHashes);

        assertEq(uint8(eBridge.messageStatus(msgHashes[0])), uint8(IBridge.Status.DONE));
    }

    function test_init3_RevertWhen_CalledTwice() public dealEther(Alice) {
        IBridge.Message memory message = _retriableMessage();
        bytes32 msgHash = eBridge.hashMessage(message);

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);

        bytes32[] memory msgHashes = new bytes32[](1);
        msgHashes[0] = msgHash;

        vm.prank(deployer);
        eBridge.init3(msgHashes);

        vm.expectRevert();
        vm.prank(deployer);
        eBridge.init3(new bytes32[](0));
    }

    function _retriableMessage() private returns (IBridge.Message memory message_) {
        Init3Target target = new Init3Target();

        message_ = IBridge.Message({
            id: 0,
            from: address(uint160(uint256(keccak256("remote_bridge")))),
            srcChainId: taikoChainId,
            destChainId: ethereumChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: address(target),
            value: 0,
            fee: 0,
            gasLimit: 1_000_000,
            data: abi.encodeCall(Init3Target.onMessageInvocation, ("hello"))
        });
    }
}
