// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/helpers/EssentialContract_EmptyStub.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "test/layer2/Layer2Test.sol";

contract TestDelegateOwner is Layer2Test {
    // Contracts on Ethereum
    address private eBridge = randAddress();

    // Contracts on Taiko
    Multicall3 private tMulticall;
    SignalService private tSignalService;
    Bridge private tBridge;
    DelegateOwner private tDelegateOwner;

    function setUpOnEthereum() internal override {
        register("bridge", eBridge);
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalService(
            address(new SignalService_WithoutProofVerification(address(resolver)))
        );
        tBridge = deployBridge(address(new Bridge(address(resolver), address(tSignalService))));
        tMulticall = new Multicall3();
        tDelegateOwner = deployDelegateOwner(eBridge, ethereumChainId, address(tBridge));
    }

    function test_delegate_owner_single_non_delegatecall() public onTaiko {
        vm.startPrank(deployer);
        EssentialContract_EmptyStub stub1 =
            _deployEssentialContract_EmptyStub("stub1", address(new EssentialContract_EmptyStub()));
        vm.stopPrank();

        bytes memory data = abi.encode(
            DelegateOwner.Call(
                uint64(0),
                address(stub1),
                false, // CALL
                abi.encodeCall(EssentialContract.pause, ())
            )
        );

        vm.expectRevert(DelegateOwner.DO_DRYRUN_SUCCEEDED.selector);
        tDelegateOwner.dryrunInvocation(data);

        IBridge.Message memory message;
        message.from = eBridge;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (data));
        message.to = address(tDelegateOwner);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        bytes32 hash = tBridge.hashMessage(message);
        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(tDelegateOwner.nextTxId(), 1);
        assertTrue(stub1.paused());
    }

    function test_delegate_owner_single_non_delegatecall_self() public onTaiko {
        address tDelegateOwnerImpl2 = address(new DelegateOwner(address(tBridge)));

        bytes memory data = abi.encode(
            DelegateOwner.Call(
                uint64(0),
                address(tDelegateOwner),
                false, // CALL
                abi.encodeCall(UUPSUpgradeable.upgradeTo, (tDelegateOwnerImpl2))
            )
        );

        vm.expectRevert(DelegateOwner.DO_DRYRUN_SUCCEEDED.selector);
        tDelegateOwner.dryrunInvocation(data);

        IBridge.Message memory message;
        message.from = eBridge;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (data));
        message.to = address(tDelegateOwner);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        bytes32 hash = tBridge.hashMessage(message);
        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(tDelegateOwner.nextTxId(), 1);
        assertEq(tDelegateOwner.impl(), tDelegateOwnerImpl2);
    }

    function test_delegate_owner_delegate_tMulticall() public onTaiko {
        address tDelegateOwnerImpl2 = address(new DelegateOwner(address(tBridge)));
        address impl1 = address(new EssentialContract_EmptyStub());
        address impl2 = address(new EssentialContract_EmptyStub());

        vm.startPrank(deployer);
        EssentialContract_EmptyStub stub1 = _deployEssentialContract_EmptyStub("stub1", impl1);
        EssentialContract_EmptyStub stub2 = _deployEssentialContract_EmptyStub("stub2", impl2);
        vm.stopPrank();

        Multicall3.Call3[] memory calls = new Multicall3.Call3[](4);
        calls[0].target = address(stub1);
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(EssentialContract.pause, ());

        calls[1].target = address(stub2);
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (impl2));

        calls[2].target = address(tDelegateOwner);
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (tDelegateOwnerImpl2));

        calls[3].target = address(tDelegateOwner);
        calls[3].allowFailure = false;
        calls[3].callData = abi.encodeCall(DelegateOwner.setAdmin, (David));

        bytes memory data = abi.encode(
            DelegateOwner.Call(
                uint64(0),
                address(tMulticall),
                true, // DELEGATECALL
                abi.encodeCall(Multicall3.aggregate3, (calls))
            )
        );

        vm.expectRevert(DelegateOwner.DO_DRYRUN_SUCCEEDED.selector);
        tDelegateOwner.dryrunInvocation(data);

        IBridge.Message memory message;
        message.from = eBridge;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (data));
        message.to = address(tDelegateOwner);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        bytes32 hash = tBridge.hashMessage(message);
        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(tDelegateOwner.nextTxId(), 1);
        assertTrue(stub1.paused());
        assertEq(stub2.impl(), impl2);
        assertEq(tDelegateOwner.impl(), tDelegateOwnerImpl2);
        assertEq(tDelegateOwner.admin(), David);
    }

    function _deployEssentialContract_EmptyStub(
        bytes32 name,
        address impl
    )
        private
        returns (EssentialContract_EmptyStub)
    {
        return EssentialContract_EmptyStub(
            deploy({
                name: name,
                impl: impl,
                data: abi.encodeCall(EssentialContract_EmptyStub.init, (address(tDelegateOwner)))
            })
        );
    }
}
