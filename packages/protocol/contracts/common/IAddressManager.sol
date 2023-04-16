// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

/**
 * @notice Interface to set and get an address for a name.
 */
interface IAddressManager {
    /**
     * Changes the address associated with a particular name.
     * @param class Uint256 class to assiciate an address with.
     * @param name String name to associate an address with.
     * @param newAddress Address to associate with the name.
     */
    function setAddress(
        uint256 class,
        string memory name,
        address newAddress
    ) external;

    /**
     * Retrieves the address associated with a given name.
     * @param class Class to retrieve an address for.
     * @param name Name to retrieve an address for.
     * @return Address associated with the given name.
     */
    function getAddress(
        uint256 class,
        string memory name
    ) external view returns (address);
}
