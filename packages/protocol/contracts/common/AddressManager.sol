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

import "./IAddressManager.sol";
import "./EssentialContract.sol";

/// @title AddressManager
/// @notice Manages a mapping of chainId-name pairs to Ethereum addresses.
contract AddressManager is EssentialContract, IAddressManager {
    mapping(uint256 => mapping(bytes32 => address)) private addresses;
    uint256[49] private __gap;

    event AddressSet(
        uint64 indexed chainId, bytes32 indexed name, address newAddress, address oldAddress
    );

    error AM_INVALID_PARAMS();
    error AM_UNSUPPORTED();
    /// @notice Initializes the owner for the upgradable contract.

    function init() external initializer {
        __Essential_init();
    }

    /// @notice Sets the address for a specific chainId-name pair.
    /// @param chainId The chainId to which the address will be mapped.
    /// @param name The name to which the address will be mapped.
    /// @param newAddress The Ethereum address to be mapped.
    function setAddress(
        uint64 chainId,
        bytes32 name,
        address newAddress
    )
        external
        virtual
        onlyOwner
    {
        address oldAddress = addresses[chainId][name];
        if (newAddress == oldAddress) revert AM_INVALID_PARAMS();
        addresses[chainId][name] = newAddress;
        emit AddressSet(chainId, name, newAddress, oldAddress);
    }

    /// @inheritdoc IAddressManager
    function getAddress(uint64 chainId, bytes32 name) public view override returns (address) {
        return addresses[chainId][name];
    }

    function _authorizePause(address) internal pure override {
        revert AM_UNSUPPORTED();
    }
}
