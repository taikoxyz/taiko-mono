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
    address public remoteOwner;
    address public owner;

    Multicall3 public multicall;
    DefaultResolver public resolver;
    SignalService public signalService;
    Bridge public bridge;
    DelegateOwner public delegateOwner;

    uint64 remoteChainId = uint64(block.chainid + 1);
    address remoteBridge = vm.addr(0x2000);

    function setUp() public {
        remoteOwner = vm.addr(0x2000);
        owner = vm.addr(0x1000);
        vm.deal(owner, 100 ether);

        vm.startPrank(owner);

        multicall = new Multicall3();
        resolver = deployDefaultResolver();
        delegateOwner = deployDelegateOwner(resolver, remoteOwner, remoteChainId);
        signalService = deploySignalService(resolver, address(new SignalServiceNoProofCheck()));
        bridge = deployBridge(resolver, address(new Bridge()));
        resolver.setAddress(remoteChainId, "bridge", remoteBridge);
        vm.stopPrank();
    }

    function test_delegate_owner_single_non_delegatecall() public {
        Target target1 = _deployTarget("target1", address(new Target()));

        bytes memory data = abi.encode(
            DelegateOwner.Call(
                uint64(0),
                address(target1),
                false, // CALL
                abi.encodeCall(EssentialContract.pause, ())
            )
        );

        vm.expectRevert(DelegateOwner.DO_DRYRUN_SUCCEEDED.selector);
        delegateOwner.dryrunInvocation(data);

        IBridge.Message memory message;
        message.from = remoteOwner;
        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (data));
        message.to = address(delegateOwner);

        vm.prank(Bob);
        bridge.processMessage(message, "");

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(delegateOwner.nextTxId(), 1);
        assertTrue(target1.paused());
    }

    function test_delegate_owner_single_non_delegatecall_self() public {
        address delegateOwnerImpl2 = address(new DelegateOwner());

        bytes memory data = abi.encode(
            DelegateOwner.Call(
                uint64(0),
                address(delegateOwner),
                false, // CALL
                abi.encodeCall(UUPSUpgradeable.upgradeTo, (delegateOwnerImpl2))
            )
        );

        vm.expectRevert(DelegateOwner.DO_DRYRUN_SUCCEEDED.selector);
        delegateOwner.dryrunInvocation(data);

        IBridge.Message memory message;
        message.from = remoteOwner;
        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (data));
        message.to = address(delegateOwner);

        vm.prank(Bob);
        bridge.processMessage(message, "");

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(delegateOwner.nextTxId(), 1);
        assertEq(delegateOwner.impl(), delegateOwnerImpl2);
    }

    function test_delegate_owner_delegate_multicall() public {
        address delegateOwnerImpl2 = address(new DelegateOwner());
        address impl1 = address(new Target());
        address impl2 = address(new Target());
        Target target1 = _deployTarget("target1", impl1);
        Target target2 = _deployTarget("target2", impl2);

        Multicall3.Call3[] memory calls = new Multicall3.Call3[](4);
        calls[0].target = address(target1);
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(EssentialContract.pause, ());

        calls[1].target = address(target2);
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (impl2));

        calls[2].target = address(delegateOwner);
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (delegateOwnerImpl2));

        calls[3].target = address(delegateOwner);
        calls[3].allowFailure = false;
        calls[3].callData = abi.encodeCall(DelegateOwner.setAdmin, (David));

        bytes memory data = abi.encode(
            DelegateOwner.Call(
                uint64(0),
                address(multicall),
                true, // DELEGATECALL
                abi.encodeCall(Multicall3.aggregate3, (calls))
            )
        );

        vm.expectRevert(DelegateOwner.DO_DRYRUN_SUCCEEDED.selector);
        delegateOwner.dryrunInvocation(data);

        IBridge.Message memory message;
        message.from = remoteOwner;
        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;
        message.destOwner = Bob;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (data));
        message.to = address(delegateOwner);

        vm.prank(Bob);
        bridge.processMessage(message, "");

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(delegateOwner.nextTxId(), 1);
        assertTrue(target1.paused());
        assertEq(target2.impl(), impl2);
        assertEq(delegateOwner.impl(), delegateOwnerImpl2);
        assertEq(delegateOwner.admin(), David);
    }

    function _deployTarget(bytes32 name, address impl) private returns (Target) {
        return Target(
            deploy({
                name: name,
                impl: impl,
                data: abi.encodeCall(Target.init, (address(delegateOwner)))
            })
        );
    }
}
