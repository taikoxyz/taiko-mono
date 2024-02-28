// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoData.sol";

/// @title IVerifier Interface
/// @custom:security-contact security@taiko.xyz
/// @notice Defines the function that handles proof verification.
interface IVerifier {
    struct Context {
        bytes32 metaHash;
        bytes32 blobHash;
        address prover;
        uint64 blockId;
        bool isContesting;
        bool blobUsed;
        address msgSender;
    }

    function verifyProof(
        Context calldata ctx,
        TaikoData.Transition calldata tran,
        TaikoData.TierProof calldata proof
    )
        external;
}
