// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

/**
 * @author dantaik <dan@taiko.xyz>
 * @notice Interface to set and get an address for a name.
 */
interface IAddressManager {
    /**
     * @notice Associate an address to a name.
     * @dev The original address associated with the name, if exists, will be
     *      replaced.
     * @param name The name which an address will be associated with.
     * @param addr The address to be associated with the given name.
     */
    function setAddress(string memory name, address addr) external;

    /**
     * @notice Returns the address associated with the given name.
     * @param name The name for which an address will be returned.
     * @return The address associated with the given name. If no address is
     *        found, `address(0)` will be returned.
     */
    function getAddress(string memory name) external view returns (address);
}
