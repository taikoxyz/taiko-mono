// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Proxied } from "./Proxied.sol";

/// @title IAddressManager
/// @notice Specifies methods to manage address mappings for given domain-name
/// pairs.
interface IAddressManager {
    /// @notice Sets the address for a specific domain-name pair.
    /// @param domain The domain to which the address will be mapped.
    /// @param name The name to which the address will be mapped.
    /// @param newAddress The Ethereum address to be mapped.
    function setAddress(
        uint256 domain,
        bytes32 name,
        address newAddress
    )
        external;

    /// @notice Gets the address mapped to a specific domain-name pair.
    /// @param domain The domain for which the address needs to be fetched.
    /// @param name The name for which the address needs to be fetched.
    /// @return Address associated with the domain-name pair.
    function getAddress(
        uint256 domain,
        bytes32 name
    )
        external
        view
        returns (address);
}

/// @title AddressManager
/// @notice Manages a mapping of domain-name pairs to Ethereum addresses.
contract AddressManager is OwnableUpgradeable, IAddressManager {
    mapping(uint256 => mapping(bytes32 => address)) private addresses;

    event AddressSet(
        uint256 indexed domain,
        bytes32 indexed name,
        address newAddress,
        address oldAddress
    );

    error EOA_OWNER_NOT_ALLOWED();

    /// @notice Initializes the owner for the upgradable contract.
    function init() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    /// @inheritdoc IAddressManager
    function setAddress(
        uint256 domain,
        bytes32 name,
        address newAddress
    )
        external
        virtual
        onlyOwner
    {
        if (newAddress.code.length == 0 && newAddress == msg.sender) {
            revert EOA_OWNER_NOT_ALLOWED();
        }

        address oldAddress = addresses[domain][name];
        addresses[domain][name] = newAddress;
        emit AddressSet(domain, name, newAddress, oldAddress);
    }

    /// @inheritdoc IAddressManager
    function getAddress(
        uint256 domain,
        bytes32 name
    )
        external
        view
        virtual
        returns (address)
    {
        return addresses[domain][name];
    }
}

/// @title ProxiedAddressManager
/// @notice Proxied version of the parent contract.
contract ProxiedAddressManager is Proxied, AddressManager { }
