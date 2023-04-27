// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

// solhint-disable-next-line max-line-length
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {AddressResolver} from "./AddressResolver.sol";

/**
 * @dev This abstract contract serves as the base contract for many core
 *      components in this package.
 */
abstract contract EssentialContract is
    ReentrancyGuardUpgradeable,
    AddressResolver
{
    function _init(address _addressManager) internal virtual override {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        AddressResolver._init(_addressManager);
    }
}
