// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract MyERC20 is ERC20 {
    constructor(address owner) ERC20("Taiko Token", "TKO") {
        _mint(owner, 1_000_000_000e18);
    }
}

contract USDC is ERC20 {
    constructor(address recipient) ERC20("USDC", "USDC") {
        _mint(recipient, 1_000_000_000e6);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}

contract TestTimelockTokenPool is TaikoTest {
    address internal Vault = randAddress();

    ERC20 tko = new MyERC20(Vault);
    ERC20 usdc = new USDC(Alice);

    uint128 public constant ONE_TKO_UNIT = 1e18;

    // 0.01 USDC if decimals are 6 (as in our test)
    uint64 strikePrice1 = uint64(10 ** usdc.decimals() / 100);
    // 0.05 USDC if decimals are 6 (as  in our test)
    uint64 strikePrice2 = uint64(10 ** usdc.decimals() / 20);

    TimelockTokenPool pool;

    function setUp() public {
        pool = TimelockTokenPool(
            deployProxy({
                name: "time_lock_token_pool",
                impl: address(new TimelockTokenPool()),
                data: abi.encodeCall(
                    TimelockTokenPool.init, (address(0), address(tko), address(usdc), Vault)
                    )
            })
        );
    }

    function test_invalid_granting() public {
        vm.expectRevert(TimelockTokenPool.INVALID_GRANT.selector);
        pool.grant(Alice, TimelockTokenPool.Grant(0, 0, 0, 0, 0, 0, 0, 0));

        vm.expectRevert(TimelockTokenPool.INVALID_PARAM.selector);
        pool.grant(address(0), TimelockTokenPool.Grant(100e18, 0, 0, 0, 0, 0, 0, 0));
    }

    function test_single_grant_zero_grant_period_zero_unlock_period() public {
        pool.grant(Alice, TimelockTokenPool.Grant(10_000e18, 0, 0, 0, 0, 0, 0, 0));
        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        ) = pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 10_000e18);
        assertEq(costToWithdraw, 0);

        // Try to void the grant
        vm.expectRevert(TimelockTokenPool.NOTHING_TO_VOID.selector);
        pool.void(Alice);

        vm.prank(Alice);
        pool.withdraw();
        assertEq(tko.balanceOf(Alice), 10_000e18);

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 10_000e18);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);
    }

    function test_single_grant_zero_grant_period_1year_unlock_period() public {
        uint64 unlockStart = uint64(block.timestamp);
        uint32 unlockPeriod = 365 days;
        uint64 unlockCliff = unlockStart + unlockPeriod / 2;

        pool.grant(
            Alice,
            TimelockTokenPool.Grant(
                10_000e18, strikePrice1, 0, 0, 0, unlockStart, unlockCliff, unlockPeriod
            )
        );
        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);
        vm.prank(Alice);
        usdc.approve(address(pool), 10_000e18 / ONE_TKO_UNIT * strikePrice1);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        ) = pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        vm.warp(unlockCliff);

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        vm.warp(unlockCliff + 1);

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);

        uint256 amount1 = uint128(10_000e18) * uint64(block.timestamp - unlockStart) / unlockPeriod;
        uint256 expectedCost = amount1 / ONE_TKO_UNIT * strikePrice1;

        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, amount1);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, amount1);
        assertEq(costToWithdraw, expectedCost);

        vm.prank(Alice);
        pool.withdraw();

        vm.warp(unlockStart + unlockPeriod + 365 days);

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);

        expectedCost = amount1 / ONE_TKO_UNIT * strikePrice1;

        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, amount1);
        assertEq(amountToWithdraw, 10_000e18 - amount1);
        assertEq(costToWithdraw, expectedCost);

        vm.prank(Alice);
        pool.withdraw();

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 10_000e18);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);
    }

    function test_single_grant_1year_grant_period_zero_unlock_period() public {
        uint64 grantStart = uint64(block.timestamp);
        uint32 grantPeriod = 365 days;
        uint64 grantCliff = grantStart + grantPeriod / 2;

        pool.grant(
            Alice,
            TimelockTokenPool.Grant(
                10_000e18, strikePrice1, grantStart, grantCliff, grantPeriod, 0, 0, 0
            )
        );
        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        vm.prank(Alice);
        usdc.approve(address(pool), 10_000e18 / ONE_TKO_UNIT * strikePrice1);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        ) = pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        vm.warp(grantCliff);

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        vm.warp(grantCliff + 1);

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);

        uint256 amount1 = uint128(10_000e18) * uint64(block.timestamp - grantStart) / grantPeriod;
        uint256 expectedCost = amount1 / ONE_TKO_UNIT * strikePrice1;
        console2.log("expectedCost", expectedCost);
        console2.log("costToWithdraw", costToWithdraw);
        assertEq(amountOwned, amount1);
        assertEq(amountUnlocked, amount1);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, amount1);
        assertEq(costToWithdraw, expectedCost);
        console2.log("EZ feltt elvileg jo volt");

        vm.prank(Alice);
        pool.withdraw();

        vm.warp(grantStart + grantPeriod + 365 days);

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);

        expectedCost = amount1 / ONE_TKO_UNIT * strikePrice1;
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, amount1);
        assertEq(amountToWithdraw, 10_000e18 - amount1);
        assertEq(costToWithdraw, expectedCost);

        vm.prank(Alice);
        pool.withdraw();

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 10_000e18);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);
    }

    function test_single_grant_4year_grant_period_4year_unlock_period() public {
        uint64 grantStart = uint64(block.timestamp);
        uint32 grantPeriod = 4 * 365 days;
        uint64 grantCliff = grantStart + 90 days;

        uint64 unlockStart = grantStart + 365 days;
        uint32 unlockPeriod = 4 * 365 days;
        uint64 unlockCliff = unlockStart + 365 days;

        pool.grant(
            Alice,
            TimelockTokenPool.Grant(
                10_000e18,
                strikePrice1,
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

        vm.prank(Alice);
        usdc.approve(address(pool), 10_000e18 / ONE_TKO_UNIT * strikePrice1);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        ) = pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        // 90 days later
        vm.warp(grantStart + 90 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        // 1 year later
        vm.warp(grantStart + 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 2500e18);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        // 2 year later
        vm.warp(grantStart + 2 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 5000e18);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        // 3 year later
        vm.warp(grantStart + 3 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);

        uint256 expectedCost = 3750e18 / ONE_TKO_UNIT * strikePrice1;

        assertEq(amountOwned, 7500e18);
        assertEq(amountUnlocked, 3750e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 3750e18);
        assertEq(costToWithdraw, expectedCost);

        // 4 year later
        vm.warp(grantStart + 4 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);

        expectedCost = 7500e18 / ONE_TKO_UNIT * strikePrice1;

        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 7500e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 7500e18);
        assertEq(costToWithdraw, expectedCost);

        // 5 year later
        vm.warp(grantStart + 5 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);

        expectedCost = 10_000e18 / ONE_TKO_UNIT * strikePrice1;

        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 10_000e18);
        assertEq(costToWithdraw, expectedCost);

        // 6 year later
        vm.warp(grantStart + 6 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 10_000e18);
        assertEq(costToWithdraw, expectedCost);
    }

    function test_void_grant_before_granted() public {
        uint64 grantStart = uint64(block.timestamp) + 30 days;
        pool.grant(Alice, TimelockTokenPool.Grant(10_000e18, 0, grantStart, 0, 0, 0, 0, 0));

        vm.expectRevert(TimelockTokenPool.ALREADY_GRANTED.selector);
        pool.grant(Alice, TimelockTokenPool.Grant(20_000e18, 0, grantStart, 0, 0, 0, 0, 0));

        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        ) = pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        // Try to void the grant
        pool.void(Alice);

        TimelockTokenPool.Grant memory grant = pool.getMyGrant(Alice);

        assertEq(grant.grantStart, 0);
        assertEq(grant.grantPeriod, 0);
        assertEq(grant.grantCliff, 0);
        assertEq(grant.unlockStart, 0);
        assertEq(grant.unlockPeriod, 0);
        assertEq(grant.unlockCliff, 0);
        assertEq(grant.amount, 0);
    }

    function test_void_grant_after_granted() public {
        uint64 grantStart = uint64(block.timestamp) + 30 days;
        pool.grant(Alice, TimelockTokenPool.Grant(10_000e18, 0, grantStart, 0, 0, 0, 0, 0));

        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        ) = pool.getMyGrantSummary(Alice);

        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        vm.warp(grantStart + 1);

        // Try to void the grant
        vm.expectRevert(TimelockTokenPool.NOTHING_TO_VOID.selector);
        pool.void(Alice);
    }

    function test_void_grant_in_the_middle() public {
        uint64 grantStart = uint64(block.timestamp);
        uint32 grantPeriod = 100 days;
        pool.grant(
            Alice,
            TimelockTokenPool.Grant(10_000e18, strikePrice1, grantStart, 0, grantPeriod, 0, 0, 0)
        );

        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        uint256 halfTimeWithdrawCost = 5000e18 / ONE_TKO_UNIT * strikePrice1;

        vm.warp(grantStart + 50 days);
        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        ) = pool.getMyGrantSummary(Alice);

        assertEq(amountOwned, 5000e18);
        assertEq(amountUnlocked, 5000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 5000e18);
        assertEq(costToWithdraw, halfTimeWithdrawCost);

        pool.void(Alice);

        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 5000e18);
        assertEq(amountUnlocked, 5000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 5000e18);
        assertEq(costToWithdraw, halfTimeWithdrawCost);

        vm.warp(grantStart + 100 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 5000e18);
        assertEq(amountUnlocked, 5000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 5000e18);
        assertEq(costToWithdraw, halfTimeWithdrawCost);
    }

    function test_correct_strike_price() public {
        uint64 grantStart = uint64(block.timestamp);
        uint32 grantPeriod = 4 * 365 days;
        uint64 grantCliff = grantStart + 90 days;

        uint64 unlockStart = grantStart + 365 days;
        uint32 unlockPeriod = 4 * 365 days;
        uint64 unlockCliff = unlockStart + 365 days;

        uint64 strikePrice = 10_000; // 0.01 USDC if decimals are 6 (as in our test)

        pool.grant(
            Alice,
            TimelockTokenPool.Grant(
                10_000e18,
                strikePrice,
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
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        ) = pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(costToWithdraw, 0);

        // When withdraw (5 years later) - check if correct price is deducted
        vm.warp(grantStart + 5 * 365 days);
        (amountOwned, amountUnlocked, amountWithdrawn, amountToWithdraw, costToWithdraw) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 10_000e18);

        // 10_000 TKO tokens * strikePrice
        uint256 paidUsdc = 10_000 * strikePrice;

        vm.prank(Alice);
        usdc.approve(address(pool), paidUsdc);

        vm.prank(Alice);
        pool.withdraw();
        assertEq(tko.balanceOf(Alice), 10_000e18);
        assertEq(usdc.balanceOf(Alice), 1_000_000_000e6 - paidUsdc);
    }
}
