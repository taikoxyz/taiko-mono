//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Converts a little-endian encoded bytes to a big-endian uint256 integer
 */
library BELE {
    function leBytesToBeUint(bytes memory encoded) internal pure returns (uint256 decoded) {
        for (uint256 i = 0; i < encoded.length; i++) {
            uint256 digits = uint256(uint8(bytes1(encoded[i])));
            uint256 upperDigit = digits / 16;
            uint256 lowerDigit = digits % 16;

            uint256 acc = lowerDigit * (16 ** (2 * i));
            acc += upperDigit * (16 ** ((2 * i) + 1));

            decoded += acc;
        }
    }
}
