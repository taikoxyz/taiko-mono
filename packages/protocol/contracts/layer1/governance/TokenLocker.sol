// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title TokenLocker
/// @notice A contract for locking and unlocking tokens with a linear release schedule.
/// @dev This contract regulates the spending rate of TAIKO tokens to prevent the DAO from being
/// exploited by malicious key opinion leaders (KOLs) who might rapidly deplete the TAIKO token
/// treasury.
/// The contract is intentionally designed to be non-upgradable and should be owned by the
/// IntermediateOwner contract.
/// @custom:security-contact security@taiko.xyz
contract TokenLocker is Ownable, ReentrancyGuard {
    error AlreadyInitialized();
    error AmountIsZero();
    error InsufficientUnlocked();
    error InvalidDuration();
    error InvalidRecipient();
    error InvalidToken();
    error NotInitialized();
    error TransferFailed();

    IERC20 public immutable token;
    uint256 public immutable duration;
    uint256 public immutable startTime;
    uint256 public immutable endTime;

    uint256 public totalLocked;
    uint256 public totalUnlocked;

    bool public initialized;

    constructor(address _token, uint256 _durationYears) {
        require(_token != address(0), InvalidToken());
        require(_durationYears != 0, InvalidDuration());
        token = IERC20(_token);
        startTime = block.timestamp;
        endTime = startTime + _durationYears * 365 days;
    }

    function lock(uint256 amount) external onlyOwner nonReentrant {
        require(!initialized, AlreadyInitialized());
        require(amount != 0, AmountIsZero());

        initialized = true;
        totalLocked = amount;

        require(token.transferFrom(msg.sender, address(this), amount), TransferFailed());
    }

    function unlock(address recipient, uint256 amount) external onlyOwner nonReentrant {
        require(initialized, NotInitialized());
        require(recipient != address(0) && recipient != address(this), InvalidRecipient());
        require(amount <= unlockedAmount() - totalUnlocked, InsufficientUnlocked());

        totalUnlocked += amount;
        require(token.transfer(recipient, amount), TransferFailed());
    }

    function unlockedAmount() public view returns (uint256) {
        if (!initialized) return 0;
        if (block.timestamp >= endTime) return totalLocked;

        uint256 elapsed = block.timestamp - startTime;
        return (totalLocked * elapsed) / (endTime - startTime);
    }

    function lockedAmount() external view returns (uint256) {
        return totalLocked - totalUnlocked;
    }
}
