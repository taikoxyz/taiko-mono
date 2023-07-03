// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressManager} from "../common/AddressManager.sol";

/**
 * @title ExampleStaticAddressManager
 * Such a static lookup AddressManager can be used to replace
 * existing storage-based lookup AddressManager so we can avoid
 * SSLOAD easily.
 */
contract ExampleStaticAddressManager is AddressManager {
    function setAddress(uint256, /*domain*/ bytes32, /*nameHash*/ address /*newAddress*/ )
        external
        pure
        override
    {
        revert("");
    }

    /// @dev This function must be a pure function in order to avoid
    /// reading from storage.
    function getAddress(uint256 domain, bytes32 nameHash)
        external
        pure
        override
        returns (address addr)
    {
        if (domain == 1) {
            if (nameHash == "ether_vault") addr = address(0x123);
        } else if (domain == 167) {
            if (nameHash == "taiko") addr = address(0x456);
        }
    }
}
