// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IInbox.sol";
import "./libs/LibData.sol";
import "./codec/LibCodecSummary.sol";
import "./codec/LibCodecBatchContext.sol";
import "./codec/LibCodecTransitionMeta.sol";
import "./codec/LibCodecProverAuth.sol";
import "./codec/LibCodecProveBatchInputs.sol";
import "./codec/LibCodecProposeBatchInputs.sol";
import "./codec/LibCodecHeaderExtraInfo.sol";

/// @title InboxHelper
/// @notice Contract that provides pure functions for off chain software.
/// @custom:security-contact security@taiko.xyz
contract InboxHelper {
    /// @notice Builds batch metadata from batch and batch context data
    /// @param _proposedIn The block number in which the batch is proposed
    /// @param _proposedAt The timestamp of the block in which the batch is proposed
    /// @param _batch The batch being proposed
    /// @param _context The batch context data containing computed values
    /// @return meta_ The populated batch metadata
    function buildBatchMetadata(
        uint48 _proposedIn,
        uint48 _proposedAt,
        IInbox.Batch calldata _batch,
        IInbox.BatchContext calldata _context
    )
        external
        pure
        returns (IInbox.BatchMetadata memory meta_)
    {
        return LibData.buildBatchMetadata(_proposedIn, _proposedAt, _batch, _context);
    }

    /// @notice Encodes a Summary struct
    /// @param _summary The Summary struct to encode
    /// @return The encoded bytes
    function encodeSummary(IInbox.Summary memory _summary) public pure returns (bytes memory) {
        return LibCodecSummary.encode(_summary);
    }

    /// @notice Decodes bytes into a Summary struct
    /// @param _data The bytes to decode
    /// @return The decoded Summary struct
    function decodeSummary(bytes memory _data) public pure returns (IInbox.Summary memory) {
        return LibCodecSummary.decode(_data);
    }

    /// @notice Encodes a BatchContext struct
    /// @param _context The BatchContext struct to encode
    /// @return The encoded bytes
    function encodeBatchContext(IInbox.BatchContext memory _context)
        public
        pure
        returns (bytes memory)
    {
        return LibCodecBatchContext.encode(_context);
    }

    /// @notice Decodes bytes into a BatchContext struct
    /// @param _data The bytes to decode
    /// @return The decoded BatchContext struct
    function decodeBatchContext(bytes memory _data)
        public
        pure
        returns (IInbox.BatchContext memory)
    {
        return LibCodecBatchContext.decode(_data);
    }

    /// @notice Encodes an array of TransitionMeta structs
    /// @param _transitionMetas The array of TransitionMeta structs to encode
    /// @return The encoded bytes
    function encodeTransitionMetas(IInbox.TransitionMeta[] memory _transitionMetas)
        public
        pure
        returns (bytes memory)
    {
        return LibCodecTransitionMeta.encode(_transitionMetas);
    }

    /// @notice Decodes bytes into an array of TransitionMeta structs
    /// @param _data The bytes to decode
    /// @return The decoded array of TransitionMeta structs
    function decodeTransitionMetas(bytes memory _data)
        public
        pure
        returns (IInbox.TransitionMeta[] memory)
    {
        return LibCodecTransitionMeta.decode(_data);
    }

    /// @notice Encodes a ProverAuth struct
    /// @param _auth The ProverAuth struct to encode
    /// @return The encoded bytes
    function encodeProverAuth(IInbox.ProverAuth memory _auth) public pure returns (bytes memory) {
        return LibCodecProverAuth.encode(_auth);
    }

    /// @notice Decodes bytes into a ProverAuth struct
    /// @param _data The bytes to decode
    /// @return The decoded ProverAuth struct
    function decodeProverAuth(bytes memory _data) public pure returns (IInbox.ProverAuth memory) {
        return LibCodecProverAuth.decode(_data);
    }

    /// @notice Encodes an array of ProveBatchInput structs
    /// @param _inputs The array of ProveBatchInput structs to encode
    /// @return The encoded bytes
    function encodeProveBatchInputs(IInbox.ProveBatchInput[] memory _inputs)
        public
        pure
        returns (bytes memory)
    {
        return LibCodecProveBatchInputs.encode(_inputs);
    }

    /// @notice Decodes bytes into an array of ProveBatchInput structs
    /// @param _data The bytes to decode
    /// @return The decoded array of ProveBatchInput structs
    function decodeProveBatchInputs(bytes memory _data)
        public
        pure
        returns (IInbox.ProveBatchInput[] memory)
    {
        return LibCodecProveBatchInputs.decode(_data);
    }

    /// @notice Decodes bytes into an array of ProveBatchInput structs (wrapper function)
    /// @param _data The bytes to decode
    /// @return The decoded array of ProveBatchInput structs
    function decodeProveBatchesInputs(bytes memory _data)
        public
        pure
        returns (IInbox.ProveBatchInput[] memory)
    {
        return LibCodecProveBatchInputs.decode(_data);
    }

    /// @notice Encodes multiple propose batch inputs
    /// @param _summary The Summary struct
    /// @param _batches The array of Batch structs
    /// @param _evidence The ProposeBatchEvidence struct
    /// @param _transitionMetas The array of TransitionMeta structs
    /// @return The encoded bytes
    function encodeProposeBatchInputs(
        IInbox.Summary memory _summary,
        IInbox.Batch[] memory _batches,
        IInbox.ProposeBatchEvidence memory _evidence,
        IInbox.TransitionMeta[] memory _transitionMetas
    )
        public
        pure
        returns (bytes memory)
    {
        return LibCodecProposeBatchInputs.encode(_summary, _batches, _evidence, _transitionMetas);
    }

    /// @notice Decodes bytes into multiple propose batch inputs
    /// @param _data The bytes to decode
    /// @return _summary The decoded Summary struct
    /// @return _batches The decoded array of Batch structs
    /// @return _evidence The decoded ProposeBatchEvidence struct
    /// @return _transitionMetas The decoded array of TransitionMeta structs
    function decodeProposeBatchInputs(bytes memory _data)
        public
        pure
        returns (
            IInbox.Summary memory _summary,
            IInbox.Batch[] memory _batches,
            IInbox.ProposeBatchEvidence memory _evidence,
            IInbox.TransitionMeta[] memory _transitionMetas
        )
    {
        return LibCodecProposeBatchInputs.decode(_data);
    }

    /// @notice Encodes a HeaderExtraInfo struct
    /// @param _headerExtraInfo The HeaderExtraInfo struct to encode
    /// @return The encoded bytes32
    function encodeHeaderExtraInfo(IInbox.HeaderExtraInfo memory _headerExtraInfo)
        public
        pure
        returns (bytes32)
    {
        return LibCodecHeaderExtraInfo.encode(_headerExtraInfo);
    }

    /// @notice Decodes bytes32 into a HeaderExtraInfo struct
    /// @param _data The bytes32 to decode
    /// @return The decoded HeaderExtraInfo struct
    function decodeHeaderExtraInfo(bytes32 _data)
        public
        pure
        returns (IInbox.HeaderExtraInfo memory)
    {
        return LibCodecHeaderExtraInfo.decode(_data);
    }
}
