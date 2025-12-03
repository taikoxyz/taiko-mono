// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibHashOptimized
/// @notice Gas-optimized hashing functions for IInbox structs using Solady's EfficientHashLib.
/// @dev Replaces standard `keccak256(abi.encode(...))` calls with more efficient alternatives
/// that avoid memory expansion costs. All hash functions maintain deterministic ordering
/// consistent with struct field definitions in IInbox.sol.
///
/// Key optimizations:
/// - Uses EfficientHashLib for direct memory hashing without ABI encoding overhead
/// - Packs small numeric fields into single bytes32 values before hashing
/// - Pre-allocates hash buffers for variable-length arrays
/// - Uses EMPTY_BYTES_HASH constant for empty array edge cases
///
/// @custom:security-contact security@taiko.xyz
library LibHashOptimized {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Precomputed keccak256 hash of empty bytes for gas optimization.
    /// @dev Used as a sentinel value when hashing empty arrays to avoid recomputation.
    bytes32 private constant EMPTY_BYTES_HASH = keccak256("");

    // ---------------------------------------------------------------
    // Singular Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Computes a hash of a Checkpoint struct.
    /// @dev Hashes blockNumber, blockHash, and stateRoot in order.
    /// @param _checkpoint The checkpoint containing L2 block state to hash.
    /// @return The keccak256 hash of the checkpoint fields.
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(_checkpoint.blockNumber)), _checkpoint.blockHash, _checkpoint.stateRoot
        );
    }

    /// @notice Computes a hash of a CoreState struct.
    /// @dev Hashes all six fields in definition order: proposalHead, proposalHeadContainerBlock,
    /// finalizationHead, synchronizationHead, finalizationHeadTransitionHash,
    /// aggregatedBondInstructionsHash.
    /// @param _coreState The core state tracking proposal and finalization progress.
    /// @return The keccak256 hash of the core state fields.
    function hashCoreState(IInbox.CoreState memory _coreState) internal pure returns (bytes32) {
        return EfficientHashLib.hash(
            bytes32(uint256(_coreState.proposalHead)),
            bytes32(uint256(_coreState.proposalHeadContainerBlock)),
            bytes32(uint256(_coreState.finalizationHead)),
            bytes32(uint256(_coreState.synchronizationHead)),
            _coreState.finalizationHeadTransitionHash,
            _coreState.aggregatedBondInstructionsHash
        );
    }

    /// @notice Computes a hash of a Derivation struct.
    /// @dev Hashes originBlockNumber, basefeeSharingPctg, originBlockHash, and sources array.
    /// Small numeric fields are bit-packed into a single bytes32 for efficiency.
    /// The sources array is hashed recursively with length prefix to prevent collisions.
    /// @param _derivation The derivation containing L1-anchored data for a proposal.
    /// @return The keccak256 hash of the derivation fields.
    function hashDerivation(IInbox.Derivation memory _derivation) internal pure returns (bytes32) {
        unchecked {
            // Pack origin block number (uint40 = 40 bits) and basefee sharing percentage (uint8 = 8 bits)
            bytes32 packedFields = bytes32(
                (uint256(_derivation.originBlockNumber) << 216)
                    | (uint256(_derivation.basefeeSharingPctg) << 208)
            );

            // Hash the sources array
            bytes32 sourcesHash;
            uint256 sourcesLength = _derivation.sources.length;
            if (sourcesLength == 0) {
                sourcesHash = EMPTY_BYTES_HASH;
            } else if (sourcesLength == 1) {
                sourcesHash = EfficientHashLib.hash(
                    bytes32(sourcesLength), _hashDerivationSource(_derivation.sources[0])
                );
            } else if (sourcesLength == 2) {
                sourcesHash = EfficientHashLib.hash(
                    bytes32(sourcesLength),
                    _hashDerivationSource(_derivation.sources[0]),
                    _hashDerivationSource(_derivation.sources[1])
                );
            } else {
                bytes32[] memory buffer = EfficientHashLib.malloc(sourcesLength + 1);
                EfficientHashLib.set(buffer, 0, bytes32(sourcesLength));

                for (uint256 i; i < sourcesLength; ++i) {
                    EfficientHashLib.set(
                        buffer, i + 1, _hashDerivationSource(_derivation.sources[i])
                    );
                }

                sourcesHash = EfficientHashLib.hash(buffer);
                EfficientHashLib.free(buffer);
            }

            return EfficientHashLib.hash(packedFields, _derivation.originBlockHash, sourcesHash);
        }
    }

    /// @notice Computes a hash of a Proposal struct.
    /// @dev Hashes all seven fields in definition order: id, timestamp, endOfSubmissionWindowTimestamp,
    /// proposer, coreStateHash, derivationHash, parentProposalHash. The first three uint40 fields
    /// are bit-packed into a single bytes32 for gas efficiency.
    /// @param _proposal The proposal containing L2 block metadata.
    /// @return The keccak256 hash of the proposal fields.
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        unchecked {
            // Pack numeric fields together (each uint40 = 40 bits)
            bytes32 packedFields = bytes32(
                (uint256(_proposal.id) << 216) | (uint256(_proposal.timestamp) << 176)
                    | (uint256(_proposal.endOfSubmissionWindowTimestamp) << 136)
            );

            return EfficientHashLib.hash(
                packedFields,
                bytes32(uint256(uint160(_proposal.proposer))),
                _proposal.coreStateHash,
                _proposal.derivationHash,
                _proposal.parentProposalHash
            );
        }
    }

    /// @notice Computes a truncated hash of a Transition struct.
    /// @dev Hashes bondInstructionHash and checkpointHash in order. The result is truncated
    /// to bytes27 (216 bits) to enable storage optimization where bytes27 + uint40 fits in
    /// a single 32-byte storage slot (see TransitionRecord in IInbox).
    /// @param _transition The transition containing state change commitments.
    /// @return The keccak256 hash truncated to bytes27.
    function hashTransition(IInbox.Transition memory _transition) internal pure returns (bytes27) {
        return bytes27(
            EfficientHashLib.hash(_transition.bondInstructionHash, _transition.checkpointHash)
        );
    }

    /// @notice Computes a hash of a BondInstruction struct.
    /// @dev Hashes proposalId, bondType, payer, and payee in order. Used for aggregating
    /// bond instructions across finalized proposals into a rolling hash.
    /// @param _instruction The bond instruction specifying payment details.
    /// @return The keccak256 hash of the bond instruction fields.
    function hashBondInstruction(LibBonds.BondInstruction memory _instruction)
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(_instruction.proposalId)),
            bytes32(uint256(uint8(_instruction.bondType))),
            bytes32(uint256(uint160(_instruction.payer))),
            bytes32(uint256(uint160(_instruction.payee)))
        );
    }

    /// @notice Computes a hash of a BondInstructionMessage struct for L2 signaling.
    /// @dev Hashes firstProposalId, lastProposalId, and aggregatedBondInstructionsHash in order.
    /// This hash is sent via the signal service to enable L2 bond settlement.
    /// @param _change The message containing the range of finalized proposals and their bond hash.
    /// @return The keccak256 hash of the message fields.
    function hashBondInstructionMessage(IInbox.BondInstructionMessage memory _change)
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(_change.firstProposalId)),
            bytes32(uint256(_change.lastProposalId)),
            _change.aggregatedBondInstructionsHash
        );
    }

    /// @notice Computes a rolling hash by aggregating a new bond instruction hash.
    /// @dev Chains bond instruction hashes together: hash(existing, new) to form a
    /// Merkle-like commitment over all bond instructions from finalized proposals.
    /// @param _aggregatedBondInstructionsHash The current rolling hash of all prior instructions.
    /// @param _bondInstructionHash The new bond instruction hash to aggregate.
    /// @return The updated aggregated hash.
    function hashAggregatedBondInstructionsHash(
        bytes32 _aggregatedBondInstructionsHash,
        bytes32 _bondInstructionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(_aggregatedBondInstructionsHash, _bondInstructionHash);
    }

    // ---------------------------------------------------------------
    // Array Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Computes a hash of an array of blob hashes.
    /// @dev Includes array length as the first element to prevent length-extension attacks.
    /// Optimized paths for 0, 1, and 2 elements avoid buffer allocation overhead.
    /// @param _blobHashes Array of versioned blob hashes from EIP-4844 blobs.
    /// @return The keccak256 hash of length-prefixed blob hashes.
    function hashBlobHashesArray(bytes32[] memory _blobHashes) internal pure returns (bytes32) {
        unchecked {
            uint256 length = _blobHashes.length;
            if (length == 0) {
                return EMPTY_BYTES_HASH;
            }

            if (length == 1) {
                return EfficientHashLib.hash(bytes32(length), _blobHashes[0]);
            }

            if (length == 2) {
                return EfficientHashLib.hash(bytes32(length), _blobHashes[0], _blobHashes[1]);
            }

            bytes32[] memory buffer = EfficientHashLib.malloc(length + 1);
            EfficientHashLib.set(buffer, 0, bytes32(length));

            for (uint256 i; i < length; ++i) {
                EfficientHashLib.set(buffer, i + 1, _blobHashes[i]);
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }

    /// @notice Computes a hash of an array of ProveInput structs.
    /// @dev Includes array length as the first element to prevent length-extension attacks.
    /// Each ProveInput is recursively hashed via _hashProveInput. Optimized paths for
    /// 0, 1, and 2 elements avoid buffer allocation overhead.
    /// @param _inputs Array of prove inputs containing proposals and their proofs.
    /// @return The keccak256 hash of length-prefixed prove input hashes.
    function hashProveInputArray(IInbox.ProveInput[] memory _inputs)
        internal
        pure
        returns (bytes32)
    {
        unchecked {
            uint256 length = _inputs.length;
            if (length == 0) {
                return EMPTY_BYTES_HASH;
            }

            if (length == 1) {
                return EfficientHashLib.hash(bytes32(length), _hashProveInput(_inputs[0]));
            }

            if (length == 2) {
                return EfficientHashLib.hash(
                    bytes32(length), _hashProveInput(_inputs[0]), _hashProveInput(_inputs[1])
                );
            }

            bytes32[] memory buffer = EfficientHashLib.malloc(length + 1);
            EfficientHashLib.set(buffer, 0, bytes32(length));

            for (uint256 i; i < length; ++i) {
                EfficientHashLib.set(buffer, i + 1, _hashProveInput(_inputs[i]));
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }

    // ---------------------------------------------------------------
    // Utility Functions
    // ---------------------------------------------------------------

    /// @notice Computes a composite storage key for transition records.
    /// @dev Combines proposalId and parentTransitionHash into a unique bytes32 key
    /// for the transitionRecords mapping. This enables efficient lookup of transition
    /// proofs by their position in the proposal chain.
    /// @param _proposalId The sequential ID of the proposal.
    /// @param _parentTransitionHash The truncated hash of the parent transition (bytes27).
    /// @return The keccak256 composite key for storage mapping lookup.
    function composeTransitionKey(
        uint40 _proposalId,
        bytes27 _parentTransitionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(bytes32(uint256(_proposalId)), bytes32(_parentTransitionHash));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @notice Computes a hash of a DerivationSource struct.
    /// @dev Hashes isForcedInclusion flag and the nested BlobSlice (blobHashes, offset, timestamp).
    /// The BlobSlice is hashed hierarchically: blobHashes array first, then combined with offset
    /// and timestamp.
    /// @param _source The derivation source (regular submission or forced inclusion).
    /// @return The keccak256 hash of the derivation source fields.
    function _hashDerivationSource(IInbox.DerivationSource memory _source)
        private
        pure
        returns (bytes32)
    {
        // Hash blob slice fields - BlobSlice has blobHashes array, offset, and timestamp
        bytes32 blobHashesHash = hashBlobHashesArray(_source.blobSlice.blobHashes);

        bytes32 blobSliceHash = EfficientHashLib.hash(
            blobHashesHash,
            bytes32(uint256(_source.blobSlice.offset)),
            bytes32(uint256(_source.blobSlice.timestamp))
        );

        return
            EfficientHashLib.hash(
                bytes32(uint256(_source.isForcedInclusion ? 1 : 0)), blobSliceHash
            );
    }

    /// @notice Computes a hash of a ProveInput struct.
    /// @dev Recursively hashes proposal, checkpoint, metadata, and parentTransitionHash.
    /// Each nested struct is hashed using its corresponding hash function.
    /// @param _input The prove input containing a proposal and its proof data.
    /// @return The keccak256 hash of the prove input fields.
    function _hashProveInput(IInbox.ProveInput memory _input) private pure returns (bytes32) {
        bytes32 proposalHash = hashProposal(_input.proposal);
        bytes32 checkpointHash = hashCheckpoint(_input.checkpoint);
        bytes32 metadataHash = _hashTransitionMetadata(_input.metadata);

        return EfficientHashLib.hash(
            proposalHash, checkpointHash, metadataHash, bytes32(_input.parentTransitionHash)
        );
    }

    /// @notice Computes a hash of a TransitionMetadata struct.
    /// @dev Hashes designatedProver and actualProver addresses in order.
    /// @param _metadata The metadata containing prover information.
    /// @return The keccak256 hash of the metadata fields.
    function _hashTransitionMetadata(IInbox.TransitionMetadata memory _metadata)
        private
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(uint160(_metadata.designatedProver))),
            bytes32(uint256(uint160(_metadata.actualProver)))
        );
    }
}
