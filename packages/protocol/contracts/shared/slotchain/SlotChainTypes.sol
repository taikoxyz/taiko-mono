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

    /// @dev Destination Bridge surplus-reclamation results.
    enum ReclaimResult {
        REJECTED,
        RECLAIMED_ZERO,
        RECLAIMED_VALUE
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

    /// @dev Immutable descriptor for the ordinary tier-1/2/3 settlement verifier.
    struct SettlementValidityVerifierDescriptorV2 {
        address verifier;
        bytes32 runtimeHash;
        bytes32 configurationHash;
        bytes32 verifyingKeyHash;
        bytes32 proofSystemId;
        bytes32 publicInputSchemaHash;
        bytes4 selector;
        uint32 maximumProofBytes;
        uint64 verificationGasLimit;
        uint64 postVerificationReserveGas;
    }

    /// @dev Immutable descriptor for the proof-first migration-transition verifier.
    struct MigrationTransitionVerifierDescriptorV2 {
        address verifier;
        bytes32 runtimeHash;
        bytes32 configurationHash;
        bytes32 verifyingKeyHash;
        bytes32 proofSystemId;
        bytes32 publicInputSchemaHash;
        bytes4 selector;
        uint32 maximumProofBytes;
        uint64 verificationGasLimit;
    }

    /// @dev Immutable descriptor for the destination-registration MPT verifier.
    struct RegistrationMptVerifierDescriptorV2 {
        address verifier;
        bytes32 runtimeHash;
        bytes32 configurationHash;
        bytes32 publicInputSchemaHash;
        bytes32 proofSchemaHash;
        bytes4 selector;
        uint16 maximumNodesPerPath;
        uint16 maximumTotalNodes;
        uint16 maximumNodeBytes;
        uint32 maximumProofBytes;
        uint64 verificationGasLimit;
    }

    /// @dev Exact public-input statement for a destination-registration storage proof.
    struct RegistrationStorageStatementV2 {
        uint256 settlementChainId;
        address activeSettlementRouter;
        address bridgeDomainRegistry;
        bytes32 routeKey;
        uint256 destinationChainId;
        uint64 protocolVersion;
        uint64 canonicalSequence;
        bytes32 stateRoot;
        address terminalDomainRegistrar;
        bytes32 registrarCodeHash;
        bytes32 storageTrieKey;
        bytes32 expectedValue;
    }

    /// @dev One fixed destination component in a release manifest.
    struct ComponentDescriptorV2 {
        address component;
        bytes32 runtimeHash;
        bytes32 configHash;
    }

    /// @dev Complete release-owned destination Bridge descriptor.
    struct DestinationBridgeDescriptorV2 {
        address bridge;
        bytes32 runtimeHash;
        bytes32 configurationHash;
        bytes32 storageLayoutHash;
        bytes32 bridgeKernelProfileHash;
        address inboxCreditStore;
        address terminalAccumulator;
        address terminalDomainRegistrar;
        address quotaManager;
        address nativeLiquidityPool;
        address bridgeSurplusSink;
    }

    /// @dev Exact static 59-word release manifest.
    struct ReleaseManifestV2 {
        uint64 protocolVersion;
        uint256 settlementChainId;
        uint256 destinationChainId;
        bytes32 destinationGenesisHash;
        bytes32 executionProfileHash;
        bytes32 manifestNamespace;
        bytes32 destinationNamespace;
        address anchorV4;
        bytes32 anchorRuntimeHash;
        bytes32 destinationDomainId;
        address destinationBridge;
        bytes32 destinationBridgeExecutionHash;
        DestinationBridgeDescriptorV2 destinationBridgeDescriptor;
        bytes32 destinationInfrastructureHash;
        bytes32 migrationVerifierDescriptorHash;
        bytes32 ingressAuthorizationRoot;
        address nativeLiquidityPool;
        bytes32 poolRuntimeHash;
        bytes32 poolConfigurationHash;
        ComponentDescriptorV2[10] components;
    }

    /// @dev Exact static input supplied by a permissionless migration activator.
    struct MigrationActivationFixedV2 {
        uint8 transitionKind;
        uint64 migrationGeneration;
        uint64 seatGeneration;
        uint64 sourceProtocolVersion;
        uint64 targetProtocolVersion;
        uint64 sourceCanonicalSequence;
        bytes32 candidateDigest;
        CanonicalCoreV2 outputCore;
        address proofBeneficiary;
        uint256 anchorNumber;
        bytes32 anchorHash;
        uint64 forceCutoff;
        uint64 preInboxLastAppliedPlusOne;
    }

    /// @dev Exact public-input statement authenticated by the migration verifier.
    struct MigrationTransitionStatementV2 {
        uint256 settlementChainId;
        address activeSettlementRouter;
        bytes32 routerRuntimeHash;
        bytes32 routerConfigurationHash;
        uint8 transitionKind;
        uint64 migrationGeneration;
        uint64 sourceProtocolVersion;
        uint64 targetProtocolVersion;
        uint64 sourceCanonicalSequence;
        bytes32 executionProfileHash;
        bytes32 targetManifestHash;
        bytes32 targetRegistrationHash;
        bytes32 candidateDigest;
        bytes32 baseCanonicalHash;
        bytes32 outputCanonicalHash;
        address forcedQueue;
        bytes32 queueRuntimeHash;
        bytes32 queueConfigurationHash;
        bytes32 queueRoot;
        uint64 queueCount;
        uint64 startCursor;
        uint64 endCursor;
        bytes32 forcedDescriptorCommitment;
        address proofBeneficiary;
        uint256 anchorNumber;
        bytes32 anchorHash;
        bytes32 forceRoot;
        uint64 forceCutoff;
        bytes32 sourceDomainId;
        uint64 sourceRegistrationEpoch;
        bytes32 sourceBridgeExecutionHash;
        bytes32 releaseSystemCalldataHash;
        bytes32 inboxSystemCalldataHash;
        bytes32 releaseSystemTxHash;
        bytes32 inboxSystemTxHash;
        uint8 releaseSystemTxPosition;
        uint8 inboxSystemTxPosition;
        bytes32 importedHeaderHash;
        bytes32 importedStateRoot;
        bytes32 legacySignalCheckpointHash;
        bytes32 legacyDeploymentHash;
        bytes32 legacyArmId;
        bytes32 legacyLaunchId;
        bytes32 deploymentCommitment;
        uint64 preInboxLastAppliedPlusOne;
        uint64 postInboxLastAppliedPlusOne;
    }

    /// @dev One release-profile ingress authorization row.
    struct ProfileIngressAuthorizationV2 {
        uint8 kind;
        address adapter;
        bytes32 adapterRuntimeHash;
        bytes32 adapterConfigurationHash;
        bytes32 adapterConstructorPoststateCommitment;
        address activeSettlementRouter;
        bytes32 routerRuntimeHash;
        bytes32 routerConfigurationHash;
        address forcedQueue;
        bytes32 queueRuntimeHash;
        bytes32 queueConfigurationHash;
        bytes32 sourceDomainId;
        uint64 sourceRegistrationEpoch;
        bytes32 sourceBridgeExecutionHash;
        uint256 destinationChainId;
        bytes32 destinationDomainId;
        address destinationBridge;
        bytes32 destinationBridgeExecutionHash;
        bytes32 destinationInfrastructureHash;
        uint256 fixedIngressWei;
        uint256 executionWeiPerAccountedGas;
        uint256 proofWeiPerAccountedGas;
        uint256 permanentWeiPerByte;
        uint256 maximumAcceptedFeeWei;
    }

    /// @dev Destination-local activation receipt retained for direct-successor reclamation.
    struct DestinationActivationReceiptV2 {
        uint256 destinationChainId;
        address terminalDomainRegistrar;
        uint64 successorIndex;
        uint64 oldProtocolVersion;
        uint64 newProtocolVersion;
        bytes32 oldManifestHash;
        bytes32 newManifestHash;
        bytes32 oldDestinationDomainId;
        bytes32 newDestinationDomainId;
        address oldDestinationBridge;
        address newDestinationBridge;
        uint64 retirementQueueCount;
        uint64 activatedAtBlock;
    }

    /// @dev One retained component identity used by a retired destination Bridge.
    struct ReclamationComponentV2 {
        address account;
        bytes32 runtimeHash;
        bytes32 configurationHash;
    }

    /// @dev Complete restart-safe configuration for destination Bridge surplus reclamation.
    struct ReclamationConfigV2 {
        uint64 protocolVersion;
        uint64 destinationChainId;
        bytes32 releaseManifestHash;
        bytes32 registrationCommitment;
        bytes32 executionProfileHash;
        bytes32 destinationDomainId;
        address destinationBridge;
        address bridgeSurplusSink;
        ReclamationComponentV2[6] components;
        address forceSendHelper;
        bytes32 forceSendCreate2Salt;
        bytes32 forceSendInitcodeHash;
        bytes32 forceSendCompilerBuildHash;
        bytes32 forceSendEvmRulesHash;
        uint64 forceSendCreate2FixedGas;
        uint64 forceSendChildGas;
        uint64 forceSendPostcheckReserve;
        uint64 forceSendPrecreateGas;
    }

    /// @dev Exact V2.27 execution profile: 281 fixed fields followed by one artifact bundle.
    struct ExecutionProfileV2 {
        // 0..15: core
        uint64 schemaVersion;
        uint64 protocolVersion;
        uint256 settlementChainId;
        uint256 l2ChainId;
        bytes32 settlementGenesisHash;
        bytes32 destinationGenesisHash;
        bytes4 forkDigest;
        uint64 firstV2BlockNumber;
        uint64 genesisTimestamp;
        bytes32 manifestNamespace;
        bytes32 destinationNamespace;
        bytes32 routerNamespace;
        bytes32 poolNamespace;
        address anchorV4;
        bytes32 anchorRuntimeHash;
        bytes32 anchorConfigurationHash;

        // 16..43: control objects
        address protocolChangeTimelock;
        bytes32 protocolChangeTimelockRuntimeHash;
        bytes32 protocolChangeTimelockConfigurationHash;
        address daoProposer;
        address protocolVersionManager;
        bytes32 protocolVersionManagerRuntimeHash;
        bytes32 protocolVersionManagerConfigurationHash;
        address activeSettlementRouter;
        bytes32 activeSettlementRouterRuntimeHash;
        bytes32 activeSettlementRouterConfigurationHash;
        address forcedQueue;
        bytes32 forcedQueueRuntimeHash;
        bytes32 forcedQueueConfigurationHash;
        address builderRegistry;
        bytes32 builderRegistryRuntimeHash;
        bytes32 builderRegistryConfigurationHash;
        address scheduleOracle;
        bytes32 scheduleOracleRuntimeHash;
        bytes32 scheduleOracleConfigurationHash;
        address aggregatorSeatMarket;
        bytes32 aggregatorSeatMarketRuntimeHash;
        bytes32 aggregatorSeatMarketConfigurationHash;
        address bridgeDomainRegistry;
        bytes32 bridgeDomainRegistryRuntimeHash;
        bytes32 bridgeDomainRegistryConfigurationHash;
        address sourceBundleFactory;
        bytes32 sourceBundleFactoryRuntimeHash;
        bytes32 sourceBundleFactoryConfigurationHash;

        // 44..56: target artifact
        address settlementFactory;
        bytes32 settlementFactoryRuntimeHash;
        bytes32 settlementFactoryConfigurationHash;
        bytes32 settlementSalt;
        bytes32 targetRuntimeHash;
        bytes32 targetCreationCodeHash;
        bytes32 targetAbiHash;
        bytes32 targetStorageLayoutHash;
        bytes32 targetConstructorSchemaHash;
        bytes32 targetCompilerBuildHash;
        bytes32 targetCompileTimeRulesHash;
        bytes32 targetImmutableReferencesHash;
        bytes32 targetLinkReferencesHash;

        // 57..62: target verification infrastructure
        address settlementL1HistoryStorageAddress;
        bytes32 settlementL1HistoryStorageRuntimeHash;
        bytes32 settlementL1HistoryStorageReadConfigurationHash;
        address registrationMptVerifier;
        bytes32 registrationMptVerifierRuntimeHash;
        bytes32 registrationMptVerifierConfigurationHash;

        // 63..71: sinks
        address builderLeaseToken;
        bytes32 builderLeaseTokenRuntimeHash;
        uint8 builderLeaseTokenDecimals;
        address builderPenaltySink;
        address dataRentSink;
        address seatPenaltySink;
        address forcedExpirySink;
        address bridgeSurplusSink;
        address protocolCoinbaseSink;

        // 72..85: recovery
        uint64 settlementWindowSeconds;
        uint64 includeMaxSeconds;
        uint64 finalLagSeconds;
        uint64 tipLagSeconds;
        uint64 proveMaxSeconds;
        uint64 l1FinalityBlocks;
        uint64 depthMaxSeconds;
        uint64 clockSkewSeconds;
        uint64 escapeOffsetSeconds;
        uint64 forceDelaySeconds;
        uint64 maximumParentGapSlots;
        uint64 maximumForceValiditySeconds;
        uint64 evidenceDelaySeconds;
        uint64 reorgMarginSeconds;

        // 86..100: seat
        uint64 seatRunwaySeconds;
        uint64 minimumPrimaryTenureSeconds;
        uint64 minimumStandbyTenureSeconds;
        uint64 handoverDelaySeconds;
        uint64 stageGraceSeconds;
        uint64 exitDelaySeconds;
        uint64 recoveryLagSeconds;
        uint64 slashLagSeconds;
        uint64 premiumClaimDelaySeconds;
        uint64 reorgStabilitySeconds;
        uint64 releaseChallengeSeconds;
        uint256 maximumAskWeiPerSecond;
        uint256 seatSlaBondWei;
        uint256 maximumAvoidedServiceCostWei;
        uint256 collusionSafetyMarginWei;

        // 101..106: data sessions
        uint256 dataSessionBondWei;
        uint256 dataSessionBaseRentWei;
        uint256 dataSessionRentPerPublishedByteWei;
        uint16 dataSessionBlobBaseFeeMultiplierBps;
        uint64 dataSessionMaximumTtlSeconds;
        uint64 dataSessionRefundClaimWindowSeconds;

        // 107..117: target gas
        uint64 activeSettlementStateReadGas;
        uint64 seatMarketStateReadGas;
        uint64 seatTermRecordReadGas;
        uint64 seatDutyRecordReadGas;
        uint64 componentConfigurationReadGas;
        uint64 registrationVerifierConfigReadGas;
        uint64 registrationVerifierCallGas;
        uint64 migrationActivationContextReadGas;
        uint64 migrationPostStateReadGas;
        uint64 targetAdoptionCallGas;
        uint64 targetPostCallbackReserveGas;

        // 118..137: compile-time rules
        uint8 slotSeconds;
        uint16 scheduleWindowSlots;
        uint8 seatCount;
        uint8 dutyRingCapacity;
        uint8 forceTreeDepth;
        uint8 dataMmrDepth;
        uint16 dataSessionCellCount;
        uint16 maximumDataSessionsPerOwner;
        uint16 maximumDataRecordsPerSession;
        uint8 maximumGcSteps;
        uint8 maximumBlobsPerPost;
        uint16 canonicalHistoryCapacity;
        uint8 destinationComponentCount;
        uint8 ingressAuthorizationCount;
        address pointEvaluationPrecompile;
        uint32 pointEvaluationGas;
        uint256 blsModulus;
        uint32 blobGasUsed;
        uint32 maximumBlobPayloadBytes;
        uint16 maximumBlobChunkCount;

        // 138..157: migration-transition verifier and migration gas
        address migrationVerifier;
        bytes32 migrationVerifierRuntimeHash;
        bytes32 migrationVerifierConfigurationHash;
        bytes32 migrationVerifyingKeyHash;
        bytes32 migrationProofSystemId;
        bytes32 migrationPublicInputSchemaHash;
        bytes4 migrationVerifierSelector;
        uint32 migrationMaximumProofBytes;
        uint64 migrationVerificationGas;
        uint64 supportedL1BlockGasLimit;
        uint64 worstCaseActivationAdoptionGas;
        uint64 sourceFreezeGas;
        uint64 targetAdoptionGas;
        uint64 queueMigrationGas;
        uint64 activationContextReadGas;
        uint64 postStateReadGas;
        uint64 legacyStateReadGas;
        uint64 legacyArmGas;
        uint64 legacyFinalizeGas;
        uint64 postCallbackReserveGas;

        // 158..201: destination
        address inboxSystemSender;
        address anchorSystemSender;
        address destinationComponent1;
        bytes32 destinationComponent1RuntimeHash;
        bytes32 destinationComponent1ConfigurationHash;
        address destinationComponent2;
        bytes32 destinationComponent2RuntimeHash;
        bytes32 destinationComponent2ConfigurationHash;
        address destinationComponent3;
        bytes32 destinationComponent3RuntimeHash;
        bytes32 destinationComponent3ConfigurationHash;
        address destinationComponent4;
        bytes32 destinationComponent4RuntimeHash;
        bytes32 destinationComponent4ConfigurationHash;
        address destinationComponent5;
        bytes32 destinationComponent5RuntimeHash;
        bytes32 destinationComponent5ConfigurationHash;
        address destinationComponent6;
        bytes32 destinationComponent6RuntimeHash;
        bytes32 destinationComponent6ConfigurationHash;
        address destinationComponent7;
        bytes32 destinationComponent7RuntimeHash;
        bytes32 destinationComponent7ConfigurationHash;
        address destinationComponent8;
        bytes32 destinationComponent8RuntimeHash;
        bytes32 destinationComponent8ConfigurationHash;
        address destinationComponent9;
        bytes32 destinationComponent9RuntimeHash;
        bytes32 destinationComponent9ConfigurationHash;
        address destinationComponent10;
        bytes32 destinationComponent10RuntimeHash;
        bytes32 destinationComponent10ConfigurationHash;
        bytes32 destinationBridgeStorageLayoutHash;
        bytes32 bridgeKernelProfileHash;
        bytes32 bridgeKernelAbiHash;
        bytes32 bridgeStatusLayoutHash;
        bytes32 bridgeCustodyLayoutHash;
        address destinationQuotaManager;
        bytes32 destinationQuotaManagerRuntimeHash;
        bytes32 destinationQuotaManagerConfigurationHash;
        uint256 destinationInitialNativeQuota;
        uint64 poolReadGas;
        uint64 poolAuthorizationCleanupGas;
        uint64 poolValueCallbackGas;

        // 202..227: source
        address releaseSourceBundleFactory;
        bytes32 releaseSourceBundleFactoryRuntimeHash;
        bytes32 releaseSourceBundleFactoryConfigurationHash;
        bytes32 sourceBundleSalt;
        bytes32 sourceBundleInitCodeHash;
        address sourceBundleDeployer;
        bytes32 sourceBundleDeployerRuntimeHash;
        address legacyV1SourceBridge;
        address sourceBridge;
        bytes32 sourceBridgeRuntimeHash;
        bytes32 sourceBridgeConfigurationHash;
        bytes32 sourceBridgeStorageLayoutHash;
        address sourceCreditRegistry;
        bytes32 sourceCreditRegistryRuntimeHash;
        bytes32 sourceCreditRegistryConfigurationHash;
        address sourceQuotaManager;
        bytes32 sourceQuotaManagerRuntimeHash;
        bytes32 sourceQuotaManagerConfigurationHash;
        address sourceSupportRegistry;
        bytes32 sourceSupportRegistryRuntimeHash;
        bytes32 sourceSupportRegistryConfigurationHash;
        address sourcePauser;
        address sourceSignalService;
        uint64 sourceRegistrationEpoch;
        bytes32 sourceNamespace;
        bytes32 sourceGenesisHash;

        // 228..234: kind-0 ingress
        address kind0IngressAdapter;
        bytes32 kind0IngressAdapterRuntimeHash;
        uint256 fixedIngressWei;
        uint256 executionWeiPerAccountedGas;
        uint256 proofWeiPerAccountedGas;
        uint256 permanentWeiPerByte;
        uint256 maximumAcceptedFeeWei;

        // 235..251: execution
        uint64 l2BlockGasLimit;
        uint64 baseFeeElasticity;
        uint64 baseFeeChangeDenominator;
        uint64 blobTarget;
        uint64 blobUpdateFraction;
        bytes32 emptyOmmersHash;
        bytes32 emptyTransactionsRoot;
        bytes32 emptyWithdrawalsRoot;
        bytes32 emptyRequestsHash;
        uint64 l1HistoryFirstSupportedBlock;
        bytes32 l2HistoryStorageRuntimeHash;
        uint64 l2HistoryStorageActivationBlock;
        bytes32 headerRulesHash;
        bytes32 systemTransactionRulesHash;
        bytes32 forcedInputRulesHash;
        bytes32 stateTransitionAbiHash;
        bytes32 legacyExecutionRulesHash;

        // 252..266: seat wire and calibrated economics
        uint64 quoteMaturitySeconds;
        uint64 quoteMaturityBlocks;
        uint64 seatMarketMutationCallGas;
        uint64 seatMutationIntentReadGas;
        uint64 seatLineupWireReadGas;
        uint64 seatInstallRecordReadGas;
        uint64 seatMarketPostReadReserveGas;
        uint64 seatWirePostCallReserveGas;
        uint64 seatDutyHistorySafeReadGas;
        uint64 seatSuccessorReceiptReadGas;
        uint64 activationReceiptReadGas;
        uint64 maximumStandbyLeaseSeconds;
        uint256 minimumAskImprovementWeiPerSecond;
        uint16 minimumAskImprovementBps;
        bytes32 economicProfileHash;

        // 267..270: kind-0 deployment provenance
        bytes32 kind0IngressAdapterCreationCodeHash;
        bytes32 kind0IngressAdapterSalt;
        bytes32 kind0IngressAdapterInitCodeHash;
        bytes32 kind0IngressAdapterConfigurationHash;

        // 271..280: settlement validity verifier
        address settlementValidityVerifier;
        bytes32 settlementValidityVerifierRuntimeHash;
        bytes32 settlementValidityVerifierConfigurationHash;
        bytes32 settlementValidityVerifyingKeyHash;
        bytes32 settlementValidityProofSystemId;
        bytes32 settlementValidityPublicInputSchemaHash;
        bytes4 settlementValidityVerifierSelector;
        uint32 settlementValidityMaximumProofBytes;
        uint64 settlementValidityVerificationGas;
        uint64 settlementValidityPostVerificationReserveGas;

        // 281: sole dynamic tail
        bytes deploymentCodeArtifacts;
    }
}
