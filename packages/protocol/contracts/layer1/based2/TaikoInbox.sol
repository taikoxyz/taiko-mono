// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Inbox.sol";
import "./codec/LibCodecBatchContext.sol";
import "./codec/LibCodecTransitionMeta.sol";
import "./codec/LibCodecSummary.sol";
import "./codec/LibCodecProposeBatchInputs.sol";
import "./codec/LibCodecProveBatchInputs.sol";
import "./codec/LibCodecProverAuth.sol";

/// @title TaikoInbox
/// @dev This contract extends Inbox with specific codec implementations for encoding and decoding
/// various protocol data structures for gas efficiency.
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoInbox is Inbox {
    uint256[50] private __gap;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() Inbox() { }

    // -------------------------------------------------------------------------
    // Encoder Decoder Internal Functions Overrides
    // -------------------------------------------------------------------------

    /// @inheritdoc AbstractInbox
    function _encodeBatchContext(IInbox.BatchContext memory _context)
        internal
        pure
        override
        returns (bytes memory)
    {
        return LibCodecBatchContext.encode(_context);
    }

    /// @inheritdoc AbstractInbox
    function _encodeTransitionMetas(IInbox.TransitionMeta[] memory _transitionMetas)
        internal
        pure
        override
        returns (bytes memory)
    {
        return LibCodecTransitionMeta.encode(_transitionMetas);
    }

    /// @inheritdoc AbstractInbox
    function _encodeSummary(IInbox.Summary memory _summary)
        internal
        pure
        override
        returns (bytes memory)
    {
        return LibCodecSummary.encode(_summary);
    }

    /// @inheritdoc AbstractInbox
    function _decodeProposeBatchesInputs(bytes memory _data)
        internal
        pure
        override
        returns (
            IInbox.Summary memory,
            IInbox.Batch[] memory,
            IInbox.ProposeBatchEvidence memory,
            IInbox.TransitionMeta[] memory
        )
    {
        return LibCodecProposeBatchInputs.decode(_data);
    }

    /// @inheritdoc AbstractInbox
    function _decodeProverAuth(bytes memory _data)
        internal
        pure
        override
        returns (IInbox.ProverAuth memory)
    {
        return LibCodecProverAuth.decode(_data);
    }

    /// @inheritdoc AbstractInbox
    function _decodeSummary(bytes memory _data)
        internal
        pure
        override
        returns (IInbox.Summary memory)
    {
        return LibCodecSummary.decode(_data);
    }

    /// @inheritdoc AbstractInbox
    function _decodeProveBatchesInputs(bytes memory _data)
        internal
        pure
        override
        returns (IInbox.ProveBatchInput[] memory)
    {
        return LibCodecProveBatchInputs.decode(_data);
    }
}
