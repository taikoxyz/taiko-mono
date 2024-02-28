// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./IAddressManager.sol";
import "./EssentialContract.sol";

/// @title AddressManager
/// @notice See the documentation in {IAddressManager}.
/// @custom:security-contact security@taiko.xyz
contract AddressManager is EssentialContract, IAddressManager {
    mapping(uint256 chainId => mapping(bytes32 name => address addr)) private addresses;
    uint256[49] private __gap;

    event AddressSet(
        uint64 indexed chainId, bytes32 indexed name, address newAddress, address oldAddress
    );

    error AM_INVALID_PARAMS();
    error AM_UNSUPPORTED();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
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
