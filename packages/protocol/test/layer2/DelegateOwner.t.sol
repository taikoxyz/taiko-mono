// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../shared/thirdparty/Multicall3.sol";
import "./TaikoL2Test.sol";

contract Target is EssentialContract {
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }
}

contract TestDelegateOwner is TaikoL2Test {
    // Contracts on Ethereum
    address public eBridge = randAddress();

    // Contracts on Taiko
    Multicall3 public tMulticall;
    SignalService public tSignalService;
    Bridge public tBridge;
    DelegateOwner public tDelegateOwner;

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
        Target tkoTarget1 = _deployTarget("tkoTarget1", address(new Target()));
        vm.stopPrank();

        bytes memory data = abi.encode(
            DelegateOwner.Call(
                uint64(0),
                address(tkoTarget1),
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
        assertTrue(tkoTarget1.paused());
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
        address impl1 = address(new Target());
        address impl2 = address(new Target());

        vm.startPrank(deployer);
        Target tkoTarget1 = _deployTarget("tkoTarget1", impl1);
        Target tTarget2 = _deployTarget("tTarget2", impl2);
        vm.stopPrank();

        Multicall3.Call3[] memory calls = new Multicall3.Call3[](4);
        calls[0].target = address(tkoTarget1);
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(EssentialContract.pause, ());

        calls[1].target = address(tTarget2);
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
        assertTrue(tkoTarget1.paused());
        assertEq(tTarget2.impl(), impl2);
        assertEq(tDelegateOwner.impl(), tDelegateOwnerImpl2);
        assertEq(tDelegateOwner.admin(), David);
    }

    function _deployTarget(bytes32 name, address impl) private returns (Target) {
        return Target(
            deploy({
                name: name,
                impl: impl,
                data: abi.encodeCall(Target.init, (address(tDelegateOwner)))
            })
        );
    }
}
