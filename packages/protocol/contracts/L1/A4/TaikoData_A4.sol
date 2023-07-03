// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

library TaikoData {
    struct Config {
        // Group 1: general configs
        uint256 chainId;
        bool relaySignalRoot;
        // Group 2: block level configs
        uint256 blockMaxProposals;
        uint256 blockRingBufferSize;
        // This number is calculated from blockMaxProposals to make
        // the 'the maximum value of the multiplier' close to 20.0
        uint256 blockMaxVerificationsPerTx;
        uint32 blockMaxGasLimit;
        uint32 blockFeeBaseGas;
        uint64 blockMaxTransactions;
        uint64 blockMaxTxListBytes;
        uint256 blockTxListExpiry;
        // Group 3: proof related configs
        uint256 proofRegularCooldown;
        uint256 proofOracleCooldown;
        uint16 proofMinWindow;
        uint16 proofMaxWindow;
        // Group 4: eth deposit related configs
        uint256 ethDepositRingBufferSize;
        uint64 ethDepositMinCountPerBlock;
        uint64 ethDepositMaxCountPerBlock;
        uint96 ethDepositMinAmount;
        uint96 ethDepositMaxAmount;
        uint256 ethDepositGas;
        uint256 ethDepositMaxFee;
        // Group 5: tokenomics
        uint32 rewardPerGasRange;
        uint8 rewardOpenMultipler;
        uint256 rewardOpenMaxCount;
    }

    struct StateVariables {
        uint32 feePerGas;
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 numBlocks;
        uint64 lastVerifiedBlockId;
        uint64 nextEthDepositToProcess;
        uint64 numEthDeposits;
    }

    // 3 slots
    struct BlockMetadataInput {
        bytes32 txListHash;
        address beneficiary;
        uint32 gasLimit;
        uint24 txListByteStart; // byte-wise start index (inclusive)
        uint24 txListByteEnd; // byte-wise end index (exclusive)
        bool cacheTxListInfo;
    }

    // Changing this struct requires changing LibUtils.hashMetadata accordingly.
    struct BlockMetadata {
        uint64 id;
        uint64 timestamp;
        uint64 l1Height;
        bytes32 l1Hash;
        bytes32 mixHash;
        bytes32 txListHash;
        uint24 txListByteStart;
        uint24 txListByteEnd;
        uint32 gasLimit;
        address beneficiary;
        address treasury;
        TaikoData.EthDeposit[] depositsProcessed;
    }

    struct BlockEvidence {
        bytes32 metaHash;
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 signalRoot;
        bytes32 graffiti;
        address prover;
        uint32 parentGasUsed;
        uint32 gasUsed;
        uint16 verifierId;
        bytes proof;
    }

    // 4 slots
    struct ForkChoice {
        // Key is only written/read for the 1st fork choice.
        bytes32 key;
        bytes32 blockHash;
        bytes32 signalRoot;
        address prover;
        uint64 provenAt;
        uint32 gasUsed;
    }

    // 5 slots
    struct Block {
        // slot 1: ForkChoice storage are reusable
        mapping(uint24 forkChoiceId => ForkChoice) forkChoices;
        // slot 2
        bytes32 metaHash;
        // slot 3: (13 bytes available)
        uint64 blockId;
        uint32 gasLimit;
        uint24 nextForkChoiceId;
        uint24 verifiedForkChoiceId;
        bool proverReleased;
        // slot 4
        address proposer;
        uint32 feePerGas;
        uint64 proposedAt;
        // slot 5
        address assignedProver;
        uint32 rewardPerGas;
        uint64 proofWindow;
    }

    struct TxListInfo {
        uint64 validSince;
        uint24 size;
    }

    struct EthDeposit {
        address recipient;
        uint96 amount;
        uint64 id;
    }

    struct State {
        // Ring buffer for proposed blocks and a some recent verified blocks.
        // Same as A3
        mapping(uint256 blockId_mode_blockRingBufferSize => Block) blocks;
        //Same as A3 except uint256 forkChoice, but keep it as 256
        mapping(
            uint256 blockId
                => mapping(
                    bytes32 parentHash => mapping(uint32 parentGasUsed => uint24 forkChoiceId)
                )
            ) forkChoiceIds;
        // Same as A3
        mapping(address account => uint256 balance) taikoTokenBalances;
        // Same as A3
        mapping(bytes32 txListHash => TxListInfo) txListInfo;
        // Make it a reserved uint256 because this exists in A4 but as a ringbuffer
        //EthDeposit[] ethDeposits;
        uint256 __reserved5;
        // Never or rarely changed
        // Slot 6: never or rarely changed
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        // Not used anymore
        //uint16 adjustmentQuotient;
        uint48 numOpenBlocks; // was uint64 on alpha-4 originally, but could fit in 48 bytes
        uint64 numEthDeposits;
        // Slot 7
        // Not used anymore
        //uint64 accProposedAt;
        //uint64 accBlockFees;
        uint64 numBlocks;
        uint64 nextEthDepositToProcess;
        // Slot 8
        // Below these 2 not used anymore
        //uint64 blockFee;
        //uint64 proofTimeIssued;
        uint128 __reserved81;
        uint64 lastVerifiedBlockId;
        // Not used anymore
        //uint64 proofTimeTarget;
        uint64 __reserved82;
        // Slot 9
        uint32 feePerGas;
        uint16 avgProofDelay;
        uint64 lastVerifiedAt;
        uint144 __reserved91;
        // Slot 10
        mapping(uint256 depositId_mode_ethDepositRingBufferSize => uint256) ethDeposits;
        // Reserved
        uint256[40] __gap;
    }
}
