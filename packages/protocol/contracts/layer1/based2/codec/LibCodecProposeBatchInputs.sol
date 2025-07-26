// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodecProposeBatchInputs
/// @notice Library for encoding and decoding propose batches inputs
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecProposeBatchInputs {
    /// @notice Encodes propose batches inputs into bytes
    /// @param _summary The summary
    /// @param _batch The batch
    /// @param _evidence The evidence
    /// @param _transitionMetas The transition metas array
    /// @return _ The encoded data
    function encode(
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.ProposeBatchEvidence memory _evidence,
        I.TransitionMeta[] memory _transitionMetas
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_summary, _batch, _evidence, _transitionMetas);
    }

    /// @notice Decodes bytes into propose batches inputs
    /// @param _data The encoded data
    /// @return _summary The decoded summary
    /// @return _batch The decoded batch
    /// @return _evidence The decoded evidence
    /// @return _transitionMetas The decoded transition metas
    function decode(bytes memory _data)
        internal
        pure
        returns (
            I.Summary memory _summary,
            I.Batch memory _batch,
            I.ProposeBatchEvidence memory _evidence,
            I.TransitionMeta[] memory _transitionMetas
        )
    {
        (_summary, _batch, _evidence, _transitionMetas) =
            abi.decode(_data, (I.Summary, I.Batch, I.ProposeBatchEvidence, I.TransitionMeta[]));
    }
}
