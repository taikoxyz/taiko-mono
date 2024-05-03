// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IRateLimiter
/// @custom:security-contact security@taiko.xyz
interface IRateLimiter {
    function consumeAmount(address token, uint256 amount) external;
    function getAvailableAmount(address token) external view returns (uint256);
}
