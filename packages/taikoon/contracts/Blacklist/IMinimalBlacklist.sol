// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IMinimalBlacklist {
    function isBlacklisted(address _account) external view returns (bool);
}
