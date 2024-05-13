// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Minimal Blacklist Interface
/// @dev Mainnet blacklist: 0x97044531D0fD5B84438499A49629488105Dc58e6
interface IMinimalBlacklist {
    function isBlacklisted(address _account) external view returns (bool);
}
