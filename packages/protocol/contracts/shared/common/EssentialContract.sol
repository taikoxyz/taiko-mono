// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseEssentialContract.sol";

/// @title EssentialContract
/// @custom:security-contact security@taiko.xyz
abstract contract EssentialContract is BaseEssentialContract {
    uint256[49] private __gap;
}
