// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "./IInbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title ICodec
/// @notice Interface for Inbox encoder/decoder and hashing functions
/// @dev Input validation assumptions:
/// - All decode functions may revert on malformed input data
/// - Array inputs should be bounded to prevent excessive gas usage
/// - Struct fields are not validated for business logic constraints
/// - Hash functions assume well-formed input structures
/// @dev Compatibility warning:
/// - Different codec implementations produce INCOMPATIBLE encoded outputs and hashes for the same
/// inputs
/// - Codec implementations cannot be used interchangeably
/// - System upgrades between codec types require careful migration planning
/// @custom:security-contact security@taiko.xyz
interface ICodec {
    // ---------------------------------------------------------------
    // ProposeInput Codec Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposeInput struct into compact bytes format
    /// @param _input The ProposeInput struct to encode
    /// @return encoded_ Encoded bytes suitable for calldata
    function encodeProposeInput(IInbox.ProposeInput calldata _input)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes compact bytes into ProposeInput struct
    /// @param _data The encoded data to decode
    /// @return input_ The decoded ProposeInput struct
    /// @dev Reverts on malformed or truncated input data
    function decodeProposeInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_);

    // ---------------------------------------------------------------
    // ProveInput Codec Functions
    // ---------------------------------------------------------------

    /// @notice Encodes ProveInput array into compact bytes format
    /// @param _inputs The ProveInput array to encode
    /// @return encoded_ Encoded bytes suitable for calldata
    function encodeProveInput(IInbox.ProveInput[] calldata _inputs)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes compact bytes into ProveInput array
    /// @param _data The encoded data to decode
    /// @return inputs_ The decoded ProveInput array
    /// @dev Reverts on malformed or truncated input data
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput[] memory inputs_);

    // ---------------------------------------------------------------
    // ProposedEvent Codec Functions
    // ---------------------------------------------------------------

    /// @notice Encodes ProposedEventPayload into compact bytes for event emission
    /// @param _payload The payload to encode
    /// @return encoded_ Encoded bytes emitted in Proposed event
    function encodeProposedEventData(IInbox.ProposedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes Proposed event data into ProposedEventPayload struct
    /// @param _data The encoded event data to decode
    /// @return payload_ The decoded ProposedEventPayload struct
    /// @dev Reverts on malformed or truncated input data
    function decodeProposedEventData(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_);

    // ---------------------------------------------------------------
    // ProvedEvent Codec Functions
    // ---------------------------------------------------------------

    /// @notice Encodes ProvedEventPayload into compact bytes for event emission
    /// @param _payload The payload to encode
    /// @return encoded_ Encoded bytes emitted in Proved event
    function encodeProvedEventData(IInbox.ProvedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes Proved event data into ProvedEventPayload struct
    /// @param _data The encoded event data to decode
    /// @return payload_ The decoded ProvedEventPayload struct
    /// @dev Reverts on malformed or truncated input data
    function decodeProvedEventData(bytes calldata _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_);

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Computes hash of a Checkpoint struct
    /// @param _checkpoint The checkpoint to hash
    /// @return The keccak256 hash of the checkpoint fields
    function hashCheckpoint(ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        pure
        returns (bytes32);

    /// @notice Computes hash of a CoreState struct
    /// @param _coreState The core state to hash
    /// @return The keccak256 hash of the core state fields
    function hashCoreState(IInbox.CoreState calldata _coreState) external pure returns (bytes32);

    /// @notice Computes hash of a Derivation struct
    /// @param _derivation The derivation to hash
    /// @return The keccak256 hash of the derivation fields
    function hashDerivation(IInbox.Derivation calldata _derivation) external pure returns (bytes32);

    /// @notice Computes hash of a Proposal struct
    /// @param _proposal The proposal to hash
    /// @return The keccak256 hash of the proposal fields
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32);

    /// @notice Computes truncated hash of a Transition struct
    /// @param _transition The transition to hash
    /// @return The keccak256 hash truncated to 27 bytes for storage optimization
    function hashTransition(IInbox.Transition calldata _transition)
        external
        pure
        returns (bytes27);

    /// @notice Computes hash of a BondInstruction struct
    /// @param _bondInstruction The bond instruction to hash
    /// @return The keccak256 hash of the bond instruction fields
    function hashBondInstruction(LibBonds.BondInstruction calldata _bondInstruction)
        external
        pure
        returns (bytes32);

    /// @notice Computes hash of a BondInstructionMessage for L2 signaling
    /// @param _change The bond instruction message to hash
    /// @return The keccak256 hash used as signal service message
    function hashBondInstructionMessage(IInbox.BondInstructionMessage calldata _change)
        external
        pure
        returns (bytes32);

    /// @notice Aggregates a bond instruction hash into the rolling hash
    /// @param _aggregatedBondInstructionHash The current aggregated hash
    /// @param _bondInstructionHash The new bond instruction hash to include
    /// @return The new aggregated hash
    function hashAggregatedBondInstructionsHash(
        bytes32 _aggregatedBondInstructionHash,
        bytes32 _bondInstructionHash
    )
        external
        pure
        returns (bytes32);

    /// @notice Computes hash of a blob hashes array
    /// @param _blobHashes The array of blob hashes to hash
    /// @return The keccak256 hash including array length for collision resistance
    function hashBlobHashesArray(bytes32[] calldata _blobHashes) external pure returns (bytes32);

    /// @notice Computes hash of ProveInput array for proof verification
    /// @param _inputs The array of prove inputs to hash
    /// @return The keccak256 hash passed to the proof verifier
    function hashProveInputArray(IInbox.ProveInput[] calldata _inputs)
        external
        pure
        returns (bytes32);
}
