// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../shared/thirdparty/Multicall3.sol";
import "./Layer2Test.sol";

contract EmptyEssential is EssentialContract {
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }
}


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
        tMulticall = new Multicall3();
        tDelegateOwner = deployDelegateOwner(eBridge, ethereumChainId);
        tSignalService = deploySignalService(address(new SignalServiceNoProofCheck()));
        tBridge = deployBridge(address(new Bridge()));
    }

    function test_delegate_owner_single_non_delegatecall() public onTaiko {
        vm.startPrank(deployer);
        EmptyEssential stub1 = _deployEmptyEssential("stub1", address(new EmptyEssential()));
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
        address tDelegateOwnerImpl2 = address(new DelegateOwner());

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
        address tDelegateOwnerImpl2 = address(new DelegateOwner());
        address impl1 = address(new EmptyEssential());
        address impl2 = address(new EmptyEssential());

        vm.startPrank(deployer);
        EmptyEssential stub1 = _deployEmptyEssential("stub1", impl1);
        EmptyEssential stub2 = _deployEmptyEssential("stub2", impl2);
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

    function _deployEmptyEssential(bytes32 name, address impl) private returns (EmptyEssential) {
        return EmptyEssential(
            deploy({
                name: name,
                impl: impl,
                data: abi.encodeCall(EmptyEssential.init, (address(tDelegateOwner)))
            })
        );
    }
}
