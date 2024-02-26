// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
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

    modifier initEssential(address _owner, address _addressManager) {
        __Essential_init(_addressManager);
        // owner == msg.sender
        _;

        if (_owner != address(0) && _owner != owner()) {
            _transferOwnership(_owner);
        }
    }

    /// @notice Initializes the contract with an address manager.
    /// @param _addressManager The address of the address manager.
    // solhint-disable-next-line func-name-mixedcase
    function __Essential_init(address _addressManager) internal virtual onlyInitializing {
        __OwnerUUPSUpgradable_init();
        __AddressResolver_init(_addressManager);
    }

    /// @notice Initializes the contract without an address manager.
    // solhint-disable-next-line func-name-mixedcase
    function __Essential_init() internal virtual onlyInitializing {
        __Essential_init(address(0));
    }
}
