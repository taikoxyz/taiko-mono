// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";

/// @title LibHashOptimized
/// @notice Optimized hashing functions using Solady's EfficientHashLib
/// @dev This library provides gas-optimized implementations of all hashing functions
///      used in the Inbox contract, replacing standard keccak256(abi.encode(...)) calls
///      with more efficient alternatives from Solady's EfficientHashLib.
/// @custom:security-contact security@taiko.xyz
library LibHashOptimized {
    // ---------------------------------------------------------------
    // Core Structure Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Optimized hashing for Derivation structs
    /// @dev Manually constructs the ABI-encoded layout to avoid nested abi.encode calls
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation memory _derivation) internal pure returns (bytes32) {
        unchecked {
            IInbox.DerivationSource[] memory sources = _derivation.sources;
            uint256 sourcesLength = sources.length;

            // Base words:
            // [0] offset to tuple head (0x20)
            // [1] originBlockNumber
            // [2] originBlockHash
            // [3] basefeeSharingPctg
            // [4] offset to sources (0x80)
            // [5] sources length
            uint256 totalWords = 6 + sourcesLength;

            // Each source contributes: element head (2) + blobSlice head (3) + blobHashes
            // length (1) + blobHashes entries
            for (uint256 i; i < sourcesLength; ++i) {
                totalWords += 6 + sources[i].blobSlice.blobHashes.length;
            }

            bytes32[] memory buffer = EfficientHashLib.malloc(totalWords);

            EfficientHashLib.set(buffer, 0, bytes32(uint256(0x20)));
            EfficientHashLib.set(buffer, 1, bytes32(uint256(_derivation.originBlockNumber)));
            EfficientHashLib.set(buffer, 2, _derivation.originBlockHash);
            EfficientHashLib.set(buffer, 3, bytes32(uint256(_derivation.basefeeSharingPctg)));
            EfficientHashLib.set(buffer, 4, bytes32(uint256(0x80)));
            EfficientHashLib.set(buffer, 5, bytes32(sourcesLength));

            uint256 offsetsBase = 6;
            uint256 dataCursor = offsetsBase + sourcesLength;

            for (uint256 i; i < sourcesLength; ++i) {
                IInbox.DerivationSource memory source = sources[i];
                EfficientHashLib.set(
                    buffer, offsetsBase + i, bytes32((dataCursor - offsetsBase) << 5)
                );

                // DerivationSource head
                EfficientHashLib.set(
                    buffer, dataCursor, bytes32(uint256(source.isForcedInclusion ? 1 : 0))
                );
                EfficientHashLib.set(buffer, dataCursor + 1, bytes32(uint256(0x40)));

                // BlobSlice head
                uint256 blobSliceBase = dataCursor + 2;
                EfficientHashLib.set(buffer, blobSliceBase, bytes32(uint256(0x60)));
                EfficientHashLib.set(
                    buffer, blobSliceBase + 1, bytes32(uint256(source.blobSlice.offset))
                );
                EfficientHashLib.set(
                    buffer, blobSliceBase + 2, bytes32(uint256(source.blobSlice.timestamp))
                );

                // Blob hashes array
                bytes32[] memory blobHashes = source.blobSlice.blobHashes;
                uint256 blobHashesLength = blobHashes.length;
                uint256 blobHashesBase = blobSliceBase + 3;
                EfficientHashLib.set(buffer, blobHashesBase, bytes32(blobHashesLength));

                for (uint256 j; j < blobHashesLength; ++j) {
                    EfficientHashLib.set(buffer, blobHashesBase + 1 + j, blobHashes[j]);
                }

                dataCursor = blobHashesBase + 1 + blobHashesLength;
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }

    /// @notice Optimized hashing for Proposal structs
    /// @dev Uses efficient multi-field hashing for all proposal fields
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        bytes32[] memory buffer = EfficientHashLib.malloc(6);

        EfficientHashLib.set(buffer, 0, bytes32(uint256(_proposal.id)));
        EfficientHashLib.set(buffer, 1, bytes32(uint256(_proposal.timestamp)));
        EfficientHashLib.set(buffer, 2, bytes32(uint256(_proposal.endOfSubmissionWindowTimestamp)));
        EfficientHashLib.set(buffer, 3, bytes32(uint256(uint160(_proposal.proposer))));
        EfficientHashLib.set(buffer, 4, _proposal.parentProposalHash);
        EfficientHashLib.set(buffer, 5, _proposal.derivationHash);

        bytes32 result = EfficientHashLib.hash(buffer);
        EfficientHashLib.free(buffer);
        return result;
    }

    /// @notice Optimized hashing for Checkpoint structs
    /// @dev Uses efficient 3-field hashing for checkpoint data
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        returns (bytes32)
    {
        bytes32[] memory buffer = EfficientHashLib.malloc(3);

        EfficientHashLib.set(buffer, 0, bytes32(uint256(_checkpoint.blockNumber)));
        EfficientHashLib.set(buffer, 1, _checkpoint.blockHash);
        EfficientHashLib.set(buffer, 2, _checkpoint.stateRoot);

        bytes32 result = EfficientHashLib.hash(buffer);
        EfficientHashLib.free(buffer);
        return result;
    }

    /// @notice Optimized hashing for prove inputs and the corresponding proposal hash.
    /// @dev Produces the same digest as `keccak256(abi.encode(_lastProposalHash, _input))`
    ///      while minimizing memory allocations.
    /// @param _lastProposalHash The hash of the last proposal in the batch.
    /// @param _input The prove input to hash.
    /// @return The hash of the prove input.
    function hashProveInput(
        bytes32 _lastProposalHash,
        IInbox.ProveInput memory _input
    )
        internal
        pure
        returns (bytes32)
    {
        unchecked {
            IInbox.Transition[] memory transitions = _input.transitions;
            uint256 transitionsLength = transitions.length;

            // Top-level layout (abi.encode):
            // [0] lastProposalHash
            // [1] offset to prove input (0x40)
            //
            // ProveInput static section (starts at word 2):
            // [2] firstProposalId
            // [3] firstProposalParentCheckpointHash
            // [4] actualProver
            // [5] offset to transitions (0xe0)
            // [6] lastCheckpoint.blockNumber
            // [7] lastCheckpoint.blockHash
            // [8] lastCheckpoint.stateRoot
            //
            // Transitions array (starts at word 9):
            // [9] length
            // [10...] transition elements (4 words each)
            uint256 totalWords = 10 + transitionsLength * 4;

            bytes32[] memory buffer = EfficientHashLib.malloc(totalWords);

            // Top-level head
            EfficientHashLib.set(buffer, 0, _lastProposalHash);
            EfficientHashLib.set(buffer, 1, bytes32(uint256(0x40)));

            // ProveInput static fields
            EfficientHashLib.set(buffer, 2, bytes32(uint256(_input.firstProposalId)));
            EfficientHashLib.set(buffer, 3, _input.firstProposalParentCheckpointHash);
            EfficientHashLib.set(buffer, 4, bytes32(uint256(uint160(_input.actualProver))));
            EfficientHashLib.set(buffer, 5, bytes32(uint256(0xe0)));
            EfficientHashLib.set(buffer, 6, bytes32(uint256(_input.lastCheckpoint.blockNumber)));
            EfficientHashLib.set(buffer, 7, _input.lastCheckpoint.blockHash);
            EfficientHashLib.set(buffer, 8, _input.lastCheckpoint.stateRoot);

            // Transitions array
            EfficientHashLib.set(buffer, 9, bytes32(transitionsLength));

            uint256 base = 10;
            for (uint256 i; i < transitionsLength; ++i) {
                IInbox.Transition memory transition = transitions[i];
                EfficientHashLib.set(buffer, base, bytes32(uint256(uint160(transition.proposer))));
                EfficientHashLib.set(
                    buffer, base + 1, bytes32(uint256(uint160(transition.designatedProver)))
                );
                EfficientHashLib.set(buffer, base + 2, bytes32(uint256(transition.timestamp)));
                EfficientHashLib.set(buffer, base + 3, transition.checkpointHash);
                base += 4;
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }
}
