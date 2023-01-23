// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

library LibZKP {
    /*********************
     * Public Functions  *
     *********************/

    function verify(
        address plonkVerifier,
        bytes memory verificationKey,
        bytes calldata zkproof,
        bytes32 blockHash,
        address prover,
        bytes32 txListHash
    ) internal view returns (bool verified) {
        // TODO(david):
        // 1) verificationKey is hard-coded in the generated PlonkVerifier, make it as a configurable parameter.
        // 2) public input is assembled in client software for testing purposes right now, move this part of logic
        //    to here.
        (verified, ) = plonkVerifier.staticcall(zkproof);
    }
}
