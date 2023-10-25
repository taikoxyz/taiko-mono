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
        this;
    }
}

contract TestTimeLockTokenPool is Test {
    address internal Vault = vm.addr(0x1);
    address internal Alice = vm.addr(0x2);
    address internal Bob = vm.addr(0x3);

    ERC20 tko = new MyERC20(Vault);
    Pool pool = new Pool();

    function setUp() public {
        pool.init(address(tko), Vault);
    }

    function test_invalid_granting() public {
        vm.expectRevert(Pool.INVALID_GRANT.selector);
        pool.grant(Alice, Pool.Grant(0, 0, 0, 0, 0, 0, 0));

        vm.expectRevert(Pool.INVALID_PARAM.selector);
        pool.grant(address(0), Pool.Grant(100e18, 0, 0, 0, 0, 0, 0));
    }

    function test_single_grant() public {
        pool.grant(Alice, Pool.Grant(10_000e18, 0, 0, 0, 0, 0, 0));
        vm.prank(Vault);
        tko.approve(address(pool), 10_000e18);

        (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountWithdrawable
        ) = pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 0);
        assertEq(amountWithdrawable, 10_000e18);

        // Try to void the grant
        vm.expectRevert(Pool.NOTHING_TO_VOID.selector);
        pool.void(Alice);

        vm.prank(Alice);
        pool.withdraw();
        assertEq(tko.balanceOf(Alice), 10_000e18);

        (amountOwned, amountUnlocked, amountWithdrawn, amountWithdrawable) =
            pool.getMyGrantSummary(Alice);
        assertEq(amountOwned, 10_000e18);
        assertEq(amountUnlocked, 10_000e18);
        assertEq(amountWithdrawn, 10_000e18);
        assertEq(amountWithdrawable, 0);
    }
}
