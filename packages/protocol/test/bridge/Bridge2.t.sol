// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract BridgeTest2 is TaikoTest {
    address public owner;
    uint64 public remoteChainId;
    address public remoteBridge;
    AddressManager public addressManager;
    SignalService public signalService;
    Bridge public bridge;

    modifier transactedBy(address addr) {
        vm.deal(addr, 100 ether);
        vm.startPrank(addr);

        _;
        vm.stopPrank();
    }

    function setUp() public {
        owner = vm.addr(0x1000);
        remoteChainId = uint64(block.chainid + 1);
        remoteBridge = vm.addr(0x2000);

        vm.startPrank(owner);
        vm.deal(owner, 100 ether);

        addressManager = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, (address(0)))
            })
        );

        signalService = SkipProofCheckSignal(
            deployProxy({
                name: "signal_service",
                impl: address(new SkipProofCheckSignal()),
                data: abi.encodeCall(SignalService.init, (address(0), address(addressManager))),
                registerTo: address(addressManager)
            })
        );

        bridge = Bridge(
            payable(
                deployProxy({
                    name: "bridge",
                    impl: address(new Bridge()),
                    data: abi.encodeCall(Bridge.init, (address(0), address(addressManager))),
                    registerTo: address(addressManager)
                })
            )
        );

        addressManager.setAddress(remoteChainId, "bridge", remoteBridge);
        vm.stopPrank();
    }
}
