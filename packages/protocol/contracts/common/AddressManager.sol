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
 * @notice Interface to set and get an address for a name.
 */
interface IAddressManager {
    /**
     * Changes the address associated with a particular name.
     * @param domain Uint256 domain to assiciate an address with.
     * @param name Name to associate an address with.
     * @param newAddress Address to associate with the name.
     */
    function setAddress(
        uint256 domain,
        bytes32 name,
        address newAddress
    )
        external;

    /**
     * Retrieves the address associated with a given name.
     * @param domain Class to retrieve an address for.
     * @param name Name to retrieve an address for.
     * @return Address associated with the given name.
     */
    function getAddress(
        uint256 domain,
        bytes32 name
    )
        external
        view
        returns (address);
}

/// @custom:security-contact hello@taiko.xyz
contract AddressManager is OwnableUpgradeable, IAddressManager {
    mapping(uint256 domain => mapping(bytes32 name => address addr)) private
        addresses;

    event AddressSet(
        uint256 indexed _domain,
        bytes32 indexed _name,
        address _newAddress,
        address _oldAddress
    );

    error EOAOwnerAddressNotAllowed();

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function setAddress(
        uint256 domain,
        bytes32 name,
        address newAddress
    )
        external
        virtual
        onlyOwner
    {
        // This is to prevent using the owner as named address
        if (newAddress.code.length == 0 && newAddress == msg.sender) {
            revert EOAOwnerAddressNotAllowed();
        }

        address oldAddress = addresses[domain][name];
        addresses[domain][name] = newAddress;
        emit AddressSet(domain, name, newAddress, oldAddress);
    }

    function getAddress(
        uint256 domain,
        bytes32 name
    )
        external
        view
        virtual
        returns (address addr)
    {
        addr = addresses[domain][name];
    }
}

contract ProxiedAddressManager is Proxied, AddressManager { }
