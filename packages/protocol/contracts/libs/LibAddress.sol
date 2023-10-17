// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressUpgradeable } from "ozu/utils/AddressUpgradeable.sol";
import { ECDSAUpgradeable } from "ozu/utils/cryptography/ECDSAUpgradeable.sol";
import { IERC165Upgradeable } from
    "ozu/utils/introspection/IERC165Upgradeable.sol";
import { IERC1271Upgradeable } from "ozu/interfaces/IERC1271Upgradeable.sol";

/// @title LibAddress
/// @dev Provides utilities for address-related operations.
library LibAddress {
    bytes4 private constant EIP1271_MAGICVALUE = 0x1626ba7e;

    /// @dev Wrap this into a new function so the parameter `to` is `address`
    /// instead of `address payable`.
    function sendEther(address to, uint256 amount) internal {
        AddressUpgradeable.sendValue(payable(to), amount);
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

    function isValidSignature(
        address addr,
        bytes32 hash,
        bytes memory sig
    )
        internal
        view
        returns (bool valid)
    {
        if (
            AddressUpgradeable.isContract(addr)
                && IERC1271Upgradeable(addr).isValidSignature(hash, sig)
                    == EIP1271_MAGICVALUE
        ) {
            valid = true;
        } else if (ECDSAUpgradeable.recover(hash, sig) == addr) {
            valid = true;
        }
    }
}
