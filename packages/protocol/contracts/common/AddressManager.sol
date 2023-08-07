// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Proxied } from "./Proxied.sol";

/**
 * @title IAddressManager Interface
 * @dev Specifies methods to manage address mappings for given domain-name
 * pairs.
 */
interface IAddressManager {
    /**
     * @notice Set the address for a specific domain-name pair.
     * @param domain The domain to which the address will be mapped.
     * @param name The name to which the address will be mapped.
     * @param newAddress The Ethereum address to be mapped.
     */
    function setAddress(
        uint256 domain,
        bytes32 name,
        address newAddress
    )
        external;

    /**
     * @notice Get the address mapped to a specific domain-name pair.
     * @param domain The domain for which the address needs to be fetched.
     * @param name The name for which the address needs to be fetched.
     * @return Address associated with the domain-name pair.
     */
    function getAddress(
        uint256 domain,
        bytes32 name
    )
        external
        view
        returns (address);
}

/**
 * @title AddressManager
 * @dev Manages a mapping of domain-name pairs to Ethereum addresses.
 * Only the contract owner can modify these mappings. Address changes
 * are emitted as events.
 */
contract AddressManager is OwnableUpgradeable, IAddressManager {
    mapping(uint256 => mapping(bytes32 => address)) private addresses;

    event AddressSet(
        uint256 indexed domain,
        bytes32 indexed name,
        address newAddress,
        address oldAddress
    );

    error EOA_OWNER_NOT_ALLOWED();

    /**
     * @notice Initializes the owner for the upgradable contract.
     */
    function init() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    /**
     * @notice Maps a domain-name pair to an Ethereum address.
     * @dev Can only be called by the contract owner.
     * @param domain The domain to which the address will be mapped.
     * @param name The name to which the address will be mapped.
     * @param newAddress The Ethereum address to be mapped.
     */
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

    /**
     * @notice Retrieves the address mapped to a domain-name pair.
     * @param domain The domain for which the address needs to be fetched.
     * @param name The name for which the address needs to be fetched.
     * @return Address associated with the domain-name pair.
     */
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

/**
 * @title ProxiedAddressManager
 * @dev Proxied version of the AddressManager contract.
 */
contract ProxiedAddressManager is Proxied, AddressManager { }
