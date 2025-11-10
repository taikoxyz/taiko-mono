// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "test/shared/bridge/helpers/MessageReceiver_SendingHalfEtherBalance.sol";

contract TestBridge2Base is CommonTest {
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

    modifier dealEther(address addr) {
        vm.deal(addr, 100 ether);
        _;
    }

    function setUpOnEthereum() internal override {
        eSignalService = _deployMockSignalService();
        eBridge = deployBridge(address(new Bridge(address(resolver), address(eSignalService))));
        vm.deal(address(eBridge), 10_000 ether);
    }

    function setUpOnTaiko() internal override {
        register("bridge", tBridge);
    }

    function getBalanceForAccounts() public view returns (uint256) {
        return Alice.balance + Bob.balance + Carol.balance + David.balance
            + address(eBridge).balance + deployer.balance;
    }

    function _deployMockSignalService() private returns (SignalService) {
        return deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_E")))), deployer
        );
    }
}
