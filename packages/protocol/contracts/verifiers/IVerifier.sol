// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoData.sol";

/// @title IVerifier
/// @notice Defines the function that handles proof verification.
/// @custom:security-contact security@taiko.xyz
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

    /// @notice Verifies a proof.
    /// @param _ctx The context of the proof verification.
    /// @param _tran The transition to verify.
    /// @param _proof The proof to verify.
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external;
}

/// @title SP1 Verifier Interface
/// @author Succinct Labs
/// @notice This interface is for the deployed SP1 Verifier and 100% brought over from :
/// https://github.com/succinctlabs/sp1-contracts/blob/main/contracts/src/ISP1Verifier.sol
interface ISP1Verifier {
    /// @notice Verifies a proof with given public values and vkey.
    /// @dev It is expected that the first 4 bytes of proofBytes must match the first 4 bytes of
    /// target verifier's VERIFIER_HASH.
    /// @param programVKey The verification key for the RISC-V program.
    /// @param publicValues The public values encoded as bytes.
    /// @param proofBytes The proof of the program execution the SP1 zkVM encoded as bytes.
    function verifyProof(
        bytes32 programVKey,
        bytes calldata publicValues,
        bytes calldata proofBytes
    )
        external
        view;
}

interface ISP1VerifierWithHash is ISP1Verifier {
    /// @notice Returns the hash of the verifier.
    function VERIFIER_HASH() external pure returns (bytes32);
}
