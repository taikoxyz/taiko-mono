// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibSummary.sol";

library LibInit2 {
    error InvalidGenesisBlockHash();

    function init(
        I.State storage $,
        uint48 _genesisBlockTimestamp,
        bytes32 _genesisBlockHash
    )
        internal
    {
        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());

        I.BatchMetadata memory meta;
        meta.buildMeta.lastBlockTimestamp = _genesisBlockTimestamp;
        meta.buildMeta.proposedIn = uint48(block.number);
        meta.proposeMeta.lastBlockTimestamp = _genesisBlockTimestamp;
        meta.proveMeta.proposedAt = uint48(block.timestamp);

        $.batches[0] = hashBatch(0, meta);

        I.Summary memory summary;
        summary.numBatches = 1;

        LibSummary.updateSummary($, summary, false);
        emit I.BatchesVerified(0, _genesisBlockHash);
    }

    function hashBatch(
        uint256 batchId,
        I.BatchMetadata memory meta
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 buildMetaHash = keccak256(abi.encode(meta.buildMeta));
        bytes32 proposeMetaHash = keccak256(abi.encode(meta.proposeMeta));
        bytes32 proveMetaHash = keccak256(abi.encode(meta.proveMeta));
        bytes32 leftHash = keccak256(abi.encode(batchId, buildMetaHash));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, proveMetaHash));
        return keccak256(abi.encode(leftHash, rightHash));
    }
}
