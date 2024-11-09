// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";

abstract contract TaikoL1TestBase is Layer1Test {
    TaikoToken internal eBondToken;
    SignalService internal eSignalService;
    Bridge internal eBridge;
    TaikoL1 internal taikoL1;

    address internal tSignalService = randAddress();
    address internal taikoL2 = randAddress();

    function setUpOnEthereum() internal override {
        eBondToken = deployBondToken();
        eSignalService = deploySignalService(address(new SignalService()));
        eBridge = deployBridge(address(new Bridge()));
        taikoL1 = deployTaikoL1(getConfig());

        eSignalService.authorize(address(taikoL1), true);
    }

    function setUpOnTaiko() internal override {
        register("taiko", taikoL2);
        register("signal_service", tSignalService);
    }

    // TODO: order and name mismatch
    function giveEthAndTko(address to, uint256 amountTko, uint256 amountEth) internal {
        vm.deal(to, amountEth);
        eBondToken.transfer(to, amountTko);

        vm.prank(to);
        eBondToken.approve(address(taikoL1), amountTko);

        console2.log("TKO balance:", to, eBondToken.balanceOf(to));
        console2.log("ETH balance:", to, to.balance);
    }

    function getConfig() public pure virtual returns (TaikoData.Config memory);
}
