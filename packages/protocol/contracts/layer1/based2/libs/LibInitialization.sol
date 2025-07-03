// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibDataUtils.sol";

/// @title LibInitialization
/// @notice Library for initializing the Taiko protocol state
/// @custom:security-contact security@taiko.xyz
library LibInitialization {
    // -------------------------------------------------------------------------
    // Public Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the protocol state with the genesis block
    /// @param $ The state storage
    /// @param _genesisBlockHash The hash of the genesis block
    function init(I.State storage $, bytes32 _genesisBlockHash) public {
        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());

        // Initialize the genesis batch metadata
        I.BatchMetadata memory meta;
        meta.buildMeta.proposedIn = uint48(block.number);
        meta.proveMeta.proposedAt = uint48(block.timestamp);
        $.batches[0] = LibDataUtils.hashBatch(0, meta);

        // Initialize the summary
        I.Summary memory summary;
        summary.numBatches = 1;
        $.summaryHash = keccak256(abi.encode(summary));

        emit I.BatchesVerified(0, _genesisBlockHash);
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when the genesis block hash is invalid (zero)
    error InvalidGenesisBlockHash();
}
