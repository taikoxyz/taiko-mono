// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BLS } from "@solady/src/utils/ext/ithaca/BLS.sol";

/// @title LibBLSG1
/// @dev Library for BLS G1Point comparison operations
/// @custom:security-contact security@taiko.xyz
library LibBLSG1 {
    /// @dev Returns true if two G1Points are equal
    function equals(
        BLS.G1Point memory _a,
        BLS.G1Point memory _b
    )
        internal
        pure
        returns (bool)
    {
        return _a.x_a == _b.x_a && _a.x_b == _b.x_b && _a.y_a == _b.y_a && _a.y_b == _b.y_b;
    }
}
