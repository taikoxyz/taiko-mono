// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

/// @author dantaik <dan@taiko.xyz>
library TaikoData {
    struct Config {
        uint256 chainId;
        // up to 2048 pending blocks
        uint256 maxNumBlocks;
        uint256 blockHashHistory;
        // This number is calculated from maxNumBlocks to make
        // the 'the maximum value of the multiplier' close to 20.0
        uint256 zkProofsPerBlock;
        uint256 maxVerificationsPerTx;
        uint256 commitConfirmations;
        uint256 maxProofsPerForkChoice;
        uint256 blockMaxGasLimit;
        uint256 maxTransactionsPerBlock;
        uint256 maxBytesPerTxList;
        uint256 minTxGasLimit;
        uint256 anchorTxGasLimit;
        uint256 slotSmoothingFactor;
        uint256 rewardBurnBips;
        uint256 proposerDepositPctg;
        // Moving average factors
        uint256 feeBaseMAF;
        uint256 blockTimeMAF;
        uint256 proofTimeMAF;
        uint64 rewardMultiplierPctg;
        uint64 feeGracePeriodPctg;
        uint64 feeMaxPeriodPctg;
        uint64 blockTimeCap;
        uint64 proofTimeCap;
        uint64 bootstrapDiscountHalvingPeriod;
        uint64 initialUncleDelay;
        bool enableTokenomics;
        bool enablePublicInputsCheck;
        bool enableProofValidation;
        bool enableOracleProver;
    }

    struct BlockMetadata {
        uint256 id;
        uint256 l1Height;
        bytes32 l1Hash;
        address beneficiary;
        bytes32 txListHash;
        bytes32 mixHash;
        bytes extraData;
        uint64 gasLimit;
        uint64 timestamp;
        uint64 commitHeight;
        uint64 commitSlot;
    }

    // 3 slots
    struct ProposedBlock {
        bytes32 metaHash;
        uint256 deposit;
        address proposer;
        uint64 proposedAt;
    }

    // 3 + n slots
    struct ForkChoice {
        bytes32 blockHash;
        uint64 provenAt;
        address[] provers;
    }

    // This struct takes 9 slots.
    struct State {
        // block id => block hash (some blocks' hashes won't be persisted,
        // only the latest one if verified in a batch)
        mapping(uint256 => bytes32) l2Hashes;
        // block id => ProposedBlock
        mapping(uint256 => ProposedBlock) proposedBlocks;
        // block id => parent hash => fork choice
        mapping(uint256 => mapping(bytes32 => ForkChoice)) forkChoices;
        // proposer => commitSlot => hash(commitHash, commitHeight)
        mapping(address => mapping(uint256 => bytes32)) commits;
        // Never or rarely changed
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 __reservedA1;
        uint64 statusBits; // rarely change
        // Changed when a block is proposed or proven/finalized
        uint256 feeBase;
        // Changed when a block is proposed
        uint64 nextBlockId;
        uint64 lastProposedAt; // Timestamp when the last block is proposed.
        uint64 avgBlockTime; // The block time moving average
        uint64 __avgGasLimit; // the block gaslimit moving average, not updated.
        // Changed when a block is proven/finalized
        uint64 latestVerifiedHeight;
        uint64 latestVerifiedId;
        // the proof time moving average, note that for each block, only the
        // first proof's time is considered.
        uint64 avgProofTime;
        uint64 __reservedC1;
        // Reserved
        uint256[42] __gap;
    }
}
