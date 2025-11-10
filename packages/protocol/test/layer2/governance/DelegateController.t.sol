// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/layer2/Layer2Test.sol";
import "test/shared/helpers/EssentialContract_EmptyStub.sol";

contract TestDelegateController is Layer2Test {
    // Contracts on Ethereum
    address private daoController = randAddress();

    // Contracts on Taiko
    SignalService private tSignalService;
    Bridge private tBridge;
    DelegateController private tDelegateController;

    function setUpOnEthereum() internal override {
        register("bridge", daoController);
    }

    function setUpOnTaiko() internal override {
        tSignalService = _deployMockSignalService();
        tBridge = deployBridge(address(new Bridge(address(resolver), address(tSignalService))));
        tDelegateController =
            deployDelegateController(ethereumChainId, address(tBridge), daoController);
    }

    function test_delegate_controller_single_action() public onTaiko {
        vm.startPrank(deployer);
        EssentialContract_EmptyStub stub1 =
            _deployEssentialContract_EmptyStub("stub1", address(new EssentialContract_EmptyStub()));
        vm.stopPrank();

        Controller.Action[] memory actions = new Controller.Action[](1);
        actions[0] = Controller.Action({
            target: address(stub1), value: 0, data: abi.encodeCall(EssentialContract.pause, ())
        });

        vm.expectRevert(Controller.DryrunSucceeded.selector);
        tDelegateController.dryrun(abi.encode(actions));

        IBridge.Message memory message;
        message.from = daoController;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(
            DelegateController.onMessageInvocation,
            (abi.encodePacked(uint64(1), abi.encode(actions)))
        );
        message.to = address(tDelegateController);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        bytes32 hash = tBridge.hashMessage(message);
        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(tDelegateController.lastExecutionId(), 1);
        assertTrue(stub1.paused());
    }

    function test_delegate_controller_multiple_actions() public onTaiko {
        address tDelegateControllerImpl2 = address(
            new DelegateController(ethereumChainId, address(tBridge), address(tDelegateController))
        );
        address impl1 = address(new EssentialContract_EmptyStub());
        address impl2 = address(new EssentialContract_EmptyStub());

        vm.startPrank(deployer);
        EssentialContract_EmptyStub stub1 = _deployEssentialContract_EmptyStub("stub1", impl1);
        EssentialContract_EmptyStub stub2 = _deployEssentialContract_EmptyStub("stub2", impl2);
        vm.stopPrank();

        Controller.Action[] memory actions = new Controller.Action[](4);
        actions[0] = Controller.Action({
            target: address(stub1), value: 0, data: abi.encodeCall(EssentialContract.pause, ())
        });

        actions[1] = Controller.Action({
            target: address(stub2),
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (impl2))
        });

        actions[2] = Controller.Action({
            target: address(tDelegateController),
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (tDelegateControllerImpl2))
        });

        actions[3] = Controller.Action({
            target: Alice,
            value: 0.1 ether,
            data: abi.encodeCall(IERC20.transfer, (Alice, 0.1 ether))
        });

        vm.deal(address(tDelegateController), 0.1 ether);

        vm.expectRevert(Controller.DryrunSucceeded.selector);
        tDelegateController.dryrun(abi.encode(actions));

        IBridge.Message memory message;
        message.from = daoController;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(
            DelegateController.onMessageInvocation,
            (abi.encodePacked(uint64(1), abi.encode(actions)))
        );
        message.to = address(tDelegateController);

        vm.prank(Bob);
        tBridge.processMessage(message, "");

        bytes32 hash = tBridge.hashMessage(message);
        assertTrue(tBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(tDelegateController.lastExecutionId(), 1);
        assertTrue(stub1.paused());
        assertEq(stub2.impl(), impl2);
        assertEq(tDelegateController.impl(), tDelegateControllerImpl2);
        assertEq(Alice.balance, 0.1 ether);
        assertEq(address(tDelegateController).balance, 0);
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
                data: abi.encodeCall(
                    EssentialContract_EmptyStub.init, (address(tDelegateController))
                )
            })
        );
    }

    function _deployMockSignalService() private returns (SignalService) {
        return deploySignalServiceWithoutProof(
            address(this),
            address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_LAYER2")))),
            deployer
        );
    }
}
