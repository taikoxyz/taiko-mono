// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC165Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

/**
 * This library offers address-related methods.
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
        if (amount == 0 || to == address(0)) return;
        (bool success,) = payable(to).call{ value: amount }("");
        require(success, "ETH transfer failed");
    }

    function codeHash(address addr) internal view returns (bytes32 codehash) {
        assembly {
            codehash := extcodehash(addr)
        }
    }

    function supportsInterface(
        address addr,
        bytes4 interfaceId
    )
        internal
        view
        returns (bool result)
    {
        try IERC165Upgradeable(addr).supportsInterface(interfaceId) returns (
            bool _result
        ) {
            result = _result;
        } catch { }
    }
}
