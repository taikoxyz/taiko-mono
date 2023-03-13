// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {ChainData} from "../common/IXchainSync.sol";

library TaikoData {
    struct FeeConfig {
        uint64 avgTimeMAF;
        uint64 avgTimeCap;
        uint64 gracePeriodPctg;
        uint64 maxPeriodPctg;
        // extra fee/reward on top of baseFee
        uint64 multiplerPctg;
    }

    struct Config {
        uint256 chainId;
        // up to 2048 pending blocks
        uint256 maxNumBlocks;
        uint256 blockHashHistory;
        // This number is calculated from maxNumBlocks to make
        // the 'the maximum value of the multiplier' close to 20.0
        uint256 maxVerificationsPerTx;
        uint256 blockMaxGasLimit;
        uint256 maxTransactionsPerBlock;
        uint256 maxBytesPerTxList;
        uint256 minTxGasLimit;
        uint256 slotSmoothingFactor;
        uint256 rewardBurnBips;
        uint256 proposerDepositPctg;
        // Moving average factors
        uint256 feeBaseMAF;
        uint64 bootstrapDiscountHalvingPeriod;
        uint64 constantFeeRewardBlocks;
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

    struct BlockMetadataInput {
        bytes32 txListHash;
        address beneficiary;
        uint64 gasLimit;
    }

    struct BlockMetadata {
        uint256 id;
        uint256 l1Height;
        bytes32 l1Hash;
        bytes32 mixHash;
        bytes32 txListHash;
        address beneficiary;
        uint64 gasLimit;
        uint64 timestamp;
    }

    struct ZKProof {
        bytes data;
        uint256 circuitId;
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
        ChainData chainData;
        address prover;
        uint64 provenAt;
    }

    // 3 slots
    struct ProposedBlock {
        bytes32 metaHash;
        uint256 deposit;
        address proposer;
        uint64 proposedAt;
        uint32 nextForkChoiceId;
    }

    // This struct takes 9 slots.
    struct State {
        mapping(uint256 blockId => ProposedBlock proposedBlock) proposedBlocks;
        // solhint-disable-next-line max-line-length
        mapping(uint256 blockId => mapping(bytes32 parentHash => uint256 forkChoiceId)) forkChoiceIds;
        mapping(uint256 blockId => mapping(uint256 index => ForkChoice)) forkChoices;
        // solhint-disable-next-line max-line-length
        mapping(uint256 blockNumber => ChainData) l2ChainDatas;
        mapping(address prover => uint256 outstandingReward) balances;
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
        uint256[42] __gap;
    }
}
