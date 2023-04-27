// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

/* External Imports */
import {AddressManager} from "../common/AddressManager.sol";

/**
 * @title ExampleStaticAddressManager
 */
contract ExampleStaticAddressManager is AddressManager {
    function setAddress(
        uint256 /*domain*/,
        bytes32 /*nameHash*/,
        address /*newAddress*/
    ) external pure override {
        revert("");
    }

    function getAddress(
        uint256 domain,
        bytes32 nameHash
    ) external pure override returns (address addr) {
        if (domain == 1) {
            if (nameHash == "ether_vault") addr = address(0x123);
        } else if (domain == 167) {
            if (nameHash == "taiko") addr = address(0x456);
        }
    }
}
