// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";

import { ReentrancyGuardUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import { AddressResolver } from "./AddressResolver.sol";

/// @title EssentialContract
/// @notice This contract serves as the base contract for many core components.
abstract contract EssentialContract is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    AddressResolver
{
    /// @notice Initializes the contract with an address manager.
    /// @param _addressManager The address of the address manager.
    function _init(address _addressManager) internal virtual override {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init_unchained();
        OwnableUpgradeable.__Ownable_init_unchained();
        PausableUpgradeable.__Pausable_init_unchained();
        AddressResolver._init(_addressManager);
    }

    function pause() external whenNotPaused onlyOwner {
        super._pause();
    }

    function unpause() external whenPaused onlyOwner {
        super._unpause();
    }
}
