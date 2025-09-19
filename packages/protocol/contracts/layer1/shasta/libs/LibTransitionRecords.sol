// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBondsL1 } from "../libs/LibBondsL1.sol";
import { LibInboxValidation } from "./LibInboxValidation.sol";

/// @title LibTransitionRecords
/// @notice Library for managing transition records and related operations
/// @custom:security-contact security@taiko.xyz
library LibTransitionRecords {

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Struct for storing transition effective timestamp and hash.
    /// @dev Stores the first transition record for each proposal to reduce gas costs
    struct TransitionRecordHashAndDeadline {
        bytes26 recordHash;
        uint48 finalizationDeadline;
    }

    // ---------------------------------------------------------------
    // Transition Record Operations
    // ---------------------------------------------------------------

    /// @dev Builds a transition record for a proposal, transition, and metadata tuple.
    /// @param _proposal The proposal the transition is proving.
    /// @param _transition The transition associated with the proposal.
    /// @param _metadata The metadata describing the prover and additional context.
    /// @param _provingWindow The proving window in seconds.
    /// @param _extendedProvingWindow The extended proving window in seconds.
    /// @return record The constructed transition record with span set to one.
    function buildTransitionRecord(
        IInbox.Proposal memory _proposal,
        IInbox.Transition memory _transition,
        IInbox.TransitionMetadata memory _metadata,
        uint48 _provingWindow,
        uint48 _extendedProvingWindow
    )
        internal
        view
        returns (IInbox.TransitionRecord memory record)
    {
        record.span = 1;
        record.bondInstructions = LibBondsL1.calculateBondInstructions(
            _provingWindow, _extendedProvingWindow, _proposal, _metadata
        );
        record.transitionHash = LibInboxValidation.hashTransition(_transition);
        record.checkpointHash = LibInboxValidation.hashCheckpoint(_transition.checkpoint);
    }

    /// @dev Hashes a transition record.
    /// @param _transitionRecord The transition record to hash.
    /// @return _ The hash of the transition record as bytes26.
    function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord)
        internal
        pure
        returns (bytes26)
    {
        /// forge-lint: disable-next-line(asm-keccak256)
        return bytes26(keccak256(abi.encode(_transitionRecord)));
    }

    /// @dev Computes the hash and finalization deadline for a transition record.
    /// @param _transitionRecord The transition record to hash.
    /// @param _finalizationGracePeriod The finalization grace period in seconds.
    /// @return recordHash The keccak hash of the transition record.
    /// @return hashAndDeadline The struct containing the hash and deadline to persist.
    function computeTransitionRecordHashAndDeadline(
        IInbox.TransitionRecord memory _transitionRecord,
        uint48 _finalizationGracePeriod
    )
        internal
        view
        returns (bytes26 recordHash, TransitionRecordHashAndDeadline memory hashAndDeadline)
    {
        recordHash = hashTransitionRecord(_transitionRecord);
        hashAndDeadline = TransitionRecordHashAndDeadline({
            finalizationDeadline: uint48(block.timestamp + _finalizationGracePeriod),
            recordHash: recordHash
        });
    }

    /// @dev Composes a transition key for mapping lookups.
    /// @param _proposalId The proposal ID.
    /// @param _parentTransitionHash The parent transition hash.
    /// @return _ The composed key for the transition.
    function composeTransitionKey(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("TRANSITION_RECORD", _proposalId, _parentTransitionHash));
    }

    /// @dev Sets the transition record hash and deadline for a specific transition.
    /// @param _proposalId The ID of the proposal containing the transition.
    /// @param _transition The transition data.
    /// @param _metadata The metadata for the transition.
    /// @param _transitionRecord The transition record.
    /// @param _transitionRecordHashAndDeadlines Storage mapping for transition records.
    /// @param _finalizationGracePeriod The finalization grace period in seconds.
    function setTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        IInbox.Transition memory _transition,
        IInbox.TransitionMetadata memory _metadata,
        IInbox.TransitionRecord memory _transitionRecord,
        mapping(bytes32 => TransitionRecordHashAndDeadline) storage _transitionRecordHashAndDeadlines,
        uint48 _finalizationGracePeriod
    )
        internal
    {
        (, TransitionRecordHashAndDeadline memory hashAndDeadline) =
            computeTransitionRecordHashAndDeadline(_transitionRecord, _finalizationGracePeriod);

        bytes32 key = composeTransitionKey(_proposalId, _transition.parentTransitionHash);
        _transitionRecordHashAndDeadlines[key] = hashAndDeadline;

        emit IInbox.Proved(
            encodeProvedEventData(IInbox.ProvedEventPayload({
                proposalId: _proposalId,
                transition: _transition,
                transitionRecord: _transitionRecord,
                metadata: _metadata
            }))
        );
    }

    /// @dev Gets the transition record hash and deadline for a specific transition.
    /// @param _proposalId The ID of the proposal containing the transition.
    /// @param _parentTransitionHash The hash of the parent transition.
    /// @param _transitionRecordHashAndDeadlines Storage mapping for transition records.
    /// @return hashAndDeadline The transition record hash and finalization deadline.
    function getTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        bytes32 _parentTransitionHash,
        mapping(bytes32 => TransitionRecordHashAndDeadline) storage _transitionRecordHashAndDeadlines
    )
        internal
        view
        returns (TransitionRecordHashAndDeadline memory hashAndDeadline)
    {
        bytes32 key = composeTransitionKey(_proposalId, _parentTransitionHash);
        hashAndDeadline = _transitionRecordHashAndDeadlines[key];
    }

    // ---------------------------------------------------------------
    // Data Encoding Functions
    // ---------------------------------------------------------------

    /// @dev Encodes event data for the Proposed event.
    /// @param _payload The event payload to encode.
    /// @return _ The encoded event data.
    function encodeProposedEventData(IInbox.ProposedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_payload);
    }

    /// @dev Encodes event data for the Proved event.
    /// @param _payload The event payload to encode.
    /// @return _ The encoded event data.
    function encodeProvedEventData(IInbox.ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_payload);
    }

    // ---------------------------------------------------------------
    // Data Decoding Functions
    // ---------------------------------------------------------------

    /// @dev Decodes ProposalInput from calldata.
    /// @param _data The calldata to decode.
    /// @return input The decoded ProposalInput.
    function decodeProposeInput(bytes calldata _data)
        internal
        pure
        returns (IInbox.ProposeInput memory input)
    {
        input = abi.decode(_data, (IInbox.ProposeInput));
    }

    /// @dev Decodes ProveInput from calldata.
    /// @param _data The calldata to decode.
    /// @return input The decoded ProveInput.
    function decodeProveInput(bytes calldata _data)
        internal
        pure
        returns (IInbox.ProveInput memory input)
    {
        input = abi.decode(_data, (IInbox.ProveInput));
    }

    // ---------------------------------------------------------------
    // Note: Unoptimized Reference Functions
    // ---------------------------------------------------------------
    // Functions in this library use standard abi.encode/abi.decode for simplicity.
    // For gas-optimized encoding/decoding, see:
    // - LibProposedEventEncoder.sol (optimized ProposedEventPayload encoding)
    // - LibProvedEventEncoder.sol (optimized ProvedEventPayload encoding)
    // - LibHashing.sol (optimized hashing functions)
}