// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

library LibZKP {
    /*********************
     * Public Functions  *
     *********************/

    function verify(
        address plonkVerifier,
        bytes calldata zkproof,
        bytes32 instance
    ) internal view returns (bool verified) {
        (bool isCallSuccess, bytes memory response) = plonkVerifier.staticcall(
            bytes.concat(
                bytes16(0),
                bytes16(instance), // left 16 bytes of the given instance
                bytes16(0),
                bytes16(uint128(uint256(instance))), // right 16 bytes of the given instance
                zkproof
            )
        );

        return isCallSuccess && bytes32(response) == keccak256("taiko");
    }
}
