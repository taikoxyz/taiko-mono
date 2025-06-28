// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibData2.sol";

library LibInit2 {
    function init(I.State storage $, bytes32 _genesisBlockHash) internal {
        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());

        I.BatchMetadata memory meta;
        meta.buildMeta.proposedIn = uint48(block.number);
        meta.proveMeta.proposedAt = uint48(block.timestamp);
        $.batches[0] = LibData2.hashBatch(0, meta);

        I.Summary memory summary;
        summary.numBatches = 1;
        $.summaryHash = keccak256(abi.encode(summary));

        emit I.BatchesVerified(0, _genesisBlockHash);
    }

    // --- ERRORs --------------------------------------------------------------------------------
    error InvalidGenesisBlockHash();
}
