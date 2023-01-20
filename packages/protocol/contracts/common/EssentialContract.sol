// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// solhint-disable-next-line max-line-length
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./AddressResolver.sol";

/**
 * @author dantaik <dan@taiko.xyz>
 * @dev This abstract contract serves as the base contract for many core
 *      components in this package.
 */
abstract contract EssentialContract is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    AddressResolver
{
    function _init(address _addressManager) internal virtual override {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        OwnableUpgradeable.__Ownable_init();
        AddressResolver._init(_addressManager);
    }
}
