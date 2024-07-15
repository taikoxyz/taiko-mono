// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Minimal Blacklist Interface
interface IMinimalBlacklist {
    function isBlacklisted(address _account) external view returns (bool);
}
