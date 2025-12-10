// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProofVerifier
/// @notice Interface for verifying validity proofs for state transitions
/// @custom:security-contact security@taiko.xyz
interface IProofVerifier {
    /// @notice Verifies a validity proof for a state transition
    /// @dev This function must revert if the proof is invalid
    /// @param _proposalAge The age in seconds of the proposal being proven. Only set for
    ///        single-proposal proofs (calculated as block.timestamp - proposal.timestamp).
    ///        For multi-proposal batches, this is always 0, meaning "not applicable".
    ///        Verifiers should interpret _proposalAge == 0 as "not applicable" rather than
    ///        "instant proof". This parameter enables age-based verification logic, such as
    ///        detecting and handling prover-killer proposals differently.
    /// @param _transitionsHash The hash of the transitions to verify
    /// @param _proof The proof data for the transitions
    function verifyProof(
        uint256 _proposalAge,
        bytes32 _transitionsHash,
        bytes calldata _proof
    )
        external
        view;
}
