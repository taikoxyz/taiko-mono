// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

/**
 * This library offers address-related methods.
 * @author dantaik <dan@taiko.xyz>
 */
library LibAddress {
    /**
     * Sends Ether to an address. Zero-value will also be sent.
     * See more information at:
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now.
     * @param to The target address.
     * @param amount The amount of Ether to send.
     */
    function sendEther(address to, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = payable(to).call{value: amount}("");
            require(success, "ETH transfer failed");
        }
    }

    function codeHash(address addr) internal view returns (bytes32 codehash) {
        assembly {
            codehash := extcodehash(addr)
        }
    }
}
