// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IAddressManager } from "./AddressManager.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title AddressResolver
/// @notice This contract acts as a bridge for name-to-address resolution.
/// It delegates the resolution to the AddressManager. By separating the logic,
/// we can maintain flexibility in address management without affecting the
/// resolving process.
abstract contract AddressResolver {
    IAddressManager internal _addressManager;

    uint256[49] private __gap;

    event AddressManagerChanged(address indexed addressManager);

    error RESOLVER_DENIED();
    error RESOLVER_INVALID_ADDR();
    error RESOLVER_ZERO_ADDR(uint256 chainId, bytes32 name);

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name.
    /// @param name The name to check against.
    modifier onlyFromNamed(bytes32 name) {
        if (msg.sender != resolve(name, true)) revert RESOLVER_DENIED();
        _;
    }

    /// @dev Modifier that ensures the caller is the resolved address of two
    /// given names.
    /// @param name1 The first name to check against.
    /// @param name2 The second name to check against.
    modifier onlyFromNamed2(bytes32 name1, bytes32 name2) {
        if (
            msg.sender != resolve(name1, true)
                && msg.sender != resolve(name2, true)
        ) revert RESOLVER_DENIED();
        _;
    }

    /// @notice Resolves a name to its address on the current chain.
    /// @param name Name whose address is to be resolved.
    /// @param allowZeroAddress If set to true, does not throw if the resolved
    /// address is `address(0)`.
    /// @return addr Address associated with the given name.
    function resolve(
        bytes32 name,
        bool allowZeroAddress
    )
        public
        view
        virtual
        returns (address payable addr)
    {
        return _resolve(block.chainid, name, allowZeroAddress);
    }

    /// @notice Resolves a name to its address on a specified chain.
    /// @param chainId The chainId of interest.
    /// @param name Name whose address is to be resolved.
    /// @param allowZeroAddress If set to true, does not throw if the resolved
    /// address is `address(0)`.
    /// @return addr Address associated with the given name on the specified
    /// chain.
    function resolve(
        uint256 chainId,
        bytes32 name,
        bool allowZeroAddress
    )
        public
        view
        virtual
        returns (address payable addr)
    {
        return _resolve(chainId, name, allowZeroAddress);
    }

    /// @notice Fetches the AddressManager's address.
    /// @return The current address of the AddressManager.
    function addressManager() public view returns (address) {
        return address(_addressManager);
    }

    /// @dev Initialization method for setting up AddressManager reference.
    /// @param addressManager_ Address of the AddressManager.
    function _init(address addressManager_) internal virtual {
        if (addressManager_ == address(0)) revert RESOLVER_INVALID_ADDR();
        _addressManager = IAddressManager(addressManager_);
    }

    /// @dev Helper method to resolve name-to-address.
    /// @param chainId The chainId of interest.
    /// @param name Name whose address is to be resolved.
    /// @param allowZeroAddress If set to true, does not throw if the resolved
    /// address is `address(0)`.
    /// @return addr Address associated with the given name on the specified
    /// chain.
    function _resolve(
        uint256 chainId,
        bytes32 name,
        bool allowZeroAddress
    )
        private
        view
        returns (address payable addr)
    {
        addr = payable(_addressManager.getAddress(chainId, name));

        if (!allowZeroAddress && addr == address(0)) {
            revert RESOLVER_ZERO_ADDR(chainId, name);
        }
    }
}
