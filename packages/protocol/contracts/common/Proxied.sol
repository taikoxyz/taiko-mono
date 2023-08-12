// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Initializable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title Proxied
/// @dev This abstract contract extends Initializable from OpenZeppelin's
/// upgradeable contracts library. It is intended to be used for proxy pattern
/// implementations where constructors are non-traditional.
abstract contract Proxied is Initializable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
}
