// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressManager} from "./AddressManager.sol";
import {Proxied} from "./Proxied.sol";

/**
 * @title A3StaticAddressManager
 * Such a static lookup AddressManager can be used to replace
 * existing storage-based lookup AddressManager so we can avoid
 * SSLOAD easily.
 */
contract A3StaticAddressManager is AddressManager {
    function setAddress(uint256, /*domain*/ bytes32, /*nameHash*/ address /*newAddress*/ )
        external
        pure
        override
    {
        revert("setAddress disabled");
    }

    /// @dev This function must be a pure function in order to avoid
    /// reading from storage.
    function getAddress(uint256 domain, bytes32 name)
        external
        pure
        override
        returns (address addr)
    {
        if (domain == 11155111) {
            if (name == "oracle_prover") addr = address(0x1567CDAb5F7a69154e61A16D8Ff5eE6A3e991b39);
            if (name == "system_prover") addr = address(0xE09e4fF4353fbf984F99fa824524277F704e7475);
            if (name == "taiko_token") addr = address(0x1c1141c6D94895b38c9472E8469aa56483b646BB);
            if (name == "taiko") addr = address(0x487C41e565DA0d96f5C4b7D8F2e1122B466ef348);
            if (name == "proto_broker") addr = address(0x487C41e565DA0d96f5C4b7D8F2e1122B466ef348);
            if (name == "bridge") addr = address(0xb5b16B80d9426021852dA4D19418b9a4d43CE490);
            if (name == "token_vault") addr = address(0x7A20a9d727280db9f059A15D551E4964c41EA487);
            if (name == "signal_service") {
                addr = address(0x8DcE72C7f9548FFd2225FEA9b2d56e84d1Da1258);
            }
            if (name == bytes32(uint256(0x1000000))) {
                addr = address(0x23CD36D723D1ecD3c4F8d53A0CD4BE7e67759778);
            }
        } else if (domain == 167005) {
            if (name == "taiko") addr = address(0x0000777700000000000000000000000000000001);
            if (name == "token_vault") addr = address(0x0000777700000000000000000000000000000002);
            if (name == "bridge") addr = address(0x0000777700000000000000000000000000000004);
            if (name == "signal_service") {
                addr = address(0x0000777700000000000000000000000000000006);
            }
            if (name == "treasury") addr = address(0xdf09A0afD09a63fb04ab3573922437e1e637dE8b);
        }
    }
}

contract ProxiedA3StaticAddressManager is Proxied, A3StaticAddressManager {}
