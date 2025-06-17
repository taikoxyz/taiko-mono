// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox as I } from "../ITaikoInbox.sol";

/// @title LibInit
/// @custom:security-contact security@taiko.xyz
library LibInit {
    function init(I.State storage $, bytes32 _genesisBlockHash) public {
        require(_genesisBlockHash != 0, I.InvalidGenesisBlockHash());
        $.transitions[0][1].blockHash = _genesisBlockHash;

        I.Batch storage batch = $.batches[0];
        batch.metaHash = bytes32(uint256(1));
        batch.lastBlockTimestamp = uint64(block.timestamp);
        batch.anchorBlockId = uint64(block.number);
        batch.nextTransitionId = 2;
        batch.verifiedTransitionId = 1;

        $.stats1.genesisHeight = uint64(block.number);

        $.stats2.lastProposedIn = uint56(block.number);
        $.stats2.numBatches = 1;

        emit I.BatchesVerified(0, _genesisBlockHash);
    }
}
