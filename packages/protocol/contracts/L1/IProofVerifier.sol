// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

interface IProofVerifier {
    /**
     * Verifying proof via the ProofVerifier contract. This function must throw
     * if verificaiton fails.
     *
     * @param blockId BlockId
     * @param blockProofs Raw bytes of proof(s)
     * @param instance Hashed evidence & config data
     */
    function verifyProofs(
        uint256 blockId,
        bytes calldata blockProofs,
        bytes32 instance
    )
        external;
}
