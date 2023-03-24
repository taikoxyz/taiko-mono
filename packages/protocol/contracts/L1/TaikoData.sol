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
        uint256 maxNumProposedBlocks;
        uint256 maxNumVerifiedBlocks;
        // This number is calculated from maxNumProposedBlocks to make
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
        uint64 numBlocks;
        uint64 lastVerifiedBlockId;
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
        uint64 id;
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
        uint64 gasUsed;
    }

    struct ForkChoice {
        bytes32 blockHash;
        bytes32 signalRoot;
        address prover;
        uint64 provenAt;
    }

    // 4 slots
    struct ProposedBlock {
        bytes32 metaHash;
        uint256 deposit;
        address proposer;
        uint64 proposedAt;
        uint24 nextForkChoiceId;
        // ForkChoice storage are reusable
        mapping(uint256 forkChoiceId => ForkChoice) forkChoices;
    }

    // 3 slots
    struct VerifiedBlock {
        uint64 blockId;
        bytes32 blockHash;
        bytes32 signalRoot;
    }

    // This struct takes 9 slots.
    struct TxListInfo {
        uint64 validSince;
        uint24 size;
    }

    struct State {
        // Ring buffer for proposed but unverified blocks.
        mapping(uint256 blockId_mode_maxNumProposedBlocks => ProposedBlock) proposedBlocks;
        // Ring buffer for recent verified blocks.
        // It shall be big enough to cache the last verified block's hash and
        // signal root for long enough so signals can be verified anytime within
        // 30 minutes.
        mapping(uint256 blockId_mode_maxNumVerifiedBlocks => VerifiedBlock) verifiedBlocks;
        // A mapping from (blockId, parentHash) to a reusable ForkChoice storage pointer.
        // solhint-disable-next-line max-line-length
        mapping(uint256 blockId => mapping(bytes32 parentHash => uint256 forkChoiceId)) forkChoiceIds;
        mapping(address account => uint256 balance) balances;
        mapping(bytes32 txListHash => TxListInfo) txListInfo;
        // Never or rarely changed
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 __reserved1;
        uint64 __reserved2;
        // Changed when a block is proposed or proven/finalized
        // Changed when a block is proposed
        uint64 numBlocks;
        uint64 lastProposedAt; // Timestamp when the last block is proposed.
        uint64 avgBlockTime; // miliseconds
        uint64 __reserved3;
        // Changed when a block is proven/finalized
        uint64 __reserved4;
        uint64 lastVerifiedBlockId;
        // the proof time moving average, note that for each block, only the
        // first proof's time is considered.
        uint64 avgProofTime; // miliseconds
        uint64 feeBaseTwei;
        // Reserved
        uint256[42] __gap;
    }
}
