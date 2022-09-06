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
    function TAIKO_GOLDFINGER_ADDRESS() public pure returns (address) {
        return LibECDSA.TAIKO_GOLDFINGER_ADDRESS;
    }

    function TAIKO_GOLDFINGURE_PRIVATEKEY() public pure returns (uint256) {
        return LibECDSA.TAIKO_GOLDFINGURE_PRIVATEKEY;
    }

    function signWithGoldenFinger(bytes memory digest)
        public
        view
        returns (
            uint8 v,
            uint256 r,
            uint256 s
        )
    {
        return LibECDSA.signWithGoldenFinger(digest);
    }
}
