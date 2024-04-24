// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title TaikoData
/// @notice This library defines various data structures used in the Taiko
/// protocol.
/// @custom:security-contact security@taiko.xyz
library TaikoData {
    /// @dev Struct holding Taiko configuration parameters. See {TaikoConfig}.
    struct Config {
        // ---------------------------------------------------------------------
        // Group 1: General configs
        // ---------------------------------------------------------------------
        // The chain ID of the network where Taiko contracts are deployed.
        uint64 chainId;
        // ---------------------------------------------------------------------
        // Group 2: Block level configs
        // ---------------------------------------------------------------------
        // The maximum number of proposals allowed in a single block.
        uint64 blockMaxProposals;
        // Size of the block ring buffer, allowing extra space for proposals.
        uint64 blockRingBufferSize;
        // The maximum number of verifications allowed when a block is proposed.
        uint64 maxBlocksToVerifyPerProposal;
        // The maximum gas limit allowed for a block.
        uint32 blockMaxGasLimit;
        // ---------------------------------------------------------------------
        // Group 3: Proof related configs
        // ---------------------------------------------------------------------
        // The amount of Taiko token as a prover liveness bond
        uint96 livenessBond;
        // ---------------------------------------------------------------------
        // Group 4: Cross-chain sync
        // ---------------------------------------------------------------------
        // The max number of L2 blocks that can stay unsynced on L1 (a value of zero disables
        // syncing)
        uint8 blockSyncThreshold;
    }

    /// @dev Struct representing prover fees per given tier
    struct TierFee {
        uint16 tier;
        uint128 fee;
    }

    /// @dev A proof and the tier of proof it belongs to
    struct TierProof {
        uint16 tier;
        bytes data;
    }

    /// @dev Hook and it's data (currently used only during proposeBlock)
    struct HookCall {
        address hook;
        bytes data;
    }

    /// @dev Represents proposeBlock's _data input parameter
    struct BlockParams {
        address assignedProver;
        address coinbase;
        bytes32 extraData;
        bytes32 parentMetaHash;
        HookCall[] hookCalls;
        bytes signature;
    }

    /// @dev Struct containing data only required for proving a block
    /// Note: On L2, `block.difficulty` is the pseudo name of
    /// `block.prevrandao`, which returns a random number provided by the layer
    /// 1 chain.
    struct BlockMetadata {
        bytes32 l1Hash;
        bytes32 difficulty;
        bytes32 blobHash; //or txListHash (if Blob not yet supported)
        bytes32 extraData;
        bytes32 depositsHash;
        address coinbase; // L2 coinbase,
        uint64 id;
        uint32 gasLimit;
        uint64 timestamp;
        uint64 l1Height;
        uint16 minTier;
        bool blobUsed;
        bytes32 parentMetaHash;
        address sender; // a.k.a proposer
    }

    /// @dev Struct representing transition to be proven.
    struct Transition {
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
        bytes32 graffiti; // Arbitrary data that the prover can use for various purposes.
    }

    /// @dev Struct representing state transition data.
    /// 10 slots reserved for upgradability, 6 slots used.
    struct TransitionState {
        bytes32 key; // slot 1, only written/read for the 1st state transition.
        bytes32 blockHash; // slot 2
        bytes32 stateRoot; // slot 3
        address prover; // slot 4
        uint96 validityBond;
        address contester; // slot 5
        uint96 contestBond;
        uint64 timestamp; // slot 6 (90 bits)
        uint16 tier;
        uint8 __reserved1;
    }

    /// @dev Struct containing data required for verifying a block.
    /// 3 slots used.
    struct Block {
        bytes32 metaHash; // slot 1
        address assignedProver; // slot 2
        uint96 livenessBond;
        uint64 blockId; // slot 3
        uint64 proposedAt; // timestamp
        uint64 proposedIn; // L1 block number, required/used by node/client.
        uint32 nextTransitionId;
        uint32 verifiedTransitionId;
    }

    /// @dev Struct representing an Ethereum deposit.
    /// 2 slot used. Currently removed from protocol, but to be backwards compatible, the struct and
    /// return values stayed for now.
    struct EthDeposit {
        address recipient;
        uint96 amount;
        uint64 id;
    }

    /// @dev Forge is only able to run coverage in case the contracts by default
    /// capable of compiling without any optimization (neither optimizer runs,
    /// no compiling --via-ir flag).
    /// In order to resolve stack too deep without optimizations, we needed to
    /// introduce outsourcing vars into structs below.
    struct SlotA {
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 lastSyncedBlockId;
        uint64 lastSynecdAt; // typo!
    }

    struct SlotB {
        uint64 numBlocks;
        uint64 lastVerifiedBlockId;
        bool provingPaused;
        uint8 __reservedB1;
        uint16 __reservedB2;
        uint32 __reservedB3;
        uint64 lastUnpausedAt;
    }

    /// @dev Struct holding the state variables for the {TaikoL1} contract.
    struct State {
        // Ring buffer for proposed blocks and a some recent verified blocks.
        mapping(uint64 blockId_mod_blockRingBufferSize => Block blk) blocks;
        // Indexing to transition ids (ring buffer not possible)
        mapping(uint64 blockId => mapping(bytes32 parentHash => uint32 transitionId)) transitionIds;
        // Ring buffer for transitions
        mapping(
            uint64 blockId_mod_blockRingBufferSize
                => mapping(uint32 transitionId => TransitionState ts)
            ) transitions;
        // Ring buffer for Ether deposits
        bytes32 __reserve1;
        SlotA slotA; // slot 5
        SlotB slotB; // slot 6
        uint256[44] __gap;
    }
}
