// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";
import "src/layer1/governance/TokenLocker.sol";
import "test/mocks/TestERC20.sol";

contract TestTokenLocker is Test {
    TestERC20 private token;
    TokenLocker private tokenLocker;
    address private owner;
    address private recipient;

    function setUp() public {
        owner = address(this);
        recipient = address(0x123);
        token = new TestERC20("Test Token", "TTK");
        tokenLocker = new TokenLocker(address(token), 1); // 1 year duration

        // Mint tokens to the owner
        token.mint(owner, 1000 ether);
    }

    function testLock() public {
        uint256 amount = 500 ether;

        // Approve the token transfer
        token.approve(address(tokenLocker), amount);

        // Lock the tokens
        tokenLocker.lock(amount);

        // Check the total locked amount
        assertEq(tokenLocker.totalLocked(), amount);

        // Check the token balance of the contract
        assertEq(token.balanceOf(address(tokenLocker)), amount);
    }

    function testUnlock() public {
        uint256 lockAmount = 500 ether;
        uint256 unlockAmount = 100 ether;

        // Approve the token transfer
        token.approve(address(tokenLocker), lockAmount);

        // Lock the tokens
        tokenLocker.lock(lockAmount);

        // Fast forward time to unlock some tokens
        vm.warp(block.timestamp + 180 days); // 6 months

        // Unlock the tokens
        tokenLocker.unlock(recipient, unlockAmount);

        // Check the total unlocked amount
        assertEq(tokenLocker.totalUnlocked(), unlockAmount);

        // Check the token balance of the recipient
        assertEq(token.balanceOf(recipient), unlockAmount);
    }

    function testUnlockedAmount() public {
        uint256 lockAmount = 500 ether;

        // Approve the token transfer
        token.approve(address(tokenLocker), lockAmount);

        // Lock the tokens
        tokenLocker.lock(lockAmount);

        // Fast forward time to unlock some tokens
        vm.warp(block.timestamp + 180 days); // 6 months

        // Check the unlocked amount
        uint256 expectedUnlocked = (lockAmount * 180 days) / (365 days);
        assertEq(tokenLocker.unlockedAmount(), expectedUnlocked);
    }

    function testLockedAmount() public {
        uint256 lockAmount = 500 ether;
        uint256 unlockAmount = 100 ether;

        // Approve the token transfer
        token.approve(address(tokenLocker), lockAmount);

        // Lock the tokens
        tokenLocker.lock(lockAmount);

        // Fast forward time to unlock some tokens
        vm.warp(block.timestamp + 180 days); // 6 months

        // Unlock the tokens
        tokenLocker.unlock(recipient, unlockAmount);

        // Check the locked amount
        uint256 expectedLocked = lockAmount - unlockAmount;
        assertEq(tokenLocker.lockedAmount(), expectedLocked);
    }

    function testLockZeroAmount() public {
        uint256 amount = 0;

        // Approve the token transfer
        token.approve(address(tokenLocker), amount);

        // Attempt to lock zero tokens and expect a revert
        vm.expectRevert(TokenLocker.AmountIsZero.selector);
        tokenLocker.lock(amount);
    }

    function testUnlockWithoutInitialization() public {
        uint256 unlockAmount = 100 ether;

        // Attempt to unlock tokens without initialization and expect a revert
        vm.expectRevert(TokenLocker.NotInitialized.selector);
        tokenLocker.unlock(recipient, unlockAmount);
    }

    function testUnlockMoreThanUnlocked() public {
        uint256 lockAmount = 500 ether;
        uint256 unlockAmount = 600 ether;

        // Approve the token transfer
        token.approve(address(tokenLocker), lockAmount);

        // Lock the tokens
        tokenLocker.lock(lockAmount);

        // Fast forward time to unlock some tokens
        vm.warp(block.timestamp + 180 days); // 6 months

        // Attempt to unlock more tokens than available and expect a revert
        vm.expectRevert(TokenLocker.InsufficientUnlocked.selector);
        tokenLocker.unlock(recipient, unlockAmount);
    }

    function testUnlockAllAfterEndTime() public {
        uint256 lockAmount = 500 ether;

        token.approve(address(tokenLocker), lockAmount);
        tokenLocker.lock(lockAmount);

        vm.warp(block.timestamp + 366 days); // After endTime

        tokenLocker.unlock(recipient, lockAmount);
        assertEq(token.balanceOf(recipient), lockAmount);
    }

    function testUnlockToSelfReverts() public {
        uint256 lockAmount = 500 ether;

        token.approve(address(tokenLocker), lockAmount);
        tokenLocker.lock(lockAmount);

        vm.warp(block.timestamp + 180 days);

        vm.expectRevert(TokenLocker.InvalidRecipient.selector);
        tokenLocker.unlock(address(tokenLocker), 100 ether);
    }
}
