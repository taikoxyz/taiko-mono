// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodecBatchProposeMetadataEvidence
/// @notice Library for encoding and decoding BatchProposeMetadataEvidence
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecBatchProposeMetadataEvidence {
    /// @notice Encodes a BatchProposeMetadataEvidence struct into bytes
    /// @param _evidence The evidence to encode
    /// @return _ The encoded data
    function encode(I.BatchProposeMetadataEvidence memory _evidence)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_evidence);
    }

    /// @notice Decodes bytes into a BatchProposeMetadataEvidence struct
    /// @param _data The encoded data
    /// @return _ The decoded evidence
    function decode(bytes memory _data)
        internal
        pure
        returns (I.BatchProposeMetadataEvidence memory)
    {
        return abi.decode(_data, (I.BatchProposeMetadataEvidence));
    }
}
