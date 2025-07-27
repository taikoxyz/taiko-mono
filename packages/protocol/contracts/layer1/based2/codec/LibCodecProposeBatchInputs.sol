// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";

/// @title LibCodecProposeBatchInputs
/// @notice Library for encoding and decoding propose batches inputs
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecProposeBatchInputs {
    /// @notice Encodes propose batches inputs into bytes
    /// @param _summary The summary
    /// @param _batches The batches array
    /// @param _evidence The evidence
    /// @param _transitionMetas The transition metas array
    /// @return _ The encoded data
    function encode(
        IInbox.Summary memory _summary,
        IInbox.Batch[] memory _batches,
        IInbox.ProposeBatchEvidence memory _evidence,
        IInbox.TransitionMeta[] memory _transitionMetas
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_summary, _batches, _evidence, _transitionMetas);
    }

    /// @notice Decodes bytes into propose batches inputs
    /// @param _data The encoded data
    /// @return _summary The decoded summary
    /// @return _batches The decoded batches
    /// @return _evidence The decoded evidence
    /// @return _transitionMetas The decoded transition metas
    /// @custom:encode optimize-gas
    function decode(bytes memory _data)
        internal
        pure
        returns (
            IInbox.Summary memory _summary,
            IInbox.Batch[] memory _batches,
            IInbox.ProposeBatchEvidence memory _evidence,
            IInbox.TransitionMeta[] memory _transitionMetas
        )
    {
        (_summary, _batches, _evidence, _transitionMetas) = abi.decode(
            _data,
            (IInbox.Summary, IInbox.Batch[], IInbox.ProposeBatchEvidence, IInbox.TransitionMeta[])
        );
    }
}
