// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

/* External Imports */
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @notice Interface to set and get an address for a name.
 */
interface IAddressManager {
    /**
     * Changes the address associated with a particular name.
     * @param domain Uint256 domain to assiciate an address with.
     * @param name String name to associate an address with.
     * @param newAddress Address to associate with the name.
     */
    function setAddress(
        uint256 domain,
        string memory name,
        address newAddress
    ) external;

    /**
     * Retrieves the address associated with a given name.
     * @param domain Class to retrieve an address for.
     * @param name Name to retrieve an address for.
     * @return Address associated with the given name.
     */
    function getAddress(
        uint256 domain,
        string memory name
    ) external view returns (address);
}

/**
 * @title AddressManager
 */
contract AddressManager is OwnableUpgradeable, IAddressManager {
    mapping(uint256 domain => mapping(bytes32 nameHash => address addr))
        private addresses;

    event AddressSet(
        uint256 indexed _domain,
        string indexed _name,
        address _newAddress,
        address _oldAddress
    );

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function setAddress(
        uint256 domain,
        string memory name,
        address newAddress
    ) external onlyOwner {
        address oldAddress = addresses[domain][stringToBytes32(name)];
        addresses[domain][stringToBytes32(name)] = newAddress;
        emit AddressSet(domain, name, newAddress, oldAddress);
    }

    function getAddress(
        uint256 domain,
        string memory name
    ) external view returns (address addr) {
        addr = addresses[domain][stringToBytes32(name)];
    }

    function stringToBytes32(
        string memory source
    ) private pure returns (bytes32 result) {
        if (bytes(source).length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}
