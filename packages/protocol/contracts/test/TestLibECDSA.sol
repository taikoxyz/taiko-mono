// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibECDSA.sol";

library TestLibECDSA {
    function signWithGoldFingerUseK(bytes32 digest, uint8 k)
        public
        view
        returns (
            uint8 v,
            uint256 r,
            uint256 s
        )
    {
        return LibECDSA.signWithGoldFingerUseK(digest, k);
    }

    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address) {
        return ecrecover(hash, v, r, s);
    }

    function TAIKO_GOLDFINGER_ADDRESS() public pure returns (address) {
        return LibECDSA.TAIKO_GOLDFINGER_ADDRESS;
    }

    function TAIKO_GOLDFINGURE_PRIVATEKEY() public pure returns (uint256) {
        return LibECDSA.TAIKO_GOLDFINGURE_PRIVATEKEY;
    }

    function GX() public pure returns (uint256) {
        return LibECDSA.GX;
    }

    function GY() public pure returns (uint256) {
        return LibECDSA.GY;
    }

    function GX2() public pure returns (uint256) {
        return LibECDSA.GX2;
    }

    function GY2() public pure returns (uint256) {
        return LibECDSA.GY2;
    }
}
