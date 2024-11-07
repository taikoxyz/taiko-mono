// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EssentialContract.sol";

/// @title Resolver
/// @notice See the documentation in {IAddressManager}.
/// @custom:security-contact security@taiko.xyz
contract Resolver is EssentialContract, IResolver {
    /// @dev Mapping of chainId to mapping of name to address.
    mapping(uint256 chainId => mapping(bytes32 name => address addr)) private __addresses;

    uint256[49] private __gap;

    /// @notice Emitted when an address is set.
    /// @param chainId The chainId for the address mapping.
    /// @param name The name for the address mapping.
    /// @param newAddress The new address.
    /// @param oldAddress The old address.
    event AddressSet(
        uint64 indexed chainId, bytes32 indexed name, address newAddress, address oldAddress
    );

    error AM_ADDRESS_ALREADY_SET();
    error RESOLVED_ADDRESS_ZERO();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner, address(this));
    }

    /// @notice Sets the address for a specific chainId-name pair.
    /// @param _chainId The chainId to which the address will be mapped.
    /// @param _name The name to which the address will be mapped.
    /// @param _newAddress The Ethereum address to be mapped.
    function setAddress(
        uint64 _chainId,
        bytes32 _name,
        address _newAddress
    )
        external
        virtual
        onlyOwner
    {
        address oldAddress = __addresses[_chainId][_name];
        require(_newAddress != oldAddress, AM_ADDRESS_ALREADY_SET());
        __addresses[_chainId][_name] = _newAddress;
        emit AddressSet(_chainId, _name, _newAddress, oldAddress);
    }

    function resolve(
        uint256 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        external
        view
        returns (address addr_)
    {
        addr_ = __addresses[_chainId][_name];
        require(addr_ != address(0) || _allowZeroAddress, RESOLVED_ADDRESS_ZERO());
    }

    function _authorizePause(address, bool) internal pure override notImplemented { }
}
