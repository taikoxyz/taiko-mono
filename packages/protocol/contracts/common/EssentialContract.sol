// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "./AddressResolver.sol";
import "./OwnerUUPSUpgradable.sol";

abstract contract EssentialContract is OwnerUUPSUpgradable, AddressResolver {
    /// @notice Initializes the contract with an address manager.
    /// @param _addressManager The address of the address manager.
    function _Essential_init(address _addressManager) internal virtual {
        _OwnerUUPSUpgradable_init();
        _AddressResolver_init(_addressManager);
    }
}
