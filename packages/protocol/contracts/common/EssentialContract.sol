// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "./AddressResolver.sol";
import "./OwnerUUPSUpgradable.sol";

abstract contract EssentialContract is OwnerUUPSUpgradable, AddressResolver {
    uint256[50] private __gap;

    /// @dev Modifier that ensures the caller is the owner or resolved address of a given name.
    /// @param name The name to check against.
    modifier onlyFromOwnerOrNamed(bytes32 name) {
        if (msg.sender != owner() && msg.sender != resolve(name, true)) revert RESOLVER_DENIED();
        _;
    }

    /// @notice Initializes the contract with an address manager.
    /// @param _addressManager The address of the address manager.
    // solhint-disable-next-line func-name-mixedcase
    function _Essential_init(address _addressManager) internal virtual {
        _OwnerUUPSUpgradable_init();
        _AddressResolver_init(_addressManager);
    }

    /// @notice Initializes the contract with an address manager.
    // solhint-disable-next-line func-name-mixedcase
    function _Essential_init() internal virtual {
        _Essential_init(address(0));
    }
}
