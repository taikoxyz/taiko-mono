// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "../TaikoData.sol";

/// @title IVerifier Interface
/// @notice Defines the function that handles proof verification.
interface IVerifier {
    struct Input {
        bytes32 metaHash;
        bytes32 blobHash;
        address prover;
        uint64 blockId;
        bool isContesting;
        bool blobUsed;
    }

    function verifyProof(
        Input calldata input,
        TaikoData.TransitionClaim calldata claim,
        TaikoData.TierProof calldata tproof
    )
        external;
}
