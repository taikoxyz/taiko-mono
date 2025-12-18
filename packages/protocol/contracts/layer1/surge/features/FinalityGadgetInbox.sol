// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Inbox } from "../../core/impl/Inbox.sol";
import { LibHashOptimized } from "../../core/libs/LibHashOptimized.sol";
import { SurgeVerifier } from "../SurgeVerifier.sol";
import { LibProofBitmap } from "../libs/LibProofBitmap.sol";

/// @title FinalityGadgetInbox
/// @notice A feature-contract that implements the Surge finality gadget
/// @custom:security-contact security@nethermind.io
abstract contract FinalityGadgetInbox is Inbox {
    using LibProofBitmap for LibProofBitmap.ProofBitmap;

    /// @dev Emitted when conflicting proofs are detected for a proposal
    /// @param firstProposalId The ID of the first proposal in the conflict
    /// @param conflictingProofBitmap Bitmap representing the conflicting proofs
    event ConflictingProofsDetected(
        uint48 indexed firstProposalId, LibProofBitmap.ProofBitmap conflictingProofBitmap
    );

    /// @notice Proves that conflicting commitments exist for the same proposal, allowing
    /// the conflicting verifiers to be marked as upgradeable
    /// @dev The first commitment must be a finalizing commitment (meeting the proof threshold),
    /// while subsequent commitments must conflict with it (same proposal metadata but different
    /// block hashes). All commitments must contain exactly one transition for simplicity.
    /// @param _commitments ABI-encoded array of Commitment structs to prove conflicts between
    /// @param _proofs Array of proofs corresponding to each commitment (index 0 for finalizing,
    /// rest for conflicting)
    function proveConflicts(
        bytes calldata _commitments,
        bytes[] calldata _proofs
    )
        external
    {
        Commitment[] memory commitments = _decodeCommitments(_commitments);

        // Multiple conflicting commitments should be provided
        require(commitments.length > 1, Surge_InsufficientCommitmentsProvided());

        LibProofBitmap.ProofBitmap conflictingProofBitmap;

        for (uint256 i; i < commitments.length; ++i) {
            // Conflict checks are restricted to a single proposal for simplicity
            require(commitments[i].transitions.length == 1, Surge_MoreThanOneTransitionProvided());

            // The first commitment is expected to be the finalizing commitment, while
            // the rest are expected to be conflicting
            if (i > 0) {
                // Ensure consistency between the provided commitments
                _validateCommitmentConsistency(commitments[i - 1], commitments[i]);

                // Validate that subsequent transitions conflict with the finalizing transition
                require(
                    commitments[i].transitions[0].blockHash
                        != commitments[0].transitions[0].blockHash,
                    Surge_TransitionBlockhashMustDiffer()
                );

                // Verify proof validity and merge the flag with the conflicting proofs bitmap
                LibProofBitmap.ProofBitmap proofBitmap = SurgeVerifier(_proofVerifier)
                    .verifyProof(false, LibHashOptimized.hashCommitment(commitments[i]), _proofs[i]);
                conflictingProofBitmap = conflictingProofBitmap.merge(proofBitmap);
            } else {
                // Set `_requireThreshold` to true to ensure this is a finalizing commitment
                SurgeVerifier(_proofVerifier)
                    .verifyProof(true, LibHashOptimized.hashCommitment(commitments[i]), _proofs[i]);
            }
        }

        // Mark the conflicting verifiers upgradeable
        // Note: This fails if the verifier has already been marked upgradeable for a conflict
        // at the given proposal id
        SurgeVerifier(_proofVerifier)
            .markVerifiersUpgradeable(commitments[0].firstProposalId, conflictingProofBitmap, true);
        emit ConflictingProofsDetected(commitments[0].firstProposalId, conflictingProofBitmap);
    }

    /// @dev Validates that two commitments are consistent
    /// @param _previousCommitment The previous commitment to compare
    /// @param _currentCommitment The current commitment to compare
    function _validateCommitmentConsistency(
        Commitment memory _previousCommitment,
        Commitment memory _currentCommitment
    )
        internal
        pure
    {
        require(
            _currentCommitment.firstProposalId == _previousCommitment.firstProposalId,
            Surge_FirstProposalIdMustNotDiffer()
        );
        require(
            _currentCommitment.firstProposalParentBlockHash
                == _previousCommitment.firstProposalParentBlockHash,
            Surge_FirstProposalParentBlockHashMustNotDiffer()
        );
        require(
            _currentCommitment.lastProposalHash == _previousCommitment.lastProposalHash,
            Surge_LastProposalHashMustNotDiffer()
        );
        require(
            _currentCommitment.endBlockNumber == _previousCommitment.endBlockNumber,
            Surge_EndBlockNumberMustNotDiffer()
        );
        require(
            _currentCommitment.endStateRoot == _previousCommitment.endStateRoot,
            Surge_EndStateRootMustNotDiffer()
        );

        // `actualProver` may or may not be different between commitments
    }

    // ---------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------

    /// @dev Given that this will only be called during a proof conflict (a rare event)
    /// we may go ahead with simple encoding/decoding
    function _decodeCommitments(bytes calldata _data) internal pure returns (Commitment[] memory) {
        return abi.decode(_data, (Commitment[]));
    }

    // ---------------------------------------------------------------
    // Overrides
    // ---------------------------------------------------------------

    /// @dev Override the handler to call the SurgeVerifier that requires a proof threshold for the
    /// verification to pass.
    function _handleProofVerification(
        Commitment memory _commitment,
        bytes calldata _proof
    )
        internal
        view
        override
    {
        SurgeVerifier(_proofVerifier)
            .verifyProof(true, LibHashOptimized.hashCommitment(_commitment), _proof);
    }

    // ---------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------

    error Surge_EndBlockNumberMustNotDiffer();
    error Surge_EndStateRootMustNotDiffer();
    error Surge_FirstProposalIdMustNotDiffer();
    error Surge_FirstProposalParentBlockHashMustNotDiffer();
    error Surge_LastProposalHashMustNotDiffer();
    error Surge_MoreThanOneTransitionProvided();
    error Surge_InsufficientCommitmentsProvided();
    error Surge_TransitionBlockhashMustDiffer();
}
