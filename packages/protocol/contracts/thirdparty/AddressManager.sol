// SPDX-License-Identifier: MIT
// Taken from https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts/contracts/libraries/resolver/LibAddressManager.sol
// Modified:
//   - contract name `LibAddressManager` modified to `AddressManager` to obey `lint:sol`
//   - `Ownable.sol` modified to `OwnableUpgradeable.sol`
//   - `init()` added to initialize
//   - `setAddress` modified to `addAddress` to conform to ABI of `IAddressManager.sol`

pragma solidity ^0.8.9;

/* External Imports */
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title AddressManager
 */
contract AddressManager is OwnableUpgradeable {
    /*************
     * Variables *
     *************/

    mapping(bytes32 => address) private addresses;

    /**********
     * Events *
     **********/

    event AddressSet(
        string indexed _name,
        address _newAddress,
        address _oldAddress
    );

    /********************
     * External Functions*
     ********************/

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    /**
     * Changes the address associated with a particular name.
     * @param _name String name to associate an address with.
     * @param _address Address to associate with the name.
     */
    function setAddress(string memory _name, address _address)
        external
        onlyOwner
    {
        bytes32 nameHash = _getNameHash(_name);
        address oldAddress = addresses[nameHash];
        addresses[nameHash] = _address;

        emit AddressSet(_name, _address, oldAddress);
    }

    /********************
     * Public Functions *
     ********************/

    /**
     * Retrieves the address associated with a given name.
     * @param _name Name to retrieve an address for.
     * @return Address associated with the given name.
     */
    function getAddress(string memory _name) external view returns (address) {
        return addresses[_getNameHash(_name)];
    }

    /**********************
     * Internal Functions *
     **********************/

    /**
     * Computes the hash of a name.
     * @param _name Name to compute a hash for.
     * @return Hash of the given name.
     */
    function _getNameHash(string memory _name) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_name));
    }
}
