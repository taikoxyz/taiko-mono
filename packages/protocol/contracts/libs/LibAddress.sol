// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { IERC165Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

/// @title LibAddress
/// @dev Provides utilities for address-related operations.
library LibAddress {
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
}
