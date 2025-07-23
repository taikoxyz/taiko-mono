// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "./IInbox.sol";
import { LibData } from "./libs/LibData.sol";
import { LibCodecSummary } from "./codec/LibCodecSummary.sol";
import { LibCodecBatchContext } from "./codec/LibCodecBatchContext.sol";
import { LibCodecBatch } from "./codec/LibCodecBatch.sol";
import { LibCodecTransitionMeta } from "./codec/LibCodecTransitionMeta.sol";
import { LibCodecProverAuth } from "./codec/LibCodecProverAuth.sol";
import { LibCodecProveBatchInputs } from "./codec/LibCodecProveBatchInputs.sol";
import { LibCodecProposeBatchEvidence } from "./codec/LibCodecProposeBatchEvidence.sol";
import { LibCodecProposeBatchInputs } from "./codec/LibCodecProposeBatchInputs.sol";
import { LibCodecHeaderExtraInfo } from "./codec/LibCodecHeaderExtraInfo.sol";

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
        I.Batch calldata _batch,
        I.BatchContext calldata _context
    )
        external
        pure
        returns (I.BatchMetadata memory meta_)
    {
        return LibData.buildBatchMetadata(_proposedIn, _proposedAt, _batch, _context);
    }

    /// @notice Encodes a Summary struct
    /// @param _summary The Summary struct to encode
    /// @return The encoded bytes
    function encodeSummary(I.Summary memory _summary) public pure returns (bytes memory) {
        return LibCodecSummary.encode(_summary);
    }

    /// @notice Decodes bytes into a Summary struct
    /// @param _data The bytes to decode
    /// @return The decoded Summary struct
    function decodeSummary(bytes memory _data) public pure returns (I.Summary memory) {
        return LibCodecSummary.decode(_data);
    }

    /// @notice Encodes a BatchContext struct
    /// @param _context The BatchContext struct to encode
    /// @return The encoded bytes
    function encodeBatchContext(I.BatchContext memory _context)
        public
        pure
        returns (bytes memory)
    {
        return LibCodecBatchContext.encode(_context);
    }

    /// @notice Decodes bytes into a BatchContext struct
    /// @param _data The bytes to decode
    /// @return The decoded BatchContext struct
    function decodeBatchContext(bytes memory _data) public pure returns (I.BatchContext memory) {
        return LibCodecBatchContext.decode(_data);
    }

    /// @notice Encodes an array of Batch structs
    /// @param _batches The array of Batch structs to encode
    /// @return The encoded bytes
    function encodeBatches(I.Batch[] memory _batches) public pure returns (bytes memory) {
        return LibCodecBatch.encode(_batches);
    }

    /// @notice Decodes bytes into an array of Batch structs
    /// @param _data The bytes to decode
    /// @return The decoded array of Batch structs
    function decodeBatches(bytes memory _data) public pure returns (I.Batch[] memory) {
        return LibCodecBatch.decode(_data);
    }

    /// @notice Encodes an array of TransitionMeta structs
    /// @param _transitionMetas The array of TransitionMeta structs to encode
    /// @return The encoded bytes
    function encodeTransitionMetas(I.TransitionMeta[] memory _transitionMetas)
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
        returns (I.TransitionMeta[] memory)
    {
        return LibCodecTransitionMeta.decode(_data);
    }

    /// @notice Encodes a ProverAuth struct
    /// @param _auth The ProverAuth struct to encode
    /// @return The encoded bytes
    function encodeProverAuth(I.ProverAuth memory _auth) public pure returns (bytes memory) {
        return LibCodecProverAuth.encode(_auth);
    }

    /// @notice Decodes bytes into a ProverAuth struct
    /// @param _data The bytes to decode
    /// @return The decoded ProverAuth struct
    function decodeProverAuth(bytes memory _data) public pure returns (I.ProverAuth memory) {
        return LibCodecProverAuth.decode(_data);
    }

    /// @notice Encodes an array of ProveBatchInput structs
    /// @param _inputs The array of ProveBatchInput structs to encode
    /// @return The encoded bytes
    function encodeProveBatchInputs(I.ProveBatchInput[] memory _inputs)
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
        returns (I.ProveBatchInput[] memory)
    {
        return LibCodecProveBatchInputs.decode(_data);
    }

    /// @notice Decodes bytes into an array of ProveBatchInput structs (wrapper function)
    /// @param _data The bytes to decode
    /// @return The decoded array of ProveBatchInput structs
    function decodeProveBatchesInputs(bytes memory _data)
        public
        pure
        returns (I.ProveBatchInput[] memory)
    {
        return LibCodecProveBatchInputs.decodeProveBatchesInputs(_data);
    }

    /// @notice Encodes a ProposeBatchEvidence struct
    /// @param _evidence The ProposeBatchEvidence struct to encode
    /// @return The encoded bytes
    function encodeProposeBatchEvidence(I.ProposeBatchEvidence memory _evidence)
        public
        pure
        returns (bytes memory)
    {
        return LibCodecProposeBatchEvidence.encode(_evidence);
    }

    /// @notice Decodes bytes into a ProposeBatchEvidence struct
    /// @param _data The bytes to decode
    /// @return The decoded ProposeBatchEvidence struct
    function decodeProposeBatchEvidence(bytes memory _data)
        public
        pure
        returns (I.ProposeBatchEvidence memory)
    {
        return LibCodecProposeBatchEvidence.decode(_data);
    }

    /// @notice Encodes multiple propose batch inputs
    /// @param _summary The Summary struct
    /// @param _batches The array of Batch structs
    /// @param _evidence The ProposeBatchEvidence struct
    /// @param _transitionMetas The array of TransitionMeta structs
    /// @return The encoded bytes
    function encodeProposeBatchInputs(
        I.Summary memory _summary,
        I.Batch[] memory _batches,
        I.ProposeBatchEvidence memory _evidence,
        I.TransitionMeta[] memory _transitionMetas
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
            I.Summary memory _summary,
            I.Batch[] memory _batches,
            I.ProposeBatchEvidence memory _evidence,
            I.TransitionMeta[] memory _transitionMetas
        )
    {
        return LibCodecProposeBatchInputs.decode(_data);
    }

    /// @notice Encodes a HeaderExtraInfo struct
    /// @param _headerExtraInfo The HeaderExtraInfo struct to encode
    /// @return The encoded bytes32
    function encodeHeaderExtraInfo(I.HeaderExtraInfo memory _headerExtraInfo)
        public
        pure
        returns (bytes32)
    {
        return LibCodecHeaderExtraInfo.encode(_headerExtraInfo);
    }

    /// @notice Decodes bytes32 into a HeaderExtraInfo struct
    /// @param _data The bytes32 to decode
    /// @return The decoded HeaderExtraInfo struct
    function decodeHeaderExtraInfo(bytes32 _data) public pure returns (I.HeaderExtraInfo memory) {
        return LibCodecHeaderExtraInfo.decode(_data);
    }
}