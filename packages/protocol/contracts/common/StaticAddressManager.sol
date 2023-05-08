// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Proxied} from "./Proxied.sol";
import {AddressManager} from "./AddressManager.sol";

/// @custom:security-contact hello@taiko.xyz
contract StaticAddressManager is AddressManager {
    error DISABLED();

    function setAddress(
        uint256 /*domain*/,
        bytes32 /*name*/,
        address /*newAddress*/
    ) external pure override {
        revert DISABLED();
    }

    function getAddress(
        uint256 domain,
        bytes32 name
    ) public pure override returns (address) {
        if (domain == 1) {
            if (name == bytes32("bridge")) {
                return address(0x0000001);
            } else if (name == bytes32("taiko")) {
                return address(0x0000002);
            }
        } else if (domain == 167) {
            if (name == bytes32("bridge")) {
                return address(0x0000011);
            } else if (name == bytes32("taiko")) {
                return address(0x0000012);
            }
        }
        return address(0x0);
    }
}

contract ProxiedStaticAddressManager is Proxied, StaticAddressManager {}
