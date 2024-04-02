// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";

contract MyERC20 is ERC20 {
    constructor(address owner) ERC20("Taiko Token", "TKO") {
        _mint(owner, 1_000_000_000e18);
    }
}

contract MockERC20Airdrop2 is ERC20Airdrop2 {
    function _verifyMerkleProof(
        bytes32[] calldata, /*proof*/
        bytes32, /*merkleRoot*/
        bytes32 /*value*/
    )
        internal
        pure
        override
        returns (bool)
    {
        return true;
    }
}

contract TestERC20Airdrop2 is TaikoTest {
    address public owner = randAddress();

    bytes32 public constant merkleRoot = bytes32(uint256(1));
    bytes32[] public merkleProof;
    uint64 public claimStart;
    uint64 public claimEnd;

    ERC20 token;
    ERC20Airdrop2 airdrop2;

    function setUp() public {
        claimStart = uint64(block.timestamp + 10);
        claimEnd = uint64(block.timestamp + 10_000);
        merkleProof = new bytes32[](3);

        token = new MyERC20(address(owner));

        airdrop2 = ERC20Airdrop2(
            deployProxy({
                name: "MockERC20Airdrop",
                impl: address(new MockERC20Airdrop2()),
                data: abi.encodeCall(
                    ERC20Airdrop2.init,
                    (address(0), claimStart, claimEnd, merkleRoot, address(token), owner, 10 days)
                    )
            })
        );

        vm.prank(owner, owner);
        MyERC20(address(token)).approve(address(airdrop2), 1_000_000_000e18);
        vm.roll(block.number + 1);
    }

    function test_withdraw_for_airdrop2_withdraw_daily() public {
        vm.warp(uint64(block.timestamp + 11));

        vm.prank(Alice, Alice);
        airdrop2.claim(Alice, 100, merkleProof);

        // Try withdraw but not started yet
        vm.expectRevert(ERC20Airdrop2.WITHDRAWALS_NOT_ONGOING.selector);
        airdrop2.withdraw(Alice);

        // Roll one day after another, for 10 days and see the 100 allowance be withdrawn all and no
        // more left for the 11th day
        uint256 i = 1;
        uint256 balance;
        uint256 withdrawable;
        for (i = 1; i < 11; i++) {
            vm.roll(block.number + 200);
            vm.warp(claimEnd + (i * 1 days));

            (balance, withdrawable) = airdrop2.getBalance(Alice);

            assertEq(balance, 100);
            assertEq(withdrawable, 10);

            airdrop2.withdraw(Alice);
            // Check Alice balance
            assertEq(token.balanceOf(Alice), (i * 10));
        }

        // On the 10th day (midnight), Alice has no claims left
        vm.roll(block.number + 200);
        vm.warp(claimEnd + (10 days));

        (balance, withdrawable) = airdrop2.getBalance(Alice);

        assertEq(balance, 100);
        assertEq(withdrawable, 0);

        // No effect
        airdrop2.withdraw(Alice);
        // Check Alice balance
        assertEq(token.balanceOf(Alice), 100);
    }

    function test_withdraw_for_airdrop2_withdraw_at_the_end() public {
        vm.warp(uint64(block.timestamp + 11));

        vm.prank(Alice, Alice);
        airdrop2.claim(Alice, 100, merkleProof);

        // Try withdraw but not started yet
        vm.expectRevert(ERC20Airdrop2.WITHDRAWALS_NOT_ONGOING.selector);
        airdrop2.withdraw(Alice);

        // Roll 10 day after
        vm.roll(block.number + 200);
        vm.warp(claimEnd + 10 days);

        (uint256 balance, uint256 withdrawable) = airdrop2.getBalance(Alice);

        assertEq(balance, 100);
        assertEq(withdrawable, 100);

        airdrop2.withdraw(Alice);

        // Check Alice balance
        assertEq(token.balanceOf(Alice), 100);
    }

    function test_withdraw_for_airdrop2_but_out_of_withdrawal_window() public {
        vm.warp(uint64(block.timestamp + 11));

        vm.prank(Alice, Alice);
        airdrop2.claim(Alice, 100, merkleProof);

        // Try withdraw but not started yet
        vm.expectRevert(ERC20Airdrop2.WITHDRAWALS_NOT_ONGOING.selector);
        airdrop2.withdraw(Alice);

        // Roll 31 day after
        vm.roll(block.number + 200);
        vm.warp(claimEnd + 10 days + 30 days + 1); // withdrawal window + grace period + 1sec

        (uint256 balance, uint256 withdrawable) = airdrop2.getBalance(Alice);

        // Balance and withdrawable is 100,100 --> bc. it is out of withdrawal window
        assertEq(balance, 100);
        assertEq(withdrawable, 100);

        vm.expectRevert(ERC20Airdrop2.WITHDRAWALS_NOT_ONGOING.selector);
        airdrop2.withdraw(Alice);

        // Check Alice balance
        assertEq(token.balanceOf(Alice), 0);
    }
}
