// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../TaikoTest.sol";

contract BridgeTest2 is TaikoTest {
    bytes public constant FAKE_PROOF = "";

    SignalService public signalService;
    Bridge public bridge;
    address public destBridge;

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
        deployer = Olivia;
        prepareContracts();
    }

    function prepareContractsOnSourceChain() internal override {
        signalService = deploySignalService(address(new SignalServiceNoProofCheck()));
        bridge = deployBridge(address(new Bridge()));
        vm.deal(address(bridge), 10_000 ether);
    }

    function prepareContractsOnDestinationChain() internal override {
        destBridge = vm.addr(0x2000);
        register("bridge", destBridge);
    }

    function getBalanceForAccounts() public view returns (uint256) {
        return Alice.balance + Bob.balance + Carol.balance + David.balance + address(bridge).balance
            + deployer.balance;
    }
}
