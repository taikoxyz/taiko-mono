// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../libs/LibTrieProof.sol";

contract TestLibTrieProof {
    function writeStorageAt(bytes32 slot, bytes32 val) public {
        assembly {
            sstore(slot, val)
        }
    }

    function verify(
        bytes32 stateRoot,
        address addr,
        bytes32 slot,
        bytes32 value,
        bytes calldata mkproof
    ) public pure returns (bool) {
        return LibTrieProof.verify(stateRoot, addr, slot, value, mkproof);
    }
}
