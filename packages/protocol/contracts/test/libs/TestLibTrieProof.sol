// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {LibTrieProof} from "../../libs/LibTrieProof.sol";

contract TestLibTrieProof {
    function writeStorageAt(bytes32 slot, bytes32 val) public {
        assembly {
            sstore(slot, val)
        }
    }
}
