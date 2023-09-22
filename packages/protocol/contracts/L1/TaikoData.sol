// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title TaikoData
/// @notice This library defines various data structures used in the Taiko
/// protocol.
library TaikoData {
    /// @dev Struct holding Taiko configuration parameters. See {TaikoConfig}.
    struct Config {
        // ---------------------------------------------------------------------
        // Group 1: General configs
        // ---------------------------------------------------------------------
        // The chain ID of the network where Taiko contracts are deployed.
        uint256 chainId;
        // Flag indicating whether the relay signal root is enabled or not.
        bool relaySignalRoot;
        // ---------------------------------------------------------------------
        // Group 2: Block level configs
        // ---------------------------------------------------------------------
        // The maximum number of proposals allowed in a single block.
        uint64 blockMaxProposals;
        // Size of the block ring buffer, allowing extra space for proposals.
        uint64 blockRingBufferSize;
        // The maximum number of verifications allowed per transaction in a
        // block.
        uint64 blockMaxVerificationsPerTx;
        // The maximum gas limit allowed for a block.
        uint32 blockMaxGasLimit;
        // The base gas for processing a block.
        uint32 blockFeeBaseGas;
        // The maximum allowed bytes for the proposed transaction list calldata.
        uint24 blockMaxTxListBytes;
        // Amount of token to reward to the first block propsoed in each L1
        // block.
        uint256 proposerRewardPerSecond;
        uint256 proposerRewardMax;
        // ---------------------------------------------------------------------
        // Group 3: Proof related configs
        // ---------------------------------------------------------------------
        // The amount of Taiko token as a zk proof bond
        uint96 assignmentBond;
        // ---------------------------------------------------------------------
        // Group 4: ETH deposit related configs
        // ---------------------------------------------------------------------
        // The size of the ETH deposit ring buffer.
        uint256 ethDepositRingBufferSize;
        // The minimum number of ETH deposits allowed per block.
        uint64 ethDepositMinCountPerBlock;
        // The maximum number of ETH deposits allowed per block.
        uint64 ethDepositMaxCountPerBlock;
        // The minimum amount of ETH required for a deposit.
        uint96 ethDepositMinAmount;
        // The maximum amount of ETH allowed for a deposit.
        uint96 ethDepositMaxAmount;
        // The gas cost for processing an ETH deposit.
        uint256 ethDepositGas;
        // The maximum fee allowed for an ETH deposit.
        uint256 ethDepositMaxFee;
    }

    /// @dev Struct holding state variables.
    struct StateVariables {
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 nextEthDepositToProcess;
        uint64 numEthDeposits;
        uint64 numBlocks;
        uint64 lastVerifiedBlockId;
    }

    /// @dev Struct representing prover assignment
    struct TierFee {
        uint16 tier;
        uint256 fee;
    }

    struct ProverAssignment {
        address prover;
        address feeToken;
        TierFee[] tierFees;
        uint64 expiry;
        bytes signature;
    }

    /// @dev Struct containing data only required for proving a block
    /// Warning: changing this struct requires changing
    /// {LibProposing.hashMetadata} accordingly.
    struct BlockMetadata {
        bytes32 l1Hash;
        bytes32 mixHash;
        bytes32 txListHash;
        uint64 id;
        uint64 timestamp;
        uint64 l1Height;
        uint32 gasLimit;
        TaikoData.EthDeposit[] depositsProcessed;
    }

    /// @dev Struct representing block evidence.
    struct BlockEvidence {
        bytes32 metaHash;
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 signalRoot;
        bytes32 graffiti;
        uint16 tier;
        bytes proof;
    }

    /// @dev Struct representing state transition data.
    /// 10 slots reserved for upgradability, 6 slots used.
    struct Transition {
        bytes32 key; // slot 1, only written/read for the 1st state transition.
        bytes32 blockHash; // slot 2
        bytes32 signalRoot; // slot 3
        address prover; // slot 4
        uint96 proofBond;
        address contester; // slot 5
        uint96 contestBond;
        uint64 timestamp; // slot 6 (82 bits)
        uint16 tier;
        bytes32[4] __reserved;
    }

    /// @dev Struct containing data required for verifying a block.
    /// 10 slots reserved for upgradability, 3 slots used.
    struct Block {
        bytes32 metaHash; // slot 1
        address assignedProver; // slot 2
        uint96 assignmentBond;
        uint64 blockId; // slot 3
        uint64 proposedAt;
        uint32 nextTransitionId;
        uint32 verifiedTransitionId;
        uint16 minTier;
        bytes32[7] __reserved;
    }

    /// @dev Struct representing information about a transaction list.
    /// 1 slot used.
    struct TxListInfo {
        uint64 validSince;
        uint24 size;
    }

    /// @dev Struct representing an Ethereum deposit.
    /// 1 slot used.
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
        uint64 numEthDeposits;
        uint64 nextEthDepositToProcess;
    }

    struct SlotB {
        uint64 numBlocks;
        uint64 nextEthDepositToProcess;
        uint64 lastVerifiedAt;
        uint64 lastVerifiedBlockId;
    }

    /// @dev Struct holding the state variables for the {TaikoL1} contract.
    struct State {
        // Ring buffer for proposed blocks and a some recent verified blocks.
        mapping(uint64 blockId_mod_blockRingBufferSize => Block) blocks;
        // Indexing to transition ids (ring buffer not possible)
        mapping(
            uint64 blockId => mapping(bytes32 parentHash => uint32 transitionId)
            ) transitionIds;
        // Ring buffer for transitions
        mapping(
            uint64 blockId_mod_blockRingBufferSize
                => mapping(uint32 transitionId => Transition)
            ) transitions;
        // Ring buffer for Ether deposits
        mapping(uint256 depositId_mod_ethDepositRingBufferSize => uint256)
            ethDeposits;
        SlotA slotA; // slot 5
        SlotB slotB; // slot 6
        uint256[144] __gap;
    }
}
