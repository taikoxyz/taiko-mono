// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { USDCFaucet } from "src/shared/faucet/USDCFaucet.sol";
import { ICircleFiatToken } from "src/shared/thirdparty/ICircleFiatToken.sol";
import { CircleArtifactTestBase } from "test/shared/helpers/CircleArtifactTestBase.sol";

contract TestUSDCFaucet is Test, CircleArtifactTestBase {
    address private constant FAUCET_OWNER = 0x6000000000000000000000000000000000000006;
    address private constant RECIPIENT = 0x7000000000000000000000000000000000000007;

    uint256 private constant INITIAL_CLAIM_AMOUNT = 1_000_000;

    USDCFaucet private faucet;
    ICircleFiatToken private token;

    function setUp() public {
        (, address proxy) = _deployTestUSDC();
        token = ICircleFiatToken(proxy);
        faucet = new USDCFaucet(proxy, FAUCET_OWNER, INITIAL_CLAIM_AMOUNT);

        vm.prank(MASTER_MINTER);
        token.configureMinter(address(faucet), type(uint256).max);
    }

    function test_claim_mints_and_sets_cooldown() public {
        uint256 nextClaimAt = block.timestamp + faucet.CLAIM_COOLDOWN();

        vm.prank(RECIPIENT);
        faucet.claim();

        assertEq(token.balanceOf(RECIPIENT), INITIAL_CLAIM_AMOUNT);
        assertEq(faucet.nextClaimAt(RECIPIENT), nextClaimAt);
    }

    function test_claim_reverts_during_cooldown() public {
        vm.prank(RECIPIENT);
        faucet.claim();

        vm.prank(RECIPIENT);
        vm.expectRevert(abi.encodeWithSelector(USDCFaucet.FAUCET_COOLDOWN_ACTIVE.selector, block.timestamp + 1 days));
        faucet.claim();
    }

    function test_claim_succeeds_again_after_cooldown() public {
        vm.prank(RECIPIENT);
        faucet.claim();

        vm.warp(block.timestamp + faucet.CLAIM_COOLDOWN());

        vm.prank(RECIPIENT);
        faucet.claim();

        assertEq(token.balanceOf(RECIPIENT), INITIAL_CLAIM_AMOUNT * 2);
    }

    function test_set_claim_amount_is_used_for_future_claims() public {
        vm.prank(FAUCET_OWNER);
        faucet.setClaimAmount(2_500_000);

        vm.prank(RECIPIENT);
        faucet.claim();

        assertEq(token.balanceOf(RECIPIENT), 2_500_000);
    }

    function test_withdraw_usdc_transfers_existing_balance() public {
        vm.prank(MASTER_MINTER);
        token.configureMinter(address(this), type(uint256).max);
        token.mint(address(faucet), 3_000_000);

        vm.prank(FAUCET_OWNER);
        faucet.withdrawUSDC(RECIPIENT, 3_000_000);

        assertEq(token.balanceOf(address(faucet)), 0);
        assertEq(token.balanceOf(RECIPIENT), 3_000_000);
    }

    function test_constructor_reverts_on_zero_token() public {
        vm.expectRevert(USDCFaucet.FAUCET_INVALID_TOKEN.selector);
        new USDCFaucet(address(0), FAUCET_OWNER, INITIAL_CLAIM_AMOUNT);
    }

    function test_constructor_reverts_on_zero_owner() public {
        vm.expectRevert(USDCFaucet.FAUCET_INVALID_OWNER.selector);
        new USDCFaucet(address(token), address(0), INITIAL_CLAIM_AMOUNT);
    }

    function test_constructor_reverts_on_zero_claim_amount() public {
        vm.expectRevert(USDCFaucet.FAUCET_INVALID_CLAIM_AMOUNT.selector);
        new USDCFaucet(address(token), FAUCET_OWNER, 0);
    }
}
