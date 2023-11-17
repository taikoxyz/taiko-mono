// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TimeLockTokenPool as Pool } from
    "../../contracts/team/TimeLockTokenPool.sol";
import { Test } from "forge-std/Test.sol";
import { ERC20 } from
    "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { console2 } from "forge-std/console2.sol";

contract MyERC20 is ERC20 {
    constructor(address owner) ERC20("Taiko Token", "TKO") {
        _mint(owner, 1_000_000_000e18);
    }
}

contract TestTimeLockTokenPool is Test {
    address internal Vault = vm.addr(0x1);
    address internal Alice = vm.addr(0x2);
    address internal Bob = vm.addr(0x3);
    address internal Owen = vm.addr(0x4);

    ERC20 tko = new MyERC20(Vault);
    Pool pool = new Pool();

    function setUp() public {
        pool.init(Owen, address(tko), Vault);
    }

    function test_invalid_granting() public {
        vm.expectRevert(Pool.INVALID_GRANT.selector);
        vm.prank(Owen);
        pool.grant(Alice, Pool.Grant(0, 0, 0, 0, 0, 0, 0));

        vm.expectRevert(Pool.INVALID_PARAM.selector);
        vm.prank(Owen);
        pool.grant(address(0), Pool.Grant(100e18, 0, 0, 0, 0, 0, 0));
    }

    function test_single_grant_zero_grant_period_zero_unlock_period() public {
        vm.prank(Owen);
        pool.grant(Alice, Pool.Grant(10_000e18, 0, 0, 0, 0, 0, 0));

        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 10_000e18);

        // Try to void the grant
        vm.expectRevert(Pool.NOTHING_TO_VOID.selector);

        vm.prank(Owen);
        pool.void(Alice);

        vm.prank(Alice);
        pool.withdraw();
        assertEq(tko.balanceOf(Alice), 10_000e18);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 10_000e18);
        assertEq(amountWithdrawable, 0);
    }

    function test_single_grant_zero_grant_period_1year_unlock_period() public {
        uint64 unlockStart = uint64(block.timestamp);
        uint32 unlockPeriod = 365 days;
        uint64 unlockCliff = unlockStart + unlockPeriod / 2;

        vm.prank(Owen);
        pool.grant(
            Alice,
            Pool.Grant(
                10_000e18, 0, 0, 0, unlockStart, unlockCliff, unlockPeriod
            )
        );
        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        vm.warp(unlockCliff);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        vm.warp(unlockCliff + 1);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        uint256 amount1 = 5_000_000_317_097_919_837_645;
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, amount1);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, amount1);

        vm.prank(Alice);
        pool.withdraw();

        vm.warp(unlockStart + unlockPeriod + 365 days);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, amount1);
        assertEq(amountWithdrawable, 10_000e18 - amount1);

        vm.prank(Alice);
        pool.withdraw();

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 10_000e18);
        assertEq(amountWithdrawable, 0);
    }

    function test_single_grant_1year_grant_period_zero_unlock_period() public {
        uint64 grantStart = uint64(block.timestamp);
        uint32 grantPeriod = 365 days;
        uint64 grantCliff = grantStart + grantPeriod / 2;

        vm.prank(Owen);
        pool.grant(
            Alice,
            Pool.Grant(10_000e18, grantStart, grantCliff, grantPeriod, 0, 0, 0)
        );

        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        vm.warp(grantCliff);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        vm.warp(grantCliff + 1);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        uint256 amount1 = 5_000_000_317_097_919_837_645;
        assertEq(amountOwned, amount1);
        assertEq(amountUnlocked, amount1);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, amount1);

        vm.prank(Alice);
        pool.withdraw();

        vm.warp(grantStart + grantPeriod + 365 days);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, amount1);
        assertEq(amountWithdrawable, 10_000e18 - amount1);

        vm.prank(Alice);
        pool.withdraw();

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 10_000e18);
        assertEq(amountWithdrawable, 0);
    }

    function test_single_grant_4year_grant_period_4year_unlock_period()
        public
    {
        uint64 grantStart = uint64(block.timestamp);
        uint32 grantPeriod = 4 * 365 days;
        uint64 grantCliff = grantStart + 90 days;

        uint64 unlockStart = grantStart + 365 days;
        uint32 unlockPeriod = 4 * 365 days;
        uint64 unlockCliff = unlockStart + 365 days;

        vm.prank(Owen);
        pool.grant(
            Alice,
            Pool.Grant(
                10_000e18,
                grantStart,
                grantCliff,
                grantPeriod,
                unlockStart,
                unlockCliff,
                unlockPeriod
            )
        );

        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        // 90 days later
        vm.warp(grantStart + 90 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        // 1 year later
        vm.warp(grantStart + 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 2500e18);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        // 2 year later
        vm.warp(grantStart + 2 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 5000e18);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        // 3 year later
        vm.warp(grantStart + 3 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 7500e18);
        assertEq(amountUnlocked, 3750e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 3750e18);

        // 4 year later
        vm.warp(grantStart + 4 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 7500e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 7500e18);

        // 5 year later
        vm.warp(grantStart + 5 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 10_000e18);

        // 6 year later
        vm.warp(grantStart + 6 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 10_000e18);
    }

    function test_multiple_grants() public {
        vm.prank(Owen);
        pool.grant(Alice, Pool.Grant(10_000e18, 0, 0, 0, 0, 0, 0));

        vm.prank(Owen);
        pool.grant(Alice, Pool.Grant(20_000e18, 0, 0, 0, 0, 0, 0));

        vm.prank(Vault);
        tko.approve(address(pool), 30_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getGrantSummary(Alice);
        assertEq(amountOwned, 30_000e18);
        assertEq(amountUnlocked, 30_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 30_000e18);
    }

    function test_void_multiple_grants_before_granted() public {
        uint64 grantStart = uint64(block.timestamp) + 30 days;

        vm.prank(Owen);
        pool.grant(Alice, Pool.Grant(10_000e18, grantStart, 0, 0, 0, 0, 0));

        vm.prank(Owen);
        pool.grant(Alice, Pool.Grant(20_000e18, grantStart, 0, 0, 0, 0, 0));

        vm.prank(Vault);
        tko.approve(address(pool), 30_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        // Try to void the grant
        vm.prank(Owen);
        pool.void(Alice);

        Pool.Grant[] memory grants = pool.getMyGrants(Alice);
        for (uint256 i; i < grants.length; ++i) {
            assertEq(grants[i].grantStart, 0);
            assertEq(grants[i].grantPeriod, 0);
            assertEq(grants[i].grantCliff, 0);

            assertEq(grants[i].unlockStart, 0);
            assertEq(grants[i].unlockPeriod, 0);
            assertEq(grants[i].unlockCliff, 0);

            assertEq(grants[i].amount, 0);
        }
    }

    function test_void_multiple_grants_after_granted() public {
        uint64 grantStart = uint64(block.timestamp) + 30 days;

        vm.prank(Owen);
        pool.grant(Alice, Pool.Grant(10_000e18, grantStart, 0, 0, 0, 0, 0));

        vm.prank(Owen);
        pool.grant(Alice, Pool.Grant(20_000e18, grantStart, 0, 0, 0, 0, 0));

        vm.prank(Vault);
        tko.approve(address(pool), 30_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getGrantSummary(Alice);

        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 0);

        vm.warp(grantStart + 1);

        // Try to void the grant
        // Try to void the grant
        vm.expectRevert(Pool.NOTHING_TO_VOID.selector);
        vm.prank(Owen);
        pool.void(Alice);
    }

    function test_void_multiple_grants_in_the_middle() public {
        uint64 grantStart = uint64(block.timestamp);
        uint32 grantPeriod = 100 days;

        vm.prank(Owen);
        pool.grant(
            Alice, Pool.Grant(10_000e18, grantStart, 0, grantPeriod, 0, 0, 0)
        );

        vm.prank(Owen);
        pool.grant(
            Alice, Pool.Grant(20_000e18, grantStart, 0, grantPeriod, 0, 0, 0)
        );

        vm.prank(Vault);
        tko.approve(address(pool), 30_000e18);

        vm.warp(grantStart + 50 days);
        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getGrantSummary(Alice);

        assertEq(amountOwned, 15_000e18);
        assertEq(amountUnlocked, 15_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 15_000e18);

        vm.prank(Owen);
        pool.void(Alice);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 15_000e18);
        assertEq(amountUnlocked, 15_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 15_000e18);

        vm.warp(grantStart + 100 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getGrantSummary(Alice);
        assertEq(amountOwned, 15_000e18);
        assertEq(amountUnlocked, 15_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 15_000e18);
    }
}
