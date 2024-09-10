// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../TaikoL2.sol";

/// @title HeklaTaikoL2
/// @custom:security-contact security@taiko.xyz
contract HeklaTaikoL2 is TaikoL2 {
    function ontakeForkHeight() public pure override returns (uint64) {
        return 840_512;
    }
}
