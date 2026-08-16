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
        assertEq(qm.availableQuota(Ether, 0), qm.UNLIMITED_QUOTA());

        vm.expectRevert();
        qm.updateQuota(Ether, 10 ether);

        vm.expectRevert();
        qm.setQuotaPeriod(24 hours);

        vm.prank(deployer);
        qm.updateQuota(Ether, 10 ether);
        assertEq(qm.availableQuota(address(0), 0), 10 ether);

        vm.expectRevert(QuotaManager.QM_PERMISSION_DENIED.selector);
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

    function test_quota_manager_constructor_initializes_quotas() public {
        address[] memory tokens = new address[](3);
        tokens[0] = address(0);
        tokens[1] = address(1);
        tokens[2] = address(2);

        uint104[] memory quotas = new uint104[](3);
        quotas[0] = 250 ether;
        quotas[1] = 10_000_000 ether;
        quotas[2] = 150_000_000_000;

        QuotaManager manager =
            new QuotaManager(deployer, bridge, erc20Vault, 24 hours, tokens, quotas);

        assertEq(manager.availableQuota(tokens[0], 0), quotas[0]);
        assertEq(manager.availableQuota(tokens[1], 0), quotas[1]);
        assertEq(manager.availableQuota(tokens[2], 0), quotas[2]);
        assertEq(manager.availableQuota(address(3), 0), manager.UNLIMITED_QUOTA());
    }

    function test_quota_manager_consume_unconfigged() public {
        address token = address(999);
        assertEq(qm.UNLIMITED_QUOTA(), type(uint256).max);
        assertEq(qm.availableQuota(token, 0), qm.UNLIMITED_QUOTA());

        vm.prank(bridge);
        qm.consumeQuota(token, 6 ether);
        assertEq(qm.availableQuota(token, 0), qm.UNLIMITED_QUOTA());
    }

    function test_quota_manager_consume_emits_event() public {
        address Ether = address(0);

        vm.prank(deployer);
        qm.updateQuota(Ether, 10 ether);

        vm.expectEmit();
        emit QuotaManager.QuotaConsumed(Ether, 6 ether, 4 ether);

        vm.prank(bridge);
        qm.consumeQuota(Ether, 6 ether);

        assertEq(qm.availableQuota(Ether, 0), 4 ether);
    }

    function test_quota_manager_restores_fully_after_long_period() public {
        address Ether = address(0);

        vm.prank(deployer);
        qm.updateQuota(Ether, 10 ether);

        vm.prank(bridge);
        qm.consumeQuota(Ether, 6 ether);
        assertEq(qm.availableQuota(Ether, 0), 4 ether);

        // Warp far beyond a single quota period (~100 years). The quota must be fully restored
        // and capped at the configured quota, and consumeQuota must keep working.
        vm.warp(block.timestamp + 36_500 days);
        assertEq(qm.availableQuota(Ether, 0), 10 ether);

        vm.prank(bridge);
        qm.consumeQuota(Ether, 10 ether);
        assertEq(qm.availableQuota(Ether, 0), 0);
    }

    function test_quota_manager_no_overflow_with_max_quota_and_large_elapsed() public {
        address Ether = address(0);

        // Configure the maximum possible quota to maximize the overflow risk in the issuance
        // calculation `q.quota * elapsed`.
        vm.prank(deployer);
        qm.updateQuota(Ether, type(uint104).max);

        // Consume a tiny amount so that `updatedAt` becomes non-zero and the issuance branch
        // (rather than the early `q.updatedAt == 0` return) is exercised.
        vm.prank(bridge);
        qm.consumeQuota(Ether, 1);

        // With an unbounded elapsed time, `q.quota * elapsed` would exceed uint256 and revert,
        // bricking `consumeQuota`. Capping elapsed at `quotaPeriod` keeps it safe and simply
        // returns the fully restored quota. `2 ** 160` is large enough to overflow the product
        // while keeping `block.timestamp + _leap` itself within uint256.
        uint256 hugeLeap = 1 << 160;
        assertEq(qm.availableQuota(Ether, hugeLeap), type(uint104).max);
    }

    function test_quota_manager_no_overflow_with_max_leap() public {
        address Ether = address(0);

        vm.prank(deployer);
        qm.updateQuota(Ether, type(uint104).max);

        // Set a non-zero `updatedAt` so the issuance branch (not the early return) is taken.
        vm.prank(bridge);
        qm.consumeQuota(Ether, 1);

        // A `_leap` near uint256 max must not overflow the `block.timestamp + _leap` addition.
        // The lookahead saturates at `quotaPeriod`, so the fully restored quota is reported.
        assertEq(qm.availableQuota(Ether, type(uint256).max), type(uint104).max);
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
