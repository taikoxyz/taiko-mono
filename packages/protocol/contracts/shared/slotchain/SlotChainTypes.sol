// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain consensus types
/// @custom:security-contact security@taiko.xyz
library SlotChainTypes {
    /// @dev Proof tiers use their consensus wire values. Zero is invalid.
    enum ProofTier {
        INVALID,
        NORMAL,
        SIGNED_RECOVERY,
        UNSIGNED_ESCAPE
    }

    /// @dev Forced-message kinds use their consensus wire values.
    enum ForcedKind {
        USER_TRANSACTION,
        BRIDGE_CREDIT
    }

    /// @dev Builder bond-tranche states use their consensus wire values.
    enum TrancheState {
        EMPTY,
        FREE,
        RESERVED,
        LIABLE,
        RELEASED,
        SLASHED
    }

    /// @dev Forced-message dispositions use their consensus wire values.
    enum Disposition {
        EXPIRED_NO_TX,
        NONCE_NO_TX,
        FUNDS_NO_TX,
        FEE_NO_TX,
        INCLUDED_TX,
        BRIDGE_CREDIT
    }

    /// @dev Forced-ingress results use their exact ABI values. Zero is invalid.
    enum QueueResult {
        INVALID,
        QUEUED,
        SYNCED,
        ALREADY_QUEUED
    }

    /// @dev Terminal credit states use their commitment values. Zero is nonterminal.
    enum TerminalState {
        NONE,
        DONE,
        FAILED
    }

    /// @dev Canonical migration transition kinds. Zero is invalid.
    enum MigrationKind {
        INVALID,
        GENESIS_IMPORT,
        VERSION_MIGRATION
    }

    /// @dev V2 refund modes. Zero is intentionally unsupported at launch.
    enum RefundMode {
        NONE,
        DIRECT
    }

    /// @dev Exact EIP-712 signed SlotChainBlock tuple.
    struct SlotChainBlock {
        uint256 settlementChainId;
        uint256 l2ChainId;
        uint256 protocolVersion;
        address verifyingContract;
        uint64 slot;
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
        bytes32 bodyRoot;
        uint64 anchorNumber;
        bytes32 anchorHash;
        bytes32 forceRoot;
        uint64 forceCutoff;
        uint64 messageStart;
        uint64 messageEnd;
        bytes32 dataManifestRoot;
        address coinbase;
        uint8 tier;
        bytes32 contextId;
        uint64 admissionVersion;
        bytes32 admissionRoot;
        uint64 episode;
        uint64 recoveryRevision;
        bytes32 recoveryId;
    }

    /// @dev Exact verifier statement tuple, in normative ABI order.
    struct SettlementStatementV2 {
        uint256 settlementChainId;
        uint256 l2ChainId;
        uint256 protocolVersion;
        bytes32 executionProfileHash;
        address verifyingContract;
        uint64 releaseProtocolVersion;
        bytes32 releaseManifestHash;
        uint8 tier;
        bytes32 baseCanonicalHash;
        bytes32 candidateCommitment;
        uint64 blockCount;
        uint64 firstSlot;
        bytes32 tipHash;
        uint64 tipSlot;
        uint64 endL2BlockNumber;
        bytes32 endStateRoot;
        bytes32 endTerminalRoot;
        uint64 endTerminalCount;
        uint64 endCursor;
        bytes32 winningDataCommitment;
        uint64 nextDueAt;
        uint256 nextBaseFee;
        uint64 nextExcessBlobGas;
        uint64 anchorNumber;
        bytes32 anchorHash;
        bytes32 anchorStateRoot;
        uint64 anchorTimestamp;
        bytes32 forceRoot;
        uint64 forceCutoff;
        bytes32 forcedDescriptorCommitment;
        uint64 startCursor;
        uint64 admissionVersion;
        bytes32 admissionRoot;
        uint64 episode;
        uint64 recoveryRevision;
        bytes32 recoveryId;
        bytes32 scheduleRootsCommitment;
        uint8 scheduleWindowCount;
        bytes32 sessionRefsCommitment;
        uint8 sessionCount;
        uint16 dataRecordCount;
        uint256 rewardExecutionGas;
        uint64 rewardPublishedBytes;
        bytes32 executionOutputsCommitment;
        address proofBeneficiary;
    }

    /// @dev Canonical state stored and transferred between settlement versions.
    struct CanonicalCoreV2 {
        uint48 l2BlockNumber;
        bytes32 tipHash;
        uint64 tipSlot;
        bytes32 stateRoot;
        uint64 messageCursor;
        bytes32 winningDataCommitment;
        uint256 nextBaseFee;
        uint64 nextExcessBlobGas;
        bytes32 terminalRoot;
        uint64 terminalCount;
    }

    /// @dev Exact historical canonical tuple returned by a settlement version.
    struct CanonicalHistoryV2 {
        uint64 protocolVersion;
        bytes32 executionProfileHash;
        uint64 canonicalSequence;
        uint48 l2BlockNumber;
        bytes32 blockHash;
        uint64 tipSlot;
        bytes32 stateRoot;
        uint64 messageCursor;
        bytes32 winningDataCommitment;
        uint256 nextBaseFee;
        uint64 nextExcessBlobGas;
        bytes32 terminalRoot;
        uint64 terminalCount;
        uint64 canonicalizedAtBlock;
    }

    /// @dev Exact recovery identity tuple.
    struct RecoveryContextV2 {
        uint256 chainId;
        address settlement;
        uint64 episode;
        uint64 revision;
        bytes32 baseHash;
        uint64 roundStartSlot;
        uint64 anchorNumber;
        bytes32 anchorHash;
        bytes32 forceRoot;
        uint64 forceCutoff;
        uint64 admissionVersion;
        bytes32 admissionRoot;
        uint64 escapeSlot;
        uint8 causes;
    }

    /// @dev One row in a candidate commitment.
    struct CandidateBlockV2 {
        uint64 slot;
        bytes32 blockStructHash;
        bytes32 blockHash;
        bytes32 bodyRoot;
        bytes32 dataManifestRoot;
        uint64 messageEnd;
    }

    /// @dev One row in the bounded schedule-root commitment.
    struct ScheduleEntryV1 {
        uint64 window;
        bytes32 entryRoot;
        bytes32 seed;
    }

    /// @dev One row in the bounded sealed-session commitment.
    struct SessionRefV1 {
        bytes32 sessionId;
        uint16 recordCount;
        bytes32 root;
    }

    /// @dev Exact execution-output tuple committed by a candidate.
    struct ExecutionOutputsV2 {
        bytes32 stateRoot;
        bytes32 transactionsRoot;
        bytes32 receiptsRoot;
        bytes32 logsBloomHash;
        bytes32 withdrawalsRoot;
        bytes32 terminalRoot;
        uint64 terminalCount;
    }

    /// @dev Active or liability builder-registry cell payload.
    struct RegistryCellV1 {
        address builder;
        uint192 bond;
        uint64 registrationIndex;
        uint64 effectiveL2Slot;
        bytes32 trancheRoot;
        uint64 tombstonedAtL2Slot;
    }

    /// @dev Builder bond-tranche leaf payload.
    struct TrancheLeafV1 {
        uint16 index;
        uint64 window;
        uint8 state;
        uint192 amount;
        uint64 liableUntil;
    }

    /// @dev Ranked schedule-entry leaf payload.
    struct RankedEntryV1 {
        uint8 rank;
        address builder;
        uint192 bond;
        uint64 registrationIndex;
        uint64 effectiveL2Slot;
        uint64 tombstonedAtL2Slot;
        bytes32 trancheLeafHash;
    }

    /// @dev Exact 220-byte kind-0 descriptor body before ABI encoding.
    struct Kind0ForcedDescriptorV2 {
        address sender;
        uint64 nonce;
        uint256 l2ChainId;
        bytes32 rawTxHash;
        uint32 byteLength;
        uint64 gasLimit;
        uint64 accountedGas;
        uint256 maxFee;
        uint64 validUntil;
        address refundAddress;
        uint64 enqueuedAt;
        uint64 dueAt;
        uint256 deposit;
    }

    /// @dev Exact 541-byte kind-1 descriptor body before ABI encoding.
    struct Kind1ForcedDescriptorV11 {
        bytes32 msgHash;
        uint256 srcChainId;
        bytes32 sourceDomainId;
        uint64 srcEpoch;
        address srcBridge;
        bytes32 bridgeExecutionHash;
        uint64 emittedAtBlock;
        bytes32 destinationDomainId;
        uint256 destChainId;
        uint64 enqueueBy;
        address sender;
        address srcOwner;
        address destOwner;
        uint256 value;
        uint64 fee;
        uint64 liquidityFee;
        bytes32 calldataHash;
        uint8 refundMode;
        address refundVault;
        bytes32 refundCapsuleHash;
        bytes32 escrowId;
        uint32 byteLength;
        uint64 accountedGas;
        address refundAddress;
        uint64 enqueuedAt;
        uint64 dueAt;
        uint256 deposit;
    }

    /// @dev One heterogeneous row in a forced-descriptor list.
    struct ForcedDescriptorRowV2 {
        uint64 index;
        uint8 kind;
        bytes descriptorBytes;
    }

    /// @dev One record in a block data manifest.
    struct ManifestEntryV1 {
        uint16 blockOrdinal;
        bytes32 sessionId;
        uint16 recordIndex;
        uint16 chunkIndex;
        uint16 chunkCount;
        uint32 chunkLength;
        bytes32 fullBodyRoot;
        bytes32 chunkRoot;
    }

    /// @dev Fixed data-session record committed as one MMR leaf.
    struct DataRecordV1 {
        bytes32 sessionId;
        uint16 recordIndex;
        bytes32 versionedHash;
        bytes32 fullBodyRoot;
        uint16 blockOrdinal;
        uint16 chunkIndex;
        uint16 chunkCount;
        uint32 chunkLength;
        bytes32 chunkRoot;
        address publisher;
        uint64 validUntil;
        uint256 z;
        uint256 y;
    }

    /// @dev One row in the forced-message disposition commitment.
    struct DispositionV1 {
        uint64 queueIndex;
        uint8 disposition;
        uint32 txIndex;
        bytes32 resultHash;
    }

    /// @dev Immutable best-effort proof reward entitlement.
    struct RewardReceiptV1 {
        bytes32 candidateId;
        address beneficiary;
        uint8 rewardClass;
        uint256 rewardExecutionGas;
        uint64 rewardPublishedBytes;
        bytes32 executionProfileHash;
        uint64 committedAtBlock;
        uint64 committedAtTimestamp;
        uint64 claimUntil;
        bool claimed;
    }

    /// @dev Raw bridge message tuple retained from the V1 ABI.
    struct MessageV1 {
        uint64 id;
        uint64 fee;
        uint32 gasLimit;
        address from;
        uint64 srcChainId;
        address srcOwner;
        uint64 destChainId;
        address destOwner;
        address to;
        uint256 value;
        bytes data;
    }

    /// @dev Source-bridge admission payload for a kind-1 forced credit.
    struct BridgeAdmissionEnvelopeV2 {
        MessageV1 message;
        uint64 liquidityFee;
    }

    /// @dev Privileged L2 inbox-application row.
    struct InboxRowV2 {
        uint64 queueIndex;
        uint8 disposition;
        uint32 txIndex;
        bytes32 resultHash;
        bytes kind1Descriptor;
    }

    /// @dev Exact fixed-width credit row delivered to an endpoint store.
    struct InboxCreditV2 {
        uint64 queueIndex;
        uint64 srcChainId;
        bytes32 sourceDomainId;
        uint64 srcEpoch;
        address srcBridge;
        bytes32 destinationDomainId;
        bytes32 msgHash;
        bytes32 resultHash;
        bytes32 sourceContextHash;
        uint256 value;
        uint64 executionFee;
        uint64 liquidityFee;
    }

    /// @dev Static source identity supplied to the destination Bridge.
    struct SourceContextV2 {
        uint64 protocolVersion;
        uint8 kind;
        bytes32 creditId;
        bytes32 msgHash;
        bytes32 sourceDomainId;
        uint64 sourceRegistrationEpoch;
        address sourceBridge;
        bytes32 sourceBridgeExecutionHash;
        uint64 emittedAtBlock;
        uint64 queueIndex;
    }

    /// @dev Static destination identity supplied to the destination Bridge.
    struct DestinationContextV2 {
        uint256 destinationChainId;
        bytes32 destinationDomainId;
        address destinationBridge;
        bytes32 releaseManifestHash;
        bytes32 executionProfileHash;
    }

    /// @dev Fixed source-domain identity tuple.
    struct SourceDomainV4 {
        uint64 sourceChainId;
        bytes32 genesisHash;
        address creditRegistry;
        address terminalVerifier;
        address bridge;
        bytes32 bridgeExecutionHash;
        bytes32 registryNamespace;
    }

    /// @dev Fixed destination-domain identity tuple.
    struct DestinationDomainV7 {
        uint64 destinationChainId;
        bytes32 genesisHash;
        address bridgeInboxAdapter;
        address activeSettlementRouter;
        address terminalVerifier;
        address inboxApply;
        address inboxCreditStore;
        address protocolReleaseAuthority;
        address terminalDomainRegistrar;
        address terminalAccumulator;
        address nativeLiquidityPool;
        address bridge;
        bytes32 bridgeExecutionHash;
        bytes32 infrastructureHash;
        bytes32 namespace;
    }

    /// @dev Liquidity claim bound into a successful terminal leaf.
    struct LiquiditySettlementV1 {
        bytes32 ticketId;
        address l1Recipient;
        uint256 settlementAmount;
    }
}
