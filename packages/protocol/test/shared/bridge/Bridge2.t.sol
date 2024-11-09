// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../TaikoTest.sol";

contract BridgeTest2 is TaikoTest {
    bytes internal constant FAKE_PROOF = "";

    // Contracts on Ethereum
    SignalService internal eSignalService;
    Bridge internal eBridge;

    // Contracts on Taiko
    address internal tBridge = randAddress();

    modifier assertSameTotalBalance() {
        uint256 totalBalance = getBalanceForAccounts();
        _;
        uint256 totalBalance2 = getBalanceForAccounts();
        assertEq(totalBalance2, totalBalance);
        assertEq(address(eSignalService).balance, 0);
    }

    // TODO remove this
    modifier dealEther(address addr) {
        vm.deal(addr, 100 ether);
        _;
    }

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalService(address(new SignalServiceNoProofCheck()));
        eBridge = deployBridge(address(new Bridge()));
        vm.deal(address(eBridge), 10_000 ether);
    }

    function setUpOnTaiko() internal override {
        register("bridge", tBridge);
    }

    function getBalanceForAccounts() public view returns (uint256) {
        return Alice.balance + Bob.balance + Carol.balance + David.balance
            + address(eBridge).balance + deployer.balance;
    }
}
