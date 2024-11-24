// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";

/// @title TaikoData
/// @notice This library defines various data structures used in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library TaikoData {
    struct BlockParamsV3 {
        address proposer;
        address coinbase;
        bytes32 parentMetaHash;
        uint64 anchorBlockId;
        uint64 timestamp;
        uint32 blobTxListOffset;
        uint32 blobTxListLength;
        uint8 blobIndex;
    }

    struct BlockMetadataV3 {
        bytes32 anchorBlockHash;
        bytes32 difficulty;
        bytes32 blobHash;
        bytes32 extraData;
        address coinbase;
        uint64 id;
        uint32 gasLimit;
        uint64 timestamp;
        uint64 anchorBlockId; 
        bytes32 parentMetaHash;
        address proposer;
        uint96 livenessBond;
        uint64 proposedAt; // Used by node/client post block proposal.
        uint64 proposedIn; // Used by node/client post block proposal.
        uint32 blobTxListOffset;
        uint32 blobTxListLength;
        uint8 blobIndex;
        LibSharedData.BaseFeeConfig baseFeeConfig;
    }

    /// @notice Struct representing transition to be proven.
    struct TransitionV3 {
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    /// @notice Struct representing state transition data.
    /// @notice 6 slots used.
    struct TransitionStateV3 {
        bytes32 key; // slot 1, only written/read for the 1st state transition.
        bytes32 blockHash; // slot 2
        bytes32 stateRoot; // slot 3
        address prover; // slot 4
        uint96 validityBond; // DEPRECATED!!!
        address contester; // slot 5, DEPRECATED!!!
        uint96 contestBond; // DEPRECATED!!!
        uint64 timestamp; // slot 6 (88 bits)
        uint16 tier; // DEPRECATED!!!
    }

    /// @notice Struct containing data required for verifying a block.
    /// @notice 3 slots used.
    struct BlockV3 {
        bytes32 metaHash; // slot 1
        address assignedProver; // DEPRECATED!!!
        uint96 livenessBond; // DEPRECATED!!!
        uint64 blockId; // slot 3
        uint64 timestamp;
        uint64 anchorBlockId;
        uint24 nextTransitionId;
        bool livenessBondReturned;
        // The ID of the transaction that is used to verify this block. However, if this block is
        // not verified as the last block in a batch, verifiedTransitionId will remain zero.
        uint24 verifiedTransitionId;
    }

    /// @notice DEPRECATED but used by node/client for syncing old blocks
    /// @notice A proof and the tier of proof it belongs to.
    struct TypedProof {
        uint16 tier;
        bytes data;
    }

    /// @notice Forge is only able to run coverage in case the contracts by default capable of
    /// compiling without any optimization (neither optimizer runs, no compiling --via-ir flag).
    /// @notice In order to resolve stack too deep without optimizations, we needed to introduce
    /// outsourcing vars into structs below.
    struct SlotA {
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 lastSyncedBlockId;
        uint64 lastSyncedAt; // known typo (lastSyncedAt)
    }

    struct SlotB {
        uint64 numBlocks;
        uint64 lastVerifiedBlockId;
        bool provingPaused;
        uint56 lastProposedIn;
        uint64 lastUnpausedAt;
    }

    /// @notice Struct holding Taiko configuration parameters. See {TaikoConfig}.
    struct ConfigV3 {
        /// @notice The chain ID of the network where Taiko contracts are deployed.
        uint64 chainId;
        /// @notice The maximum number of verifications allowed when a block is proposed or proved.
        uint64 blockMaxProposals;
        /// @notice Size of the block ring buffer, allowing extra space for proposals.
        uint64 blockRingBufferSize;
        /// @notice The maximum number of verifications allowed when a block is proposed or proved.
        uint64 maxBlocksToVerify;
        /// @notice The maximum gas limit allowed for a block.
        uint32 blockMaxGasLimit;
        /// @notice The amount of Taiko token as a prover liveness bond.
        uint96 livenessBond;
        /// @notice The number of L2 blocks between each L2-to-L1 state root sync.
        uint8 stateRootSyncInternal;
        /// @notice The max differences of the anchor height and the current block number.
        uint64 maxAnchorHeightOffset;
        /// @notice Base fee configuration
        LibSharedData.BaseFeeConfig baseFeeConfig;
        /// @notie The Ontake fork height on L2.
        uint64 pacayaForkHeight;
    }

    /// @notice Struct holding the state variables for the {TaikoL1} contract.
    struct State {
        // Ring buffer for proposed blocks and a some recent verified blocks.
        mapping(uint64 blockId_mod_blockRingBufferSize => BlockV3 blk) blocks;
        // Indexing to transition ids (ring buffer not possible)
        mapping(uint64 blockId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
        // Ring buffer for transitions
        mapping(
            uint64 blockId_mod_blockRingBufferSize
                => mapping(uint24 transitionId => TransitionStateV3 ts)
        ) transitions;
        bytes32 __reserve1; // Used as a ring buffer for Ether deposits
        SlotA slotA; // slot 5
        SlotB slotB; // slot 6
        mapping(address account => uint256 bond) bondBalance;
        uint256[43] __gap;
    }
}
