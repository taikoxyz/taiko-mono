// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract BridgeTest2 is TaikoTest {
    AddressManager l1AddressManager;
    AddressManager l2AddressManager;

    SignalService l1SignalService;
    SignalService l2SignalService;

    Bridge l1Bridge;
    Bridge l2Bridge;

    uint64 l1ChainId = 100_001;
    uint64 l2ChainId = 100_002;

    function _deployContracts()
        private
        returns (AddressManager am, SignalService ss, Bridge bridge)
    {
        am = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, (address(0)))
            })
        );
        console2.log("address_manager:", block.chainid, address(am));

        ss = SkipProofCheckSignal(
            deployProxy({
                name: "signal_service",
                impl: address(new SkipProofCheckSignal()),
                data: abi.encodeCall(SignalService.init, (address(0), address(am))),
                registerTo: address(am)
            })
        );
        console2.log("signal_service:", block.chainid, address(ss));

        bridge = Bridge(
            payable(
                deployProxy({
                    name: "bridge",
                    impl: address(new Bridge()),
                    data: abi.encodeCall(Bridge.init, (address(0), address(am))),
                    registerTo: address(am)
                })
            )
        );
        console2.log("bridge:", block.chainid, address(bridge));
    }

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 100 ether);

        vm.chainId(l2ChainId);
        (l2AddressManager, l2SignalService, l2Bridge) = _deployContracts();

        vm.chainId(l1ChainId);
        (l1AddressManager, l1SignalService, l1Bridge) = _deployContracts();

        vm.stopPrank();
    }

    // struct Message {
    //     uint64 fee;
    //     uint32 gasLimit;
    //     address from;
    //     uint64 srcChainId;
    //     address srcOwner;
    //     uint64 destChainId;
    //     address destOwner;
    //     address to;
    //     uint256 value;
    //     bytes data;
    // }

    function test_Bridge2_hashMessage() public {
        IBridge.Message memory message;
        bytes32 h1 = l1Bridge.hashMessage(message);
        message.data = " ";
        bytes32 h2 = l1Bridge.hashMessage(message);
        assertNotEq(h1, h2);
    }

    function test_Bridge2_sendMessage() public { }
}
