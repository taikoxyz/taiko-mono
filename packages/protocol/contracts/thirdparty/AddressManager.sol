// SPDX-License-Identifier: MIT
// Taken from https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts/contracts/libraries/resolver/LibAddressManager.sol
// Modified:
//   - contract name `LibAddressManager` modified to `AddressManager` to obey `lint:sol`
//   - `Ownable.sol` modified to `OwnableUpgradeable.sol`
//   - `init()` added to initialize
//   - `setAddress` modified to `addAddress` to conform to ABI of `IAddressManager.sol`
// (The MIT License)
//
// Copyright 2020-2021 Optimism
// Copyright 2022-2023 Taiko Labs
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

pragma solidity ^0.8.18;

/* External Imports */
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../common/IAddressManager.sol";

/**
 * @title AddressManager
 */
contract AddressManager is OwnableUpgradeable, IAddressManager {
    /*************
     * Variables *
     *************/

    mapping(uint256 domain => mapping(string nameHash => address addr))
        private addresses;

    /**********
     * Events *
     **********/

    event AddressSet(
        uint256 indexed _domain,
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
     * @param domain Uint256 domain to assiciate an address with.
     * @param name String name to associate an address with.
     * @param newAddress Address to associate with the name.
     */
    function setAddress(
        uint256 domain,
        string memory name,
        address newAddress
    ) external onlyOwner {
        address oldAddress = addresses[domain][name];
        addresses[domain][name] = newAddress;
        emit AddressSet(domain, name, newAddress, oldAddress);
    }

    /********************
     * Public Functions *
     ********************/

    /**
     * Retrieves the address associated with a given name.
     * @param domain Class to retrieve an address for.
     * @param name Name to retrieve an address for.
     * @return addr Address associated with the given name.
     */
    function getAddress(
        uint256 domain,
        string memory name
    ) external view returns (address addr) {
        addr = addresses[domain][name];
    }
}
