// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EssentialContract.sol";
import "./ResolverBase.sol";

import "./DefaultResolver_Layout.sol"; // DO NOT DELETE

/// @title DefaultResolver
/// @notice Storage-based address resolver.
/// @custom:security-contact security@taiko.xyz
contract DefaultResolver is EssentialContract, ResolverBase {
    /// @dev Mapping of chainId to mapping of name to address.
    mapping(uint256 chainId => mapping(bytes32 name => address addr)) private __addresses;

    uint256[49] private __gap;

    /// @notice Emitted when an address is registered.
    /// @param chainId The chainId for the address mapping.
    /// @param name The name for the address mapping.
    /// @param newAddress The new address.
    /// @param oldAddress The old address.
    event AddressRegistered(
        uint256 indexed chainId, bytes32 indexed name, address newAddress, address oldAddress
    );

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Registers an address for a specific chainId-name pair.
    /// @param _chainId The chainId to which the address will be mapped.
    /// @param _name The name to which the address will be mapped.
    /// @param _newAddress The Ethereum address to be mapped.
    function registerAddress(
        uint256 _chainId,
        bytes32 _name,
        address _newAddress
    )
        external
        virtual
        onlyOwner
    {
        address oldAddress = __addresses[_chainId][_name];
        __addresses[_chainId][_name] = _newAddress;
        emit AddressRegistered(_chainId, _name, _newAddress, oldAddress);
    }

    /// @notice Returns the address of this contract.
    /// @return The address of this contract.
    function resolver() public view override returns (address) {
        return address(this);
    }

    function getAddress(
        uint256 _chainId,
        bytes32 _name
    )
        internal
        view
        override
        returns (address)
    {
        return __addresses[_chainId][_name];
    }

    function _authorizePause(address, bool) internal pure override notImplemented { }
}
