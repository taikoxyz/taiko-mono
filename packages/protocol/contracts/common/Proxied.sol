// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

/// @title Proxied
/// @dev Extends OpenZeppelin's Initializable for upgradeable contracts.
/// Intended as the base class for contracts used with
/// TransparentUpgradeableProxy.
///
/// @dev For each chain, deploy Proxied contracts with unique deployers to
/// ensure distinct contract addresses.
abstract contract Proxied is Initializable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
}
