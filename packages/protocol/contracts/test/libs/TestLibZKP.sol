// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibZKP} from "../../libs/LibZKP.sol";

contract TestLibZKP {
    function verify(
        address plonkVerifier,
        bytes calldata zkproof,
        bytes32 instance
    ) public view returns (bool verified) {
        return LibZKP.verify(plonkVerifier, zkproof, instance);
    }
}
