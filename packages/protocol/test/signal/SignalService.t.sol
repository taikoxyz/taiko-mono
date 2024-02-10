// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestSignalService is TaikoTest {
    AddressManager addressManager;
    SignalService relayer;
    SignalService destSignalService;
    DummyCrossChainSync crossChainSync;
    uint64 public destChainId = 7;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);

        addressManager = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, ()),
                registerTo: address(addressManager),
                owner: address(0)
            })
        );

        relayer = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, ())
            })
        );

        destSignalService = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, ())
            })
        );

        crossChainSync = DummyCrossChainSync(
            deployProxy({
                name: "dummy_cross_chain_sync",
                impl: address(new DummyCrossChainSync()),
                data: ""
            })
        );

        register(address(addressManager), "signal_service", address(destSignalService), destChainId);

        register(address(addressManager), "taiko", address(crossChainSync), destChainId);

        vm.stopPrank();
    }

    function test_SignalService_sendSignal_revert() public {
        vm.expectRevert(SignalService.SS_INVALID_SIGNAL.selector);
        relayer.sendSignal(0);
    }

    function test_SignalService_isSignalSent_revert() public {
        bytes32 signal = bytes32(uint256(1));
        vm.expectRevert(SignalService.SS_INVALID_APP.selector);
        relayer.isSignalSent(address(0), signal);

        signal = bytes32(uint256(0));
        vm.expectRevert(SignalService.SS_INVALID_SIGNAL.selector);
        relayer.isSignalSent(Alice, signal);
    }

    function test_SignalService_sendSignal_isSignalSent() public {
        vm.startPrank(Alice);
        bytes32 signal = bytes32(uint256(1));
        relayer.sendSignal(signal);

        assertTrue(relayer.isSignalSent(Alice, signal));
    }

    function test_SignalService_getSignalSlot() public {
        vm.startPrank(Alice);
        for (uint8 i = 1; i < 100; ++i) {
            bytes32 signal = bytes32(block.prevrandao + i);
            relayer.sendSignal(signal);

            assertTrue(relayer.isSignalSent(Alice, signal));
        }
    }
}
