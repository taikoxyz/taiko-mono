// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract BridgeTest2 is TaikoTest {
    bytes public constant fakeProof = "";

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

    modifier assertSameTotalBalance() {
        uint256 totalBalance = getBalanceForAccounts();
        _;
        uint256 totalBalance2 = getBalanceForAccounts();
        assertEq(totalBalance2, totalBalance);
    }

    modifier dealEther(address addr) {
        vm.deal(addr, 100 ether);
        _;
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

        vm.deal(address(bridge), 10_000 ether);

        addressManager.setAddress(remoteChainId, "bridge", remoteBridge);
        vm.stopPrank();
    }

    function getBalanceForAccounts() public view returns (uint256) {
        return Alice.balance + Bob.balance + Carol.balance + David.balance + address(bridge).balance;
    }
}

contract TestToContract is IMessageInvocable {
    uint256 public receivedEther;
    IBridge private bridge;
    IBridge.Context public ctx;

    constructor(IBridge _bridge) {
        bridge = _bridge;
    }

    function onMessageInvocation(bytes calldata) external payable {
        ctx = bridge.context();
        receivedEther += msg.value;
    }

    function anotherFunc(bytes calldata) external payable {
        receivedEther += msg.value;
    }

    fallback() external payable {
        ctx = bridge.context();
        receivedEther += msg.value;
    }

    receive() external payable { }
}
