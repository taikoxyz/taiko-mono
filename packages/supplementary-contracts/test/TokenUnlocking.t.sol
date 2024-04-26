// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../contracts/TokenUnlocking.sol";

contract MyERC20 is ERC20 {
    constructor(address owner) ERC20("Taiko Token", "TKO") {
        _mint(owner, 1_000_000_000e18);
    }
}

contract TestTokenUnlocking is Test {
    // Owner of the
    address internal Owner = vm.addr(0x1);

    /* Let's assume Alice has 100_000 tokens which vests over 4 years, quarterly.
    Alice started at company 1 year BEFORE TGE, so actually at TGE she has 25_000 vested (and
    deposited) already */
    address internal Alice = vm.addr(0x2);

    /* Let's assume Alice has 16_000 tokens which vests over 4 years, quarterly.
    Alice started at company at TGE, so actually at TGE she has 0 vested. First deposit will be
    after a quarter past TGE (not considering his vesting cliff could be half year, it will be done
    off-chain anyways) */
    address internal Bob = vm.addr(0x3);

    address internal Vault = vm.addr(0x4);

    uint64 tgeTimestamp = 1_713_564_000; // = 2024.04.20. 00:00:00

    ERC20 tko = new MyERC20(Vault);

    uint128 public constant ONE_TKO_UNIT = 1e18;

    TokenUnlocking tokenUnlockingAlice;
    TokenUnlocking tokenUnlockingBob;

    function setUp() public {
        vm.warp(tgeTimestamp);

        tokenUnlockingAlice = TokenUnlocking(
            deployProxy({
                impl: address(new TokenUnlocking()),
                data: abi.encodeCall(
                    TokenUnlocking.init, (Owner, address(tko), Vault, Alice, tgeTimestamp)
                    )
            })
        );
        tokenUnlockingBob = TokenUnlocking(
            deployProxy({
                impl: address(new TokenUnlocking()),
                data: abi.encodeCall(
                    TokenUnlocking.init, (Owner, address(tko), Vault, Bob, tgeTimestamp)
                    )
            })
        );
    }

    function test_invalid_grantee() public {
        vm.startPrank(Owner);
        vm.expectRevert(TokenUnlocking.INVALID_GRANTEE.selector);
        // Cannot call if not Alice is the recipient
        tokenUnlockingAlice.vestToken(Bob, 25_000);
        vm.stopPrank();
    }

    function test_wrong_grantee_recipient() public {
        vm.startPrank(Bob);
        vm.expectRevert(TokenUnlocking.WRONG_GRANTEE_RECIPIENT.selector);
        // Cannot call if not Alice is the recipient
        tokenUnlockingAlice.withdraw();
        vm.stopPrank();
    }

    function test_Bobs_unlocking() public {
        // Vault has to approve Alice's unlocking contract before calling the vestToken() function.
        vm.prank(Vault, Vault);
        tko.approve(address(tokenUnlockingBob), 25_000);

        vm.startPrank(Owner);
        // At TGE Bob has nothing
        (
            uint128 amountVested,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw
        ) = tokenUnlockingBob.getMyGrantSummary(Bob);

        assertEq(amountVested, 0);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);

        // 1 quarter after TGE, Bob get's 1/16 of his tokens (Since vesting is querterly during the
        // 4 year unlcok period after TGE)
        // Vault has to approve Bob's unlocking contract before calling the vestToken() function.
        vm.warp(tgeTimestamp + 90 days + 1);

        vm.stopPrank();

        vm.prank(Vault, Vault);
        tko.approve(address(tokenUnlockingBob), 1000);

        vm.startPrank(Owner);
        tokenUnlockingBob.vestToken(Bob, 1000);

        // Bob has some amount vested, but not unlocked, since we are below the 1 year unlock cliff
        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingBob.getMyGrantSummary(Bob);

        assertEq(amountVested, 1000);
        assertEq(amountUnlocked, 0);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 0);

        vm.stopPrank();

        // Ok, let's imitate there were 3 other tokenVests in that rest of that year
        vm.prank(Vault, Vault);
        tko.approve(address(tokenUnlockingBob), 3000); //The missing 3000 of 4000 per year

        vm.startPrank(Owner);
        tokenUnlockingBob.vestToken(Bob, 3000);

        // 1 year elapsed, 25% of that 25K shall be unlocked
        vm.warp(tgeTimestamp + 365 days + 1);

        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingBob.getMyGrantSummary(Bob);

        assertEq(amountVested, 4000);
        assertEq(amountUnlocked, 4000 / 4);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 4000 / 4);

        vm.stopPrank();

        vm.startPrank(Bob);
        // Bob now withdraws
        tokenUnlockingBob.withdraw();

        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingBob.getMyGrantSummary(Bob);

        assertEq(amountVested, 4000);
        assertEq(amountUnlocked, 4000 / 4);
        assertEq(amountWithdrawn, 4000 / 4);
        assertEq(amountToWithdraw, 0);

        vm.stopPrank();

        // Ok, let's imitate again a quarterly vesting (but in 1 go now, for the sake of simplicity)
        vm.prank(Vault, Vault);
        tko.approve(address(tokenUnlockingBob), 4000);

        vm.startPrank(Owner);
        tokenUnlockingBob.vestToken(Bob, 4000);
        vm.stopPrank();

        vm.startPrank(Bob);
        // 2 year elapsed, 50% of that 16K shall be unlocked
        vm.warp(tgeTimestamp + 2 * 365 days + 1);

        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingBob.getMyGrantSummary(Bob);

        assertEq(amountVested, 8000);
        assertEq(amountUnlocked, 8000 / 2);
        assertEq(amountWithdrawn, 8000 / 8); // only 1/4 of that 4K is withdrawn, so 1/8 of 8k
        assertEq(amountToWithdraw, (amountUnlocked - amountWithdrawn));

        // Bob now withdraws again after year 2
        tokenUnlockingBob.withdraw();
        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingBob.getMyGrantSummary(Bob);

        assertEq(amountVested, 8000);
        assertEq(amountUnlocked, 8000 / 2);
        assertEq(amountWithdrawn, 8000 / 2);
        assertEq(amountToWithdraw, 0);

        vm.stopPrank();

        // Ok, let's imitate again a quarterly vesting (for the sake of simplicity)
        // Now 2 year elapses.. (So we will be at 4 year post TGE)
        vm.prank(Vault, Vault);
        tko.approve(address(tokenUnlockingBob), 8000);

        vm.startPrank(Owner);
        tokenUnlockingBob.vestToken(Bob, 8000);
        vm.stopPrank();

        vm.startPrank(Bob);

        // 4 year elapsed, 100% of that 16K shall be unlocked
        vm.warp(tgeTimestamp + 4 * 365 days + 1);

        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingBob.getMyGrantSummary(Bob);

        assertEq(amountVested, 16_000);
        assertEq(amountUnlocked, 16_000);
        assertEq(amountWithdrawn, 8000 / 2); // Let's assume between year2 and year4, there were no
            // withdrawals
        assertEq(amountToWithdraw, (amountUnlocked - amountWithdrawn));

        // Bob now withdraws again after year 4
        tokenUnlockingBob.withdraw();
        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingBob.getMyGrantSummary(Bob);

        assertEq(amountVested, 16_000);
        assertEq(amountUnlocked, 16_000);
        assertEq(amountWithdrawn, 16_000);
        assertEq(amountToWithdraw, 0);

        vm.stopPrank();
    }

    function test_Alice_leaves_at_tge_so_vests_only_25_percent_of_her_allocation_linearly()
        public
    {
        // Vault has to approve Alice's unlocking contract before calling the vestToken() function.
        vm.prank(Vault, Vault);
        tko.approve(address(tokenUnlockingAlice), 25_000);

        vm.startPrank(Owner);
        // So if Alice left at TGE, she only vested 25K tokens. (Since she joined 1 year pre TGE)
        // Let's see how it unlocks
        tokenUnlockingAlice.vestToken(Alice, 25_000);

        // 1 year elapsed, 25% of that 25K shall be unlocked
        vm.warp(tgeTimestamp + 365 days + 1);

        (
            uint128 amountVested,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw
        ) = tokenUnlockingAlice.getMyGrantSummary(Alice);

        assertEq(amountVested, 25_000);
        assertEq(amountUnlocked, 25_000 / 4);
        assertEq(amountWithdrawn, 0);
        assertEq(amountToWithdraw, 25_000 / 4);

        vm.stopPrank();

        vm.startPrank(Alice);
        // Alice now withdraws
        tokenUnlockingAlice.withdraw();

        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingAlice.getMyGrantSummary(Alice);

        assertEq(amountVested, 25_000);
        assertEq(amountUnlocked, 25_000 / 4);
        assertEq(amountWithdrawn, 25_000 / 4);
        assertEq(amountToWithdraw, 0);

        // 2 year elapsed, 50% of that 25K shall be unlocked
        vm.warp(tgeTimestamp + 2 * 365 days + 1);

        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingAlice.getMyGrantSummary(Alice);

        // console2.log("After 2 years, before withdraw");
        // console2.log(amountVested);
        // console2.log(amountUnlocked);
        // console2.log(amountWithdrawn);
        // console2.log(amountToWithdraw);

        assertEq(amountVested, 25_000);
        assertEq(amountUnlocked, 25_000 / 2);
        assertEq(amountWithdrawn, 25_000 / 4);
        assertEq(amountToWithdraw, 25_000 / 4);

        // Alice now withdraws again after year 2
        tokenUnlockingAlice.withdraw();
        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingAlice.getMyGrantSummary(Alice);

        // console2.log("After 2 years, and after withdraw");
        // console2.log(amountVested);
        // console2.log(amountUnlocked);
        // console2.log(amountWithdrawn);
        // console2.log(amountToWithdraw);

        assertEq(amountVested, 25_000);
        assertEq(amountUnlocked, 25_000 / 2);
        assertEq(amountWithdrawn, 25_000 / 2);
        assertEq(amountToWithdraw, 0);

        // 3 year elapsed, 75% of that 25K shall be unlocked
        vm.warp(tgeTimestamp + 3 * 365 days + 1);

        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingAlice.getMyGrantSummary(Alice);

        assertEq(amountVested, 25_000);
        assertEq(amountUnlocked, (25_000 / 2) + (25_000 / 4)); // 50% + 25% = 75%
        assertEq(amountWithdrawn, 25_000 / 2);
        assertEq(amountToWithdraw, 25_000 / 4);

        // Alice now withdraws again after year 3
        tokenUnlockingAlice.withdraw();
        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingAlice.getMyGrantSummary(Alice);

        assertEq(amountVested, 25_000);
        assertEq(amountUnlocked, (25_000 / 2) + (25_000 / 4));
        assertEq(amountWithdrawn, (25_000 / 2) + (25_000 / 4));
        assertEq(amountToWithdraw, 0);

        // 4 year elapsed, 100% of that 25K shall be unlocked
        vm.warp(tgeTimestamp + 4 * 365 days + 1);

        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingAlice.getMyGrantSummary(Alice);

        assertEq(amountVested, 25_000);
        assertEq(amountUnlocked, 25_000);
        assertEq(amountWithdrawn, (25_000 / 2) + (25_000 / 4));
        assertEq(amountToWithdraw, 25_000 / 4);

        // Alice now withdraws again after year 3
        tokenUnlockingAlice.withdraw();
        (amountVested, amountUnlocked, amountWithdrawn, amountToWithdraw) =
            tokenUnlockingAlice.getMyGrantSummary(Alice);

        assertEq(amountVested, 25_000);
        assertEq(amountUnlocked, 25_000);
        assertEq(amountWithdrawn, 25_000);
        assertEq(amountToWithdraw, 0);

        vm.stopPrank();
    }

    function deployProxy(address impl, bytes memory data) public returns (address proxy) {
        proxy = address(new ERC1967Proxy(impl, data));

        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
