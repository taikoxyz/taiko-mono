// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/helpers/EssentialContract_EmptyStub.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "test/layer2/Layer2Test.sol";

contract TestDelegateController is Layer2Test {
    // Contracts on Ethereum
    address private daoController = randAddress();

    // Contracts on Taiko
    Multicall3 private tMulticall;
    SignalService private tSignalService;
    Bridge private tBridge;
    DelegateController private tDelegateController;

    function setUpOnEthereum() internal override {
        register("bridge", daoController);
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalService(
            address(new SignalService_WithoutProofVerification(address(resolver)))
        );
        tBridge = deployBridge(address(new Bridge(address(resolver), address(tSignalService))));
        tMulticall = new Multicall3();
        tDelegateController = deployDelegateController(ethereumChainId, address(tBridge), daoController);
    }

    function test_delegate_controller_single_non_delegatecall() public onTaiko {
        vm.startPrank(deployer);
        EssentialContract_EmptyStub stub1 =
            _deployEssentialContract_EmptyStub("stub1", address(new EssentialContract_EmptyStub()));
        vm.stopPrank();

        Controller.Action[] memory actions = new Controller.Action[](1);
        calls[0] = Controller.Action({
            target: address(stub1),
            value: 0,
            data: abi.encodeCall(EssentialContract.pause, ())
        });

        vm.expectRevert(Controller.DryrunSucceeded.selector);
        tDelegateController.dryrun(actions);

        IBridge.Message memory message;
        message.from = daoController;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateController.onMessageInvocation, (abi.encode(uint(1), actions)));
        message.to = address(tDelegateController);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        bytes32 hash = tBridge.hashMessage(message);
        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);

                    assertEq(tDelegateController.lastExecutionId(), 1);
        assertTrue(stub1.paused());
    }

    function test_delegate_owner_single_non_delegatecall_self() public onTaiko {
        address tDelegateOwnerImpl2 =
            address(new DelegateOwner(ethereumChainId, address(tBridge), address(tDelegateOwner)));

        Controller.Action[] memory actions = new Controller.Action[](1);
        calls[0] = Controller.Action({
            target: address(tDelegateOwner),
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (tDelegateOwnerImpl2))
        });


        vm.expectRevert(Controller.DryrunSucceeded.selector);
        tDelegateOwner.dryrun(calls);

        IBridge.Message memory message;
        message.from = daoController;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (abi.encode(uint64(1), actions)));
        message.to = address(tDelegateOwner);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        bytes32 hash = tBridge.hashMessage(message);
        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(tDelegate      Controller.lastExecutionId(), 1);
        assertEq(tDelegateController.impl(), tDelegateControllerImpl2);
    }

    function test_delegate_owner_delegate_tMulticall() public onTaiko {
        address tDelegateOwnerImpl2 =
            address(new DelegateOwner(ethereumChainId, address(tBridge), address(tDelegateOwner)));
        address impl1 = address(new EssentialContract_EmptyStub());
        address impl2 = address(new EssentialContract_EmptyStub());

        vm.startPrank(deployer);
        EssentialContract_EmptyStub stub1 = _deployEssentialContract_EmptyStub("stub1", impl1);
        EssentialContract_EmptyStub stub2 = _deployEssentialContract_EmptyStub("stub2", impl2);
        vm.stopPrank();

        Multicall3.Call3[] memory calls = new Multicall3.Call3[](3);
        calls[0].target = address(stub1);
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(EssentialContract.pause, ());

        calls[1].target = address(stub2);
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (impl2));

        calls[2].target = address(tDelegateOwner);
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (tDelegateOwnerImpl2));

        Controller.Action[] memory actions = new Controller.Action[](1);
        calls[0] = Controller.Action({
            target: address(tMulticall),
                value: 0,
            data: abi.encodeCall(Multicall3.aggregate3, (calls))
        });

        vm.expectRevert(Controller.DryrunSucceeded.selector);
        tDelegateOwner.dryrun(calls);

        IBridge.Message memory message;
        message.from = daoController;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (abi.encode(uint64(1), actions)));
        message.to = address(tDelegateOwner);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        bytes32 hash = tBridge.hashMessage(message);
        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(tDelegateOwner.txId(), 1);
        assertTrue(stub1.paused());
        assertEq(stub2.impl(), impl2);
        assertEq(tDelegateOwner.impl(), tDelegateOwnerImpl2);
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
