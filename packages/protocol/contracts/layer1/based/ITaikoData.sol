// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";

interface ITaikoData {
    struct AnchorBlock2 {
        uint256 id;
        bytes32 blockHash;
    }

    struct BlockParams2 {
        uint256 numTransactions;
        uint256 timeShift;
        bytes32[] signalSlots;
        uint256 anchorBlockId;
    }

    struct BatchVerifyMeta {
        uint256 lastBlockId;
        uint256 provabilityBond;
        uint256 livenessBond;
        bytes32 proveMetaHash;
    }

    struct BatchProveMetadata {
        address proposer;
        address prover;
        uint256 proposedAt;
        uint256 firstBlockId;
        bytes32 proposeMetaHash;
        uint256 provabilityBond;
    }

    struct BatchProposeMetadata {
        uint256 lastBlockTimestamp;
        uint256 lastBlockId;
        uint256 lastAnchorBlockId;
        bytes32 buildMetaHash;
    }

    struct BatchBuildMetadata {
        bytes32 txsHash;
        bytes32[] blobHashes;
        bytes32 extraData;
        address coinbase;
        uint256 proposedIn;
        uint256 blobCreatedIn;
        uint256 blobByteOffset;
        uint256 blobByteSize;
        uint256 gasLimit;
        uint256 lastBlockId;
        uint256 lastBlockTimestamp;
        AnchorBlock2[] anchorBlocks;
        BlockParams2[] blocks;
        LibSharedData.BaseFeeConfig baseFeeConfig;
    }

    struct BatchMetadata2 {
        BatchVerifyMeta verifyMeta;
        BatchProveMetadata proveMeta;
        BatchProposeMetadata proposeMeta;
        BatchBuildMetadata buildMeta;
    }

    struct Batch2 {
        uint64 blockId;
        uint24 verifiedTransitionId;
        uint24 nextTransitionId;
        bytes32 metaHash;
    }
}
