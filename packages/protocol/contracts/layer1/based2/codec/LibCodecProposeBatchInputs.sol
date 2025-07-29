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
    /// @param _proposeBatchEvidence The evidence
    /// @param _transitionMetas The transition metas array
    /// @return _ The encoded data
    function encode(
        IInbox.Summary memory _summary,
        /// @custom:encode max-size:7
        IInbox.Batch[] memory _batches,
        IInbox.ProposeBatchEvidence memory _proposeBatchEvidence,
        /// @custom:encode max-size:63
        IInbox.TransitionMeta[] memory _transitionMetas
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_summary, _batches, _proposeBatchEvidence, _transitionMetas);
    }

    /// @notice Decodes bytes into propose batches inputs
    /// @param _data The encoded data
    /// @return summary_ The decoded summary
    /// @return batches_ The decoded batches
    /// @return proposeBatchEvidence_ The decoded evidence
    /// @return transitionMetas_ The decoded transition metas
    /// @custom:encode optimize-gas
    function decode(bytes memory _data)
        internal
        pure
        returns (
            IInbox.Summary memory summary_,
            IInbox.Batch[] memory batches_,
            IInbox.ProposeBatchEvidence memory proposeBatchEvidence_,
            IInbox.TransitionMeta[] memory transitionMetas_
        )
    {
        (summary_, batches_, proposeBatchEvidence_, transitionMetas_) = abi.decode(
            _data,
            (IInbox.Summary, IInbox.Batch[], IInbox.ProposeBatchEvidence, IInbox.TransitionMeta[])
        );
    }
}
