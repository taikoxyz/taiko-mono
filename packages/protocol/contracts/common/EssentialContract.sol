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

abstract contract Essential1StepContract is OwnerUUPSUpgradable, AddressResolver {
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
    function __Essential_init(address _addressManager) internal virtual {
        __OwnerUUPSUpgradable_init();
        __AddressResolver_init(_addressManager);
    }

    /// @notice Initializes the contract without an address manager.
    // solhint-disable-next-line func-name-mixedcase
    function __Essential_init() internal virtual {
        __Essential_init(address(0));
    }
}

abstract contract EssentialContract is Essential1StepContract, Ownable2StepUpgradeable {
    uint256[50] private __gap;

    function transferOwnership(address newOwner)
        public
        virtual
        override(Ownable2StepUpgradeable, OwnableUpgradeable)
    {
        Ownable2StepUpgradeable.transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner)
        internal
        virtual
        override(Ownable2StepUpgradeable, OwnableUpgradeable)
    {
        Ownable2StepUpgradeable._transferOwnership(newOwner);
    }
}
