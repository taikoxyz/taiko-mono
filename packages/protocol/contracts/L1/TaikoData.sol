// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

library TaikoData {
    struct FeeConfig {
        uint16 avgTimeMAF;
        uint64 avgTimeCap; // miliseconds
        uint16 gracePeriodPctg;
        uint16 maxPeriodPctg;
        // extra fee/reward on top of baseFee
        uint16 multiplerPctg;
    }

    struct Config {
        uint256 chainId;
        // up to 2048 pending blocks
        uint256 maxNumBlocks;
        // This number is calculated from maxNumBlocks to make
        // the 'the maximum value of the multiplier' close to 20.0
        uint256 maxVerificationsPerTx;
        uint256 blockMaxGasLimit;
        uint256 maxTransactionsPerBlock;
        uint256 maxBytesPerTxList;
        uint256 minTxGasLimit;
        uint256 slotSmoothingFactor;
        uint256 anchorTxGasLimit;
        uint256 rewardBurnBips;
        uint256 proposerDepositPctg;
        // Moving average factors
        uint256 feeBaseMAF;
        uint64 bootstrapDiscountHalvingPeriod;
        uint64 constantFeeRewardBlocks;
        uint64 txListCacheExpiry;
        bool enableSoloProposer;
        bool enableOracleProver;
        bool enableTokenomics;
        bool skipZKPVerification;
        FeeConfig proposingConfig;
        FeeConfig provingConfig;
    }

    struct StateVariables {
        uint64 feeBaseTwei;
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 nextBlockId;
        uint64 lastBlockId;
        uint64 avgBlockTime;
        uint64 avgProofTime;
        uint64 lastProposedAt;
    }

    // 3 slots
    struct BlockMetadataInput {
        bytes32 txListHash;
        address beneficiary;
        uint32 gasLimit;
        uint24 txListByteStart; // byte-wise start index (inclusive)
        uint24 txListByteEnd; // byte-wise end index (exclusive)
        uint8 cacheTxListInfo; // non-zero = True
    }

    // 5 slots
    struct BlockMetadata {
        uint64 blockId;
        uint32 gasLimit;
        uint64 timestamp;
        uint64 l1Height;
        bytes32 l1Hash;
        bytes32 mixHash;
        bytes32 txListHash;
        uint24 txListByteStart;
        uint24 txListByteEnd;
        address beneficiary;
    }

    struct ZKProof {
        bytes data;
        uint16 verifierId;
    }

    struct BlockEvidence {
        TaikoData.BlockMetadata meta;
        ZKProof zkproof;
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 signalRoot;
        address prover;
    }

    struct ForkChoice {
        bytes32 blockHash;
        bytes32 signalRoot;
        address prover;
        uint64 provenAt;
    }

    // 3 slots
    struct BlockSpec {
        bytes32 metaHash;
        uint256 deposit;
        address proposer;
        uint64 proposedAt;
        uint24 nextForkChoiceId;
    }

    struct Block {
        BlockSpec spec;
        mapping(uint256 index => ForkChoice) forkChoices;
    }

    // This struct takes 9 slots.
    struct TxListInfo {
        uint64 validSince;
        uint24 size;
    }

    struct ChainData {
        uint64 blockId;
    bytes32 blockHash;
    bytes32 signalRoot;
}

    struct State {
        mapping(uint256 blockId /* % maxNumBlocks */ => Block) blocks;
        mapping(uint256 blockId => ChainData) chainData;
        // solhint-disable-next-line max-line-length
        mapping(bytes32 parentHash => mapping(uint256 blockId => uint256 forkChoiceId)) forkChoiceIds;
        // solhint-disable-next-line max-line-length
        mapping(address account => uint256 balance) balances;
        mapping(bytes32 txListHash => TxListInfo) txListInfo;
        // Never or rarely changed
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 __reserved1;
        uint64 __reserved2;
        // Changed when a block is proposed or proven/finalized
        // Changed when a block is proposed
        uint64 nextBlockId;
        uint64 lastProposedAt; // Timestamp when the last block is proposed.
        uint64 avgBlockTime; // miliseconds
        uint64 __reserved3;
        // Changed when a block is proven/finalized
        uint64 __reserved4;
        uint64 lastBlockId;
        // the proof time moving average, note that for each block, only the
        // first proof's time is considered.
        uint64 avgProofTime; // miliseconds
        uint64 feeBaseTwei;
        // Reserved
        uint256[41] __gap;
    }
}
