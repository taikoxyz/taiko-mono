// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../libs/LibAnchorSignature.sol";

library TestLibAnchorSignature {
    function signTransaction(
        bytes32 digest,
        uint8 k
    ) public view returns (uint8 v, uint256 r, uint256 s) {
        return LibAnchorSignature.signTransaction(digest, k);
    }

    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address) {
        return ecrecover(hash, v, r, s);
    }

    function goldenTouchAddress() public pure returns (address, uint256) {
        return (
            LibAnchorSignature.K_GOLDEN_TOUCH_ADDRESS,
            LibAnchorSignature.K_GOLDEN_TOUCH_PRIVATEKEY
        );
    }
}
