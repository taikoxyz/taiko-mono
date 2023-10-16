// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from "@ozu/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
    "@ozu/security/ReentrancyGuardUpgradeable.sol";

import { AddressResolver } from "./AddressResolver.sol";
import { IAddressManager } from "./AddressManager.sol";

/// @title EssentialContract
/// @notice This contract serves as the base contract for many core components.
abstract contract EssentialContract is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    AddressResolver
{
    /// @notice Sets a new address manager.
    /// @param _addressManager Address of the new address manager.
    function setAddressManager(address _addressManager) external onlyOwner {
        if (_addressManager == address(0)) revert RESOLVER_INVALID_MANAGER();
        addressManager = _addressManager;
        emit AddressManagerChanged(_addressManager);
    }

    /// @notice Initializes the contract with an address manager.
    /// @param _addressManager The address of the address manager.
    function _init(address _addressManager) internal virtual override {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        OwnableUpgradeable.__Ownable_init();
        AddressResolver._init(_addressManager);
    }
}
