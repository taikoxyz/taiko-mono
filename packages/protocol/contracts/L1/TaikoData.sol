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
	    uint256 proofCooldownPeriod; //A3 lib related
        uint256 systemProofCooldownPeriod; //A3 lib related
        uint256 proofRegularCooldown;
        uint256 proofOracleCooldown;
	    uint256 realProofSkipSize;
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
    
    struct StateVariables_A3 {
        uint64 blockFee;
        uint64 accBlockFees;
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 numBlocks;
        uint64 proofTimeIssued;
        uint64 proofTimeTarget;
        uint64 lastVerifiedBlockId;
        uint64 accProposedAt;
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
        uint8 cacheTxListInfo; // uint8 to bool, (should not require change)
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
        uint64 provenAt;
        address prover;
        uint32 gasUsed;
    }

    // 5 slots
    struct Block {
        // slot 1: ForkChoice storage are reusable
        mapping(uint256 forkChoiceId => ForkChoice) forkChoices;
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
    
    // 4 slots
    struct Block_A3 {
        // ForkChoice storage are reusable
        mapping(uint256 forkChoiceId => ForkChoice) forkChoices;
        uint64 blockId;
        uint64 proposedAt;
        uint24 nextForkChoiceId;
        uint24 verifiedForkChoiceId;
        bytes32 metaHash;
        address proposer;
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

    struct Slot6 {
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint16 adjustmentQuotient;
        uint32 feePerGas;
        uint16 avgProofDelay;
        uint64 numOpenBlocks;
    }

    struct Slot7 {
        uint64 accProposedAt;
        uint64 accBlockFees;
        uint64 numBlocks;
        uint64 nextEthDepositToProcess;
    }

    struct Slot8 {
        uint64 blockFee;
        uint64 proofTimeIssued;
        uint64 lastVerifiedBlockId;
        uint64 proofTimeTarget;
    }

    struct State {
        // Ring buffer for (A3) proposed blocks and a some recent verified blocks.
        mapping(uint256 blockId_mode_blockRingBufferSize => Block_A3) blocks_A3;
        mapping(
            uint256 blockId
                => mapping(
                    bytes32 parentHash
                        => mapping(uint32 parentGasUsed => uint24 forkChoiceId)
                )
            ) forkChoiceIds;
        mapping(address account => uint256 balance) taikoTokenBalances;
        mapping(bytes32 txListHash => TxListInfo) txListInfo;
        EthDeposit[] ethDeposits_A3;
        // Never or rarely changed
        // Slot 6: never or rarely changed
        Slot6 slot6;
        // Slot 7
        Slot7 slot7;
        // Slot 8
        Slot8 slot8;
        // Slot 10
        uint64 numEthDeposits;
        uint64 lastVerifiedAt;
        // Slot 11
	    // Ring buffer for (A4) proposed blocks and a some recent verified blocks.
        mapping(uint256 blockId_mode_blockRingBufferSize => Block) blocks;
        // SLot 12
	    mapping(uint256 depositId_mode_ethDepositRingBufferSize => uint256)
            ethDeposits;
        uint256[38] __gap; // TODO: update this
    }
}
