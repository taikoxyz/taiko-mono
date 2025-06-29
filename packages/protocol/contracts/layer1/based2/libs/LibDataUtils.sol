// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

library LibDataUtils {
    function hashBatch(
        uint256 _batchId,
        I.BatchMetadata memory _meta
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 buildMetaHash = keccak256(abi.encode(_meta.buildMeta));
        bytes32 proposeMetaHash = keccak256(abi.encode(_meta.proposeMeta));
        bytes32 proveMetaHash = keccak256(abi.encode(_meta.proveMeta));
        bytes32 leftHash = keccak256(abi.encode(_batchId, buildMetaHash));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, proveMetaHash));
        return keccak256(abi.encode(leftHash, rightHash));
    }

    function hashBatch(I.BatchProposeMetadataEvidence memory _evidence)
        public
        pure
        returns (bytes32)
    {
        bytes32 proposeMetaHash = keccak256(abi.encode(_evidence.proposeMeta));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, _evidence.proveMetaHash));
        return keccak256(abi.encode(_evidence.idAndBuildHash, rightHash));
    }

    /// @dev The function __encodeExtraDataLower128Bits encodes certain information into a uint128
    /// - bits 0-7: used to store _conf.baseFeeConfig.sharingPctg.
    /// - bit 8: used to store _batch.isForcedInclusion.
    function encodeExtraDataLower128Bits(
        I.Config memory _conf,
        I.Batch memory _batch
    )
        internal
        pure
        returns (bytes32)
    {
        uint128 v = _conf.baseFeeConfig.sharingPctg; // bits 0-7
        v |= _batch.isForcedInclusion ? 1 << 8 : 0; // bit 8
        return bytes32(uint256(v));
    }

    function packBatchMetadata(I.BatchMetadata memory _meta) internal pure returns (bytes memory) {
        return abi.encode(_meta);
    }
}
