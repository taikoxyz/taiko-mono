// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../TaikoTest.sol";

contract BridgeTest2 is TaikoTest {
    bytes public constant fakeProof = "";

    address public owner;
    uint64 public remoteChainId;
    address public remoteBridge;

    DefaultResolver public resolver;
    SignalService public signalService;
    Bridge public bridge;

    modifier transactedBy(address addr) {
        vm.deal(addr, 100 ether);
        vm.startPrank(addr);

        _;
        vm.stopPrank();
    }

    modifier assertSameTotalBalance() {
        uint256 totalBalance = getBalanceForAccounts();
        _;
        uint256 totalBalance2 = getBalanceForAccounts();
        assertEq(totalBalance2, totalBalance);
        assertEq(address(signalService).balance, 0);
    }

    modifier dealEther(address addr) {
        vm.deal(addr, 100 ether);
        _;
    }

    function setUp() public {
        owner = vm.addr(0x1000);
        vm.deal(owner, 100 ether);

        remoteChainId = uint64(block.chainid + 1);
        remoteBridge = vm.addr(0x2000);

        vm.startPrank(owner);

        resolver = deployDefaultResolver();
        //     deployProxy({
        //         name: "address_manager",
        //         impl: address(new DefaultResolver()),
        //         data: abi.encodeCall(DefaultResolver.init, (address(0)))
        //     })
        // );

        signalService = deploySignalService(resolver, address(new SkipProofCheckSignal()));
        //     deployProxy({
        //         name: "signal_service",
        //         impl: address(new SkipProofCheckSignal()),
        //         data: abi.encodeCall(SignalService.init, (address(0), address(resolver))),
        //         registerTo: address(resolver)
        //     })
        // );

        bridge = deployBridge(resolver, address(new Bridge()));
        //     payable(
        //         deployProxy({
        //             name: "bridge",
        //             impl: address(new Bridge()),
        //             data: abi.encodeCall(Bridge.init, (address(0), address(resolver))),
        //             registerTo: address(resolver)
        //         })
        //     )
        // );

        vm.deal(address(bridge), 10_000 ether);

        resolver.setAddress(remoteChainId, "bridge", remoteBridge);
        vm.stopPrank();
    }

    function getBalanceForAccounts() public view returns (uint256) {
        return Alice.balance + Bob.balance + Carol.balance + David.balance + address(bridge).balance
            + owner.balance;
    }
}
