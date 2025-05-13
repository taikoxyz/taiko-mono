// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";

contract TestQuotaManager is CommonTest {
    // Contracts on Ethereum
    QuotaManager private qm;
    address private bridge = randAddress();
    address private erc20Vault = randAddress();

    function setUpOnEthereum() internal override {
        qm = deployQuotaManager(bridge, erc20Vault);
        register("bridge", bridge);
    }

    function test_quota_manager_consume_configged() public {
        address Ether = address(0);
        assertEq(qm.availableQuota(Ether, 0), type(uint256).max);

        vm.expectRevert();
        qm.updateQuota(Ether, 10 ether);

        vm.expectRevert();
        qm.setQuotaPeriod(24 hours);

        vm.prank(deployer);
        qm.updateQuota(Ether, 10 ether);
        assertEq(qm.availableQuota(address(0), 0), 10 ether);

        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        qm.consumeQuota(Ether, 5 ether);

        vm.prank(bridge);
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        qm.consumeQuota(Ether, 11 ether);

        vm.prank(bridge);
        qm.consumeQuota(Ether, 6 ether);
        assertEq(qm.availableQuota(Ether, 0), 4 ether);

        assertEq(qm.availableQuota(Ether, 3 hours), 4 ether + 10 ether * 3 / 24);

        vm.warp(block.timestamp + 3 hours);
        assertEq(qm.availableQuota(Ether, 0), 4 ether + 10 ether * 3 / 24);

        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(Ether, 0), 10 ether);

        vm.startPrank(deployer);
        vm.expectRevert(QuotaManager.QM_INVALID_PARAM.selector);
        qm.setQuotaPeriod(0);

        qm.setQuotaPeriod(12 hours);
        vm.stopPrank();

        vm.prank(bridge);
        qm.consumeQuota(Ether, 5 ether);
        assertEq(qm.availableQuota(Ether, 0), 5 ether);
        assertEq(qm.availableQuota(Ether, 6 hours), 5 ether + 10 ether * 6 / 12);
    }

    function test_quota_manager_consume_unconfigged() public {
        address token = address(999);
        assertEq(qm.availableQuota(token, 0), type(uint256).max);

        vm.prank(bridge);
        qm.consumeQuota(token, 6 ether);
        assertEq(qm.availableQuota(token, 0), type(uint256).max);
    }

    function test_calc_quota() public pure {
        uint24 quotaPeriod = 24 hours;
        uint104 value = 4_000_000; // USD
        uint104 priceETH = 4000; // USD
        uint104 priceTKO = 2; // USD

        console2.log("quota period:", quotaPeriod);
        console2.log("quota value: ", value);
        console2.log("Ether amount ", value / priceETH);
        console2.log("ETH ", address(0), value * 1 ether / priceETH);
        console2.log(
            "WETH ", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, value * 1 ether / priceETH
        );
        console2.log("TAIKO", 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, value * 1e18 / priceTKO);
        console2.log("USDT ", 0xdAC17F958D2ee523a2206206994597C13D831ec7, value * 1e6);
        console2.log("USDC ", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, value * 1e6);
    }
}
