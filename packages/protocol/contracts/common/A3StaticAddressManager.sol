// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

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
            if (name == "taiko_token") addr = address(0xE52952B8063d0AE6Bd35E894866d8148976ce645);
            if (name == "taiko") addr = address(0x6375394335f34848b850114b66A49D6F47f2cdA8);
            if (name == "proto_broker") addr = address(0x6375394335f34848b850114b66A49D6F47f2cdA8);
            if (name == "bridge") addr = address(0x7D992599E1B8b4508Ba6E2Ba97893b4C36C23A28);
            if (name == "token_vault") addr = address(0xD70506580B5F65e68ed0dbA7B4Ae507641C48197);
            if (name == "signal_service") {
                addr = address(0x23baAc3892a823e9E59B85d6c90068474fe60086);
            }
            if (name == bytes32(uint256(0x1000000))) {
                addr = address(0xd46eb8cF2b47cd99bdb1dD8C76EEc55ac6eb930E);
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
