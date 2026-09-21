// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../shared/slotchain/SlotChainTypes.sol";
import { IBuilderRegistry } from "../iface/IBuilderRegistry.sol";
import { LibBuilderRegistry } from "../libs/LibBuilderRegistry.sol";

/// @title Shared Slot Chain builder-registry storage schema
/// @dev The Registry and its immutable execution facets must inherit this contract directly and
///      must pass the pinned storage-layout digest gate. It deliberately contains no functions.
/// @custom:security-contact security@taiko.xyz
abstract contract BuilderRegistryStorageV1 {
    // Slots 0 and 1 are retained, always-zero words that keep the pinned physical layout stable:
    // the layout digest covers variable labels and the lifecycle-facet configuration hashes are
    // derived from that digest, so the labels stay verbatim although nothing writes them.
    bytes32 internal _protocolRootFactoryRuntimeHash;
    bytes32 internal _protocolRootCampaignKey;
    // Slot 2, byte 0: the one-shot Registry activation flag (0 = inactive, 1 = activated), set
    // once by `BuilderRegistry.activateRegistryV1()`.
    uint8 internal _protocolRootActivationState;

    // Writerless proof-verifier descriptor. Storage, rather than immutable bytecode, is required
    // because lifecycle code executes in the Registry context through fixed delegate facets.
    address internal _builderProofVerifier;
    bytes32 internal _builderProofVerifierRuntimeHash;
    bytes32 internal _builderProofVerifierConfigurationHash;

    // Direct facet calls observe zero here and fail before any stateful operation.
    address internal _registrySelf;

    // Global cross-facet/core mutation lock. The Registry dispatcher owns its lifecycle.
    uint8 internal _operationLock;

    uint256 internal _settlementChainId;
    address internal _builderLeaseToken;
    uint8 internal _builderLeaseTokenDecimals;
    uint192 internal _leasePerWindowAtomic;
    uint192 internal _maximumBondAtomic;
    uint192 internal _reporterRewardCapAtomic;
    uint64 internal _genesisTimestamp;
    uint64 internal _evidenceDelaySeconds;
    uint64 internal _reorgMarginSeconds;
    uint64 internal _firstManagedWindow;
    uint64 internal _lastManagedWindow;
    address internal _builderPenaltySink;
    uint64 internal _rewardClaimWindowSeconds;
    address internal _activeSettlementRouter;
    address internal _scheduleOracle;

    bytes32 internal _builderLeaseTokenRuntimeHash;
    bytes32 internal _routerRuntimeHash;
    bytes32 internal _routerConfigurationHash;
    bytes32 internal _scheduleOracleRuntimeHash;
    bytes32 internal _economicConfigurationHash;
    bytes32 internal _topologyHash;
    IBuilderRegistry.BuilderRewardClassConfigV1[3] internal _rewardClassRows;

    LibBuilderRegistry.Generation[64] internal _active;
    LibBuilderRegistry.Generation[1072] internal _liabilities;
    mapping(uint64 registrationIndex => LibBuilderRegistry.Location location) internal _locations;
    mapping(address builder => uint256 registrationIndexPlusOne) internal _liveIndexPlusOne;
    mapping(
        uint64 registrationIndex => mapping(uint16 index => SlotChainTypes.TrancheLeafV1 leaf)
    ) internal _tranches;
    mapping(uint64 sequence => LibBuilderRegistry.ExitRequest request) internal _exitRequests;
    mapping(uint64 registrationIndex => uint256 sequencePlusOne) internal _exitByRegistration;
    mapping(address owner => uint256 amount) internal _credits;

    uint256 internal _nextRegistrationIndex;
    uint64 internal _movementSequence;
    uint64 internal _nextExitSequence;
    uint64 internal _exitHeadSequence;
    uint64 internal _moveCounterWindow;
    uint8 internal _movesInCounterWindow;
    uint8 internal _activeCount;
    uint64 internal _registryMutationVersion;
    uint64 internal _admissionVersion;
    bytes32 internal _registryRoot;
    bytes32 internal _admissionRoot;
    uint256 internal _baseBondEscrow;
    uint256 internal _trancheEscrow;
    uint256 internal _totalCredits;
    uint8 internal _tokenLock;
}
