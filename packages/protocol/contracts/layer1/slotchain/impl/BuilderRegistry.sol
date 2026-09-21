// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../shared/slotchain/SlotChainTypes.sol";
import { IComponentConfigV2 } from "../../../shared/slotchain/iface/IComponentConfigV2.sol";
import { LibExactCall } from "../../../shared/slotchain/libs/LibExactCall.sol";
import { LibSlotChainFixedTrees } from "../../../shared/slotchain/libs/LibSlotChainFixedTrees.sol";
import { IBuilderRegistry } from "../iface/IBuilderRegistry.sol";
import { IBuilderRegistryProofVerifierV1 } from "../iface/IBuilderRegistryProofVerifierV1.sol";
import { LibBuilderRegistry } from "../libs/LibBuilderRegistry.sol";
import { BuilderRegistryStorageV1 } from "./BuilderRegistryStorageV1.sol";

/// @title Shared immutable Slot Chain builder-registry logic
/// @notice Supplies one storage-exact implementation to the Registry and its frozen facets.
/// @custom:security-contact security@taiko.xyz
abstract contract BuilderRegistryLogicV1 is IComponentConfigV2, BuilderRegistryStorageV1 {
    bytes4 private constant _BRC1_MAGIC = 0x42524331;
    bytes4 private constant _ADS1_MAGIC = 0x41445331;
    bytes4 private constant _BRS1_MAGIC = 0x42525331;
    bytes4 private constant _BRG1_MAGIC = 0x42524731;
    bytes4 private constant _BRV1_MAGIC = 0x42525631;
    bytes4 private constant _BRE1_MAGIC = 0x42524531;
    bytes4 private constant _BRM1_MAGIC = 0x42524d31;
    bytes4 private constant _BRN1_MAGIC = 0x42524e31;
    bytes4 private constant _BTR1_MAGIC = 0x42545231;
    bytes4 private constant _BGR1_MAGIC = 0x42475231;
    bytes4 private constant _BCL1_MAGIC = 0x42434c31;
    bytes4 private constant _BEV1_MAGIC = 0x42455631;
    bytes4 private constant _RCV1_MAGIC = 0x52435631;

    bytes4 private constant _SST1_MAGIC = 0x53535431;
    bytes4 private constant _SWR1_MAGIC = 0x53575231;
    bytes4 private constant _DECIMALS_SELECTOR = 0x313ce567;
    bytes4 private constant _BALANCE_OF_SELECTOR = 0x70a08231;
    bytes4 private constant _TRANSFER_SELECTOR = 0xa9059cbb;
    bytes4 private constant _TRANSFER_FROM_SELECTOR = 0x23b872dd;
    bytes4 private constant _SST1_SELECTOR = 0x5c449b11;
    bytes4 private constant _SWR1_SELECTOR = 0xf4cd9a5e;
    bytes4 private constant _BPV1_SELECTOR = 0x0d1c9932;
    bytes4 internal constant _BRF1_SELECTOR = 0x5c19dfed;
    bytes4 internal constant _BRF1_MAGIC = 0x42524631;
    bytes4 private constant _BPO1_MAGIC = 0x42504f31;
    bytes4 private constant _BPR1_MAGIC = 0x42505231;
    bytes4 private constant _COMPONENT_CONFIG_SELECTOR = 0xf6c0f7d2;

    uint256 private constant _EXTERNAL_READ_GAS = 50_000;
    uint256 private constant _WINDOW_SLOTS = 384;
    uint256 private constant _LAST_FULL_SLOT_WINDOW = 48_038_396_025_285_289;
    uint64 private constant _LIVE_TOMBSTONE = type(uint64).max;
    uint64 private constant _TERMINAL_CURSOR = type(uint64).max;
    bytes32 private constant _BPV1_RETURN_HASH =
        0x424eb74a70eb5383c3ca04922b259ce7314377be45a1b10e5dd0c7ab79df6419;
    bytes32 private constant _BPV1_CONFIGURATION_HASH =
        0xe3e45065c704e9bdad17d5b1a8de56115576b30d7e4e09d50a3a07aa66aac80b;
    bytes32 internal constant _BUILDER_REGISTRY_STORAGE_LAYOUT_HASH =
        0x5b676bdd8dd5b37f6353a4b46a59d7d24f6b0cc66b28cf1222b3deafe36402bd;

    bytes32 private constant _HEADER_SLOT =
        0xe7ce7a505bf18b9ed57a0785851385323c9487991c55b422861381f92e5c245a;
    bytes32 private constant _ROOT_SLOT =
        0x4dc6f1bf199f7518c646d40ed35ca04703f646273e6de1d7eace0746cc7100a6;

    // Implementation immutables assigned by the Registry constructor. The lifecycle facets have
    // no constructor and hold zero here; no delegated path reads them, because activation, the
    // BRC1 view and equivocation execute in Registry code only.
    address internal immutable _activator;
    uint256 internal immutable _l2ChainId;

    struct EvidenceTransition {
        address builder;
        uint64 registrationIndex;
        uint64 window;
        uint8 locationKind;
        uint16 locationIndex;
        uint16 trancheIndex;
        uint8 oldTrancheState;
        bool firstTombstone;
        uint64 tombstonedAtL2Slot;
        bytes32 newTrancheRoot;
        bytes32 newRegistryRoot;
        bytes32 newAdmissionRoot;
    }

    struct EvidenceIdentity {
        bytes32 evidenceHash;
        bytes32 identityCommitment;
        address builder;
        uint64 window;
        uint64 protocolVersion;
        address verifyingContract;
        uint256 l2ChainId;
        uint64 signedAdmissionVersion;
        bytes32 signedAdmissionRoot;
    }

    struct MaintenanceCursor {
        uint256 witnessOffset;
        uint64 currentWindow;
        uint8 moveLimit;
        uint8 inspected;
        uint8 moved;
    }

    struct ReservationContext {
        uint256 balanceBefore;
        uint64 currentWindow;
        uint32 staleMask;
        uint8 activeIndex;
        uint8 closeCount;
        bool alreadyReserved;
        bool rootChanged;
    }

    struct RegistrationContext {
        uint256 balanceBefore;
        uint64 currentWindow;
        uint64 registrationIndex;
        uint64 effectiveL2Slot;
        uint8 activeIndex;
        bool hasVacancy;
    }

    struct EvidenceRequestContext {
        SlotChainTypes.RegistryCellV1 oldCell;
        SlotChainTypes.TrancheLeafV1 oldTranche;
        uint64 registrationIndex;
        uint64 currentL2Slot;
        uint16 position;
        uint8 locationKind;
    }

    struct MovementContext {
        SlotChainTypes.RegistryCellV1 oldVictimCell;
        SlotChainTypes.RegistryCellV1 replacementCell;
        SlotChainTypes.RegistryCellV1 priorCell;
        LibBuilderRegistry.Generation retained;
        uint256 offset;
        uint16 ringIndex;
        uint16 liabilityPosition;
        bool priorOccupied;
    }

    /// @dev Validates and stores the complete writerless Registry-local constructor suffix. The
    ///      Settlement and ScheduleOracle peers are proxies pinned by address only; the retained
    ///      `_routerRuntimeHash`, `_routerConfigurationHash` and `_scheduleOracleRuntimeHash`
    ///      words stay zero.
    function _initializeRegistry(IBuilderRegistry.BuilderRegistryConstructorV1 memory _config)
        internal
    {
        if (
            _config.settlementChainId == 0 || _config.settlementChainId != block.chainid
                || _config.l2ChainId == 0 || _config.builderLeaseToken == address(0)
                || _config.builderLeaseTokenRuntimeHash == bytes32(0)
                || _config.leasePerWindowAtomic == 0
                || _config.leasePerWindowAtomic > _config.maximumBondAtomic
                || _config.reporterRewardCapAtomic > _config.leasePerWindowAtomic / 5
                || _config.builderPenaltySink == address(0)
                || _config.builderPenaltySink == address(this) || _config.settlement == address(0)
                || _config.settlement == address(this) || _config.scheduleOracle == address(0)
                || _config.scheduleOracle == address(this)
                || _config.scheduleOracle == _config.settlement
                || _config.builderProofVerifier == address(0)
                || _config.builderProofVerifierRuntimeHash == bytes32(0)
                || _config.builderProofVerifierConfigurationHash == bytes32(0)
                || _config.seatLifecycleFacet == address(0)
                || _config.seatLifecycleFacetRuntimeHash == bytes32(0)
                || _config.seatLifecycleFacetConfigurationHash == bytes32(0)
                || _config.leaseLifecycleFacet == address(0)
                || _config.leaseLifecycleFacetRuntimeHash == bytes32(0)
                || _config.leaseLifecycleFacetConfigurationHash == bytes32(0)
        ) {
            revert InvalidBuilderRegistryConfiguration();
        }
        for (uint256 i; i < 3; ++i) {
            if (
                _config.rewardClasses[i].classId != i + 1
                    || _config.rewardClasses[i].nameHash == bytes32(0)
            ) {
                revert InvalidRewardClassConfiguration();
            }
        }

        uint256 maximumLiabilityResidence = uint256(LibBuilderRegistry.MAX_TRANCHE_AHEAD_WINDOWS)
            + 3
            + (uint256(_config.evidenceDelaySeconds) + uint256(_config.reorgMarginSeconds) + 383)
            / 384;
        if (maximumLiabilityResidence >= LibBuilderRegistry.MAX_LIVE_WINDOWS) {
            revert InvalidLiabilityResidence();
        }

        uint64 lastWindow = _deriveLastManagedWindow(
            _config.genesisTimestamp, _config.evidenceDelaySeconds, _config.reorgMarginSeconds
        );
        if (lastWindow < _config.firstManagedWindow) revert InvalidManagedWindowRange();

        bytes memory decimalsReturn = LibExactCall.staticcallExact(
            _config.builderLeaseToken,
            _config.builderLeaseTokenRuntimeHash,
            abi.encodePacked(_DECIMALS_SELECTOR),
            _EXTERNAL_READ_GAS,
            32,
            0
        );
        if (LibExactCall.u8Word(decimalsReturn, 0) != _config.builderLeaseTokenDecimals) {
            revert BuilderTokenDecimalsMismatch();
        }

        LibBuilderRegistry.EconomicConfig memory economic;
        economic.settlementChainId = _config.settlementChainId;
        economic.builderLeaseToken = _config.builderLeaseToken;
        economic.builderLeaseTokenRuntimeHash = _config.builderLeaseTokenRuntimeHash;
        economic.builderLeaseTokenDecimals = _config.builderLeaseTokenDecimals;
        economic.leasePerWindowAtomic = _config.leasePerWindowAtomic;
        economic.maximumBondAtomic = _config.maximumBondAtomic;
        economic.reporterRewardCapAtomic = _config.reporterRewardCapAtomic;
        economic.evidenceDelaySeconds = _config.evidenceDelaySeconds;
        economic.reorgMarginSeconds = _config.reorgMarginSeconds;
        economic.builderPenaltySink = _config.builderPenaltySink;
        economic.rewardClaimWindowSeconds = _config.rewardClaimWindowSeconds;
        economic.rewardClasses = _config.rewardClasses;
        bytes32 economicHash = LibBuilderRegistry.economicConfigurationHash(economic);
        LibBuilderRegistry.TopologyConfig memory topology;
        topology.settlementChainId = _config.settlementChainId;
        topology.l2ChainId = _config.l2ChainId;
        topology.builderLeaseToken = _config.builderLeaseToken;
        topology.builderLeaseTokenRuntimeHash = _config.builderLeaseTokenRuntimeHash;
        topology.builderLeaseTokenDecimals = _config.builderLeaseTokenDecimals;
        topology.genesisTimestamp = _config.genesisTimestamp;
        topology.evidenceDelaySeconds = _config.evidenceDelaySeconds;
        topology.reorgMarginSeconds = _config.reorgMarginSeconds;
        topology.firstManagedWindow = _config.firstManagedWindow;
        topology.lastManagedWindow = lastWindow;
        topology.builderPenaltySink = _config.builderPenaltySink;
        topology.rewardClaimWindowSeconds = _config.rewardClaimWindowSeconds;
        topology.settlement = _config.settlement;
        topology.scheduleOracle = _config.scheduleOracle;
        topology.builderProofVerifier = _config.builderProofVerifier;
        topology.builderProofVerifierRuntimeHash = _config.builderProofVerifierRuntimeHash;
        topology.builderProofVerifierConfigurationHash =
        _config.builderProofVerifierConfigurationHash;
        topology.seatLifecycleFacet = _config.seatLifecycleFacet;
        topology.seatLifecycleFacetRuntimeHash = _config.seatLifecycleFacetRuntimeHash;
        topology.seatLifecycleFacetConfigurationHash = _config.seatLifecycleFacetConfigurationHash;
        topology.leaseLifecycleFacet = _config.leaseLifecycleFacet;
        topology.leaseLifecycleFacetRuntimeHash = _config.leaseLifecycleFacetRuntimeHash;
        topology.leaseLifecycleFacetConfigurationHash = _config.leaseLifecycleFacetConfigurationHash;
        topology.economicConfigurationHash = economicHash;

        _registrySelf = address(this);
        _builderProofVerifier = _config.builderProofVerifier;
        _builderProofVerifierRuntimeHash = _config.builderProofVerifierRuntimeHash;
        _builderProofVerifierConfigurationHash = _config.builderProofVerifierConfigurationHash;
        _settlementChainId = _config.settlementChainId;
        _builderLeaseToken = _config.builderLeaseToken;
        _builderLeaseTokenRuntimeHash = _config.builderLeaseTokenRuntimeHash;
        _builderLeaseTokenDecimals = _config.builderLeaseTokenDecimals;
        _leasePerWindowAtomic = _config.leasePerWindowAtomic;
        _maximumBondAtomic = _config.maximumBondAtomic;
        _reporterRewardCapAtomic = _config.reporterRewardCapAtomic;
        _genesisTimestamp = _config.genesisTimestamp;
        _evidenceDelaySeconds = _config.evidenceDelaySeconds;
        _reorgMarginSeconds = _config.reorgMarginSeconds;
        _firstManagedWindow = _config.firstManagedWindow;
        _lastManagedWindow = lastWindow;
        _builderPenaltySink = _config.builderPenaltySink;
        _rewardClaimWindowSeconds = _config.rewardClaimWindowSeconds;
        _activeSettlementRouter = _config.settlement;
        _scheduleOracle = _config.scheduleOracle;
        _economicConfigurationHash = economicHash;
        _topologyHash = LibBuilderRegistry.topologyHash(topology);
        for (uint256 i; i < 3; ++i) {
            _rewardClassRows[i] = _config.rewardClasses[i];
        }

        _requireProofVerifier();
        _registryRoot = LibSlotChainFixedTrees.emptyRegistryRoot();
        _admissionRoot = LibSlotChainFixedTrees.emptyAdmissionRoot();
        _syncHistoricalSlots();
    }

    /// @dev Authenticates the stateless verifier's runtime and both exact configuration reads.
    function _requireProofVerifier() private view {
        if (_builderProofVerifierConfigurationHash != _BPV1_CONFIGURATION_HASH) {
            revert InvalidBuilderProofVerifier();
        }
        bytes memory config = LibExactCall.staticcallExact(
            _builderProofVerifier,
            _builderProofVerifierRuntimeHash,
            abi.encodePacked(_BPV1_SELECTOR),
            100_000,
            512,
            0
        );
        if (keccak256(config) != _BPV1_RETURN_HASH) revert InvalidBuilderProofVerifier();
        LibExactCall.requireConfiguration(
            _builderProofVerifier,
            _builderProofVerifierRuntimeHash,
            _COMPONENT_CONFIG_SELECTOR,
            _builderProofVerifierConfigurationHash,
            50_000,
            0
        );
    }

    /// @dev Calls the authenticated verifier and checks the complete BPO1 envelope.
    function _verifyProof(
        bytes memory _request,
        uint256 _gasLimit
    )
        private
        view
        returns (bytes memory output_)
    {
        output_ = LibExactCall.staticcallExact(
            _builderProofVerifier,
            _builderProofVerifierRuntimeHash,
            abi.encodeWithSelector(
                IBuilderRegistryProofVerifierV1.verifyBuilderRegistryProofV1.selector, _request
            ),
            _gasLimit,
            192,
            0
        );
        if (
            LibExactCall.bytes4Word(output_, 0) != _BPO1_MAGIC
                || LibExactCall.word(output_, 1) != _builderProofVerifierConfigurationHash
                || LibExactCall.word(output_, 2)
                    != keccak256(
                        abi.encodePacked(
                            "slot-chain-builder-proof-request-v1", uint32(_request.length), _request
                        )
                    )
        ) {
            revert InvalidBuilderProofResult();
        }
    }

    /// @dev Returns the verifier-authenticated root after one registry-cell replacement.
    function _replaceRegistryRoot(
        bytes32 _root,
        uint8 _index,
        bool _oldOccupied,
        SlotChainTypes.RegistryCellV1 memory _oldCell,
        bool _newOccupied,
        SlotChainTypes.RegistryCellV1 memory _newCell,
        bytes calldata _siblings
    )
        private
        view
        returns (bytes32 root_)
    {
        if (_siblings.length != 192) revert InvalidBuilderProofRequest();
        bytes memory request = bytes.concat(
            _BPR1_MAGIC,
            bytes1(uint8(1)),
            _root,
            bytes1(_index),
            bytes1(_oldOccupied ? uint8(1) : uint8(0)),
            _registryCellBytes(_oldCell),
            bytes1(_newOccupied ? uint8(1) : uint8(0)),
            _registryCellBytes(_newCell),
            _siblings
        );
        bytes memory output = _verifyProof(request, 120_000);
        if (
            LibExactCall.word(output, 4) != bytes32(0) || LibExactCall.word(output, 5) != bytes32(0)
        ) {
            revert InvalidBuilderProofResult();
        }
        root_ = LibExactCall.word(output, 3);
        if (root_ == bytes32(0)) revert InvalidBuilderProofResult();
    }

    /// @dev Returns the verifier-authenticated root after one admission-cell replacement.
    function _replaceAdmissionRoot(
        bytes32 _root,
        uint16 _position,
        bool _oldOccupied,
        uint8 _oldLocation,
        SlotChainTypes.RegistryCellV1 memory _oldCell,
        bool _newOccupied,
        uint8 _newLocation,
        SlotChainTypes.RegistryCellV1 memory _newCell,
        bytes calldata _siblings
    )
        private
        view
        returns (bytes32 root_)
    {
        if (_siblings.length != 352) revert InvalidBuilderProofRequest();
        bytes memory request = bytes.concat(
            _BPR1_MAGIC,
            bytes1(uint8(2)),
            _root,
            bytes2(_position),
            bytes1(_oldOccupied ? uint8(1) : uint8(0)),
            bytes1(_oldLocation),
            _admissionCellBytes(_oldCell),
            bytes1(_newOccupied ? uint8(1) : uint8(0)),
            bytes1(_newLocation),
            _admissionCellBytes(_newCell),
            _siblings
        );
        bytes memory output = _verifyProof(request, 160_000);
        if (
            LibExactCall.word(output, 3) != bytes32(0) || LibExactCall.word(output, 5) != bytes32(0)
        ) {
            revert InvalidBuilderProofResult();
        }
        root_ = LibExactCall.word(output, 4);
        if (root_ == bytes32(0)) revert InvalidBuilderProofResult();
    }

    /// @dev Returns the verifier-authenticated root after one or more tranche transitions.
    function _replaceTrancheRoot(bytes memory _request) private view returns (bytes32 root_) {
        bytes memory output = _verifyProof(_request, 700_000);
        if (
            LibExactCall.word(output, 3) != bytes32(0) || LibExactCall.word(output, 4) != bytes32(0)
        ) {
            revert InvalidBuilderProofResult();
        }
        root_ = LibExactCall.word(output, 5);
        if (root_ == bytes32(0)) revert InvalidBuilderProofResult();
    }

    /// @dev Packs one exact 100-byte Registry-cell preimage.
    function _registryCellBytes(SlotChainTypes.RegistryCellV1 memory _cell)
        private
        pure
        returns (bytes memory encoded_)
    {
        return abi.encodePacked(
            _cell.builder,
            _cell.bond,
            _cell.registrationIndex,
            _cell.effectiveL2Slot,
            _cell.trancheRoot,
            _cell.tombstonedAtL2Slot
        );
    }

    /// @dev Packs one exact 68-byte admission-cell preimage.
    function _admissionCellBytes(SlotChainTypes.RegistryCellV1 memory _cell)
        private
        pure
        returns (bytes memory encoded_)
    {
        return abi.encodePacked(
            _cell.builder,
            _cell.bond,
            _cell.registrationIndex,
            _cell.effectiveL2Slot,
            _cell.tombstonedAtL2Slot
        );
    }

    /// @dev Packs one exact 43-byte tranche-leaf preimage.
    function _trancheLeafBytes(SlotChainTypes.TrancheLeafV1 memory _leaf)
        private
        pure
        returns (bytes memory encoded_)
    {
        return abi.encodePacked(
            _leaf.index, _leaf.window, _leaf.state, _leaf.amount, _leaf.liableUntil
        );
    }

    /// @inheritdoc IComponentConfigV2
    function componentConfigHashV2() external view virtual returns (bytes32 configHash_) {
        return _economicConfigurationHash;
    }

    /// @dev Implements the raw 768-byte `IBuilderRegistry.builderRegistryConfigV1` wire
    ///      response without declaring its non-compilable twenty-four-output Solidity signature.
    function builderRegistryConfigV1() external view virtual {
        bytes memory output = new bytes(768);
        _storeWord(output, 0, bytes32(_BRC1_MAGIC));
        _storeWord(output, 1, bytes32(_settlementChainId));
        _storeWord(output, 2, bytes32(_l2ChainId));
        _storeWord(output, 3, bytes32(uint256(uint160(_builderLeaseToken))));
        _storeWord(output, 4, _builderLeaseTokenRuntimeHash);
        _storeWord(output, 5, bytes32(uint256(_builderLeaseTokenDecimals)));
        _storeWord(output, 6, bytes32(uint256(_leasePerWindowAtomic)));
        _storeWord(output, 7, bytes32(uint256(_maximumBondAtomic)));
        _storeWord(output, 8, bytes32(uint256(_reporterRewardCapAtomic)));
        _storeWord(output, 9, bytes32(uint256(_genesisTimestamp)));
        _storeWord(output, 10, bytes32(uint256(_evidenceDelaySeconds)));
        _storeWord(output, 11, bytes32(uint256(_reorgMarginSeconds)));
        _storeWord(output, 12, bytes32(uint256(_firstManagedWindow)));
        _storeWord(output, 13, bytes32(uint256(_lastManagedWindow)));
        _storeWord(output, 14, bytes32(uint256(uint160(_builderPenaltySink))));
        _storeWord(output, 15, bytes32(uint256(_rewardClaimWindowSeconds)));
        _storeWord(output, 16, bytes32(uint256(uint160(_activator))));
        _storeWord(output, 17, bytes32(uint256(uint160(_activeSettlementRouter))));
        _storeWord(output, 18, bytes32(uint256(uint160(_scheduleOracle))));
        _storeWord(output, 19, bytes32(uint256(uint160(_builderProofVerifier))));
        _storeWord(output, 20, _builderProofVerifierRuntimeHash);
        _storeWord(output, 21, _builderProofVerifierConfigurationHash);
        _storeWord(output, 22, _economicConfigurationHash);
        _storeWord(output, 23, _topologyHash);
        assembly ("memory-safe") {
            return(add(output, 32), 768)
        }
    }

    /// @dev Implements {IBuilderRegistry-builderRegistryTopologyHashV1}; readable before
    ///      activation.
    function builderRegistryTopologyHashV1() external view virtual returns (bytes32 topologyHash_) {
        return _topologyHash;
    }

    /// @dev Implements {IBuilderRegistry-rewardClassV1}.
    function rewardClassV1(uint8 _classId)
        external
        view
        virtual
        onlyActivatedRegistry
        returns (
            bytes4 magic_,
            bytes32 economicConfigurationHash_,
            uint8 classId_,
            uint256 fixedWei_,
            uint256 perExecutionGasWei_,
            uint256 perPublishedByteWei_,
            uint256 capWei_
        )
    {
        if (msg.data.length != 36) revert NonCanonicalCalldata();
        if (_classId == 0 || _classId > 3) {
            revert InvalidRewardClass();
        }
        IBuilderRegistry.BuilderRewardClassConfigV1 storage rewardClass =
            _rewardClassRows[_classId - 1];
        return (
            _RCV1_MAGIC,
            _economicConfigurationHash,
            _classId,
            rewardClass.fixedWei,
            rewardClass.perExecutionGasWei,
            rewardClass.perPublishedByteWei,
            rewardClass.capWei
        );
    }

    /// @dev Implements {IBuilderRegistry-admissionStateV1}.
    function admissionStateV1()
        external
        view
        virtual
        onlyActivatedRegistry
        returns (bytes4 magic_, uint64 admissionVersion_, bytes32 admissionRoot_)
    {
        return (_ADS1_MAGIC, _admissionVersion, _admissionRoot);
    }

    /// @dev Implements {IBuilderRegistry-scheduleRegistryStateV1}.
    function scheduleRegistryStateV1()
        external
        view
        virtual
        onlyActivatedRegistry
        returns (
            bytes4 magic_,
            uint8 schema_,
            uint8 activeCount_,
            uint64 registryMutationVersion_,
            uint64 admissionVersion_,
            uint256 nextRegistrationIndex_,
            bytes32 registryRoot_
        )
    {
        return (
            _BRS1_MAGIC,
            1,
            _activeCount,
            _registryMutationVersion,
            _admissionVersion,
            _nextRegistrationIndex,
            _registryRoot
        );
    }

    /// @dev Implements {IBuilderRegistry-registerBuilderV1}.
    function registerBuilderV1(
        uint192 _baseBondAtomic,
        uint64 _expectedNextRegistrationIndex,
        uint8 _expectedActiveIndex,
        bytes calldata _witness
    )
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        tokenNonReentrant
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint8 activeIndex_,
            uint64 effectiveL2Slot_,
            uint64 admissionVersion_,
            bytes32 admissionRoot_
        )
    {
        _requireCanonicalDynamicCalldata(_witness, 4);
        _requireProofVerifier();
        RegistrationContext memory context = _registerBuilder(
            msg.sender,
            _baseBondAtomic,
            _expectedNextRegistrationIndex,
            _expectedActiveIndex,
            _witness
        );
        return (
            _BRG1_MAGIC,
            context.registrationIndex,
            context.activeIndex,
            context.effectiveL2Slot,
            _admissionVersion,
            _admissionRoot
        );
    }

    /// @dev Registers one builder after canonical external-boundary checks.
    function _registerBuilder(
        address _builder,
        uint192 _baseBondAtomic,
        uint64 _expectedNextRegistrationIndex,
        uint8 _expectedActiveIndex,
        bytes calldata _witness
    )
        private
        returns (RegistrationContext memory context_)
    {
        if (
            _builder == address(0) || _baseBondAtomic < _leasePerWindowAtomic
                || _baseBondAtomic > _maximumBondAtomic || _nextRegistrationIndex > type(uint64).max
                || _expectedNextRegistrationIndex != _nextRegistrationIndex
                || _liveIndexPlusOne[_builder] != 0
        ) {
            revert InvalidBuilderRegistration();
        }
        uint256 currentSlot = _currentL2Slot();
        if (currentSlot > type(uint64).max) revert L2SlotOutOfRange();
        uint256 effective = currentSlot + uint256(LibBuilderRegistry.ENTRY_DELAY_WINDOWS) * 384;
        if (effective > type(uint64).max || effective / 384 > _lastManagedWindow) {
            revert BuilderEntryBeyondManagedRange();
        }
        context_.currentWindow = uint64(currentSlot / 384);
        context_.registrationIndex = uint64(_nextRegistrationIndex);
        context_.effectiveL2Slot = uint64(effective);

        LibBuilderRegistry.Generation memory newcomer;
        newcomer.builder = _builder;
        newcomer.bond = _baseBondAtomic;
        newcomer.registrationIndex = context_.registrationIndex;
        newcomer.effectiveL2Slot = context_.effectiveL2Slot;
        newcomer.trancheRoot = LibSlotChainFixedTrees.emptyTrancheRoot();
        newcomer.tombstonedAtL2Slot = _LIVE_TOMBSTONE;
        newcomer.reservationBaseWindow = context_.currentWindow;

        (context_.hasVacancy, context_.activeIndex) = _selectVacancyOrVictim(_baseBondAtomic);
        if (_expectedActiveIndex != context_.activeIndex) revert ActiveIndexRace();
        context_.balanceBefore = _builderTokenBalance(address(this));

        if (context_.hasVacancy) {
            _registerVacant(context_.activeIndex, newcomer, _witness);
            ++_activeCount;
        } else {
            _requireReplacementReady(context_.currentWindow);
            _moveActiveToLiability(
                context_.activeIndex, newcomer, true, context_.currentWindow, _witness
            );
        }

        _baseBondEscrow += _baseBondAtomic;
        ++_nextRegistrationIndex;
        _incrementRegistryVersion();
        _incrementAdmissionVersion();
        _syncHistoricalSlots();
        _pullBuilderToken(_builder, _baseBondAtomic, context_.balanceBefore);

        emit IBuilderRegistry.BuilderRegistered(
            _builder,
            context_.registrationIndex,
            context_.activeIndex,
            _baseBondAtomic,
            context_.effectiveL2Slot
        );
    }

    /// @dev Implements {IBuilderRegistry-reserveBuilderWindowV1}.
    function reserveBuilderWindowV1(
        uint64 _expectedRegistrationIndex,
        uint64 _window,
        bytes calldata _witness
    )
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        tokenNonReentrant
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint64 window_,
            uint64 registryMutationVersion_,
            bytes32 registryRoot_
        )
    {
        _requireCanonicalDynamicCalldata(_witness, 3);
        _requireProofVerifier();
        _requireSettlementOpen();
        _reserveBuilderWindow(msg.sender, _expectedRegistrationIndex, _window, _witness);
        return (
            _BRV1_MAGIC,
            _expectedRegistrationIndex,
            _window,
            _registryMutationVersion,
            _registryRoot
        );
    }

    /// @dev Applies one idempotent or new reservation after the external boundary checks.
    function _reserveBuilderWindow(
        address _builder,
        uint64 _expectedRegistrationIndex,
        uint64 _window,
        bytes calldata _witness
    )
        private
    {
        ReservationContext memory context;
        (uint8 activeIndex, LibBuilderRegistry.Generation storage generation) =
            _activeGeneration(_builder, _expectedRegistrationIndex);
        context.activeIndex = activeIndex;
        uint256 currentWindow256 = _currentL2Slot() / 384;
        if (
            currentWindow256 > type(uint64).max || _window < currentWindow256
                || _window < _firstManagedWindow || _window > _lastManagedWindow
                || uint256(_window)
                    > currentWindow256 + LibBuilderRegistry.MAX_TRANCHE_AHEAD_WINDOWS
                || generation.reservationsClosed || generation.tombstonedAtL2Slot != _LIVE_TOMBSTONE
        ) {
            revert InvalidBuilderReservation();
        }
        context.currentWindow = uint64(currentWindow256);
        context.staleMask = _staleMask(generation, context.currentWindow);
        context.closeCount = LibBuilderRegistry.popcount(context.staleMask);
        SlotChainTypes.TrancheLeafV1 storage stored =
            _tranches[_expectedRegistrationIndex][uint16(_window % 512)];
        context.alreadyReserved =
            stored.state == LibBuilderRegistry.TRANCHE_RESERVED && stored.window == _window;

        if (context.alreadyReserved) {
            context.rootChanged = _reserveExistingWindow(generation, _window, context, _witness);
        } else {
            _reserveNewWindow(generation, _expectedRegistrationIndex, _window, context, _witness);
            context.rootChanged = true;
        }

        if (context.rootChanged) {
            _incrementRegistryVersion();
            _syncHistoricalSlots();
        } else {
            _shiftReservationWindow(generation, context.currentWindow);
        }
        if (!context.alreadyReserved) {
            _pullBuilderToken(_builder, _leasePerWindowAtomic, context.balanceBefore);
        }
        if (context.rootChanged || !context.alreadyReserved) {
            emit IBuilderRegistry.BuilderWindowReserved(
                _builder, _expectedRegistrationIndex, _window
            );
        }
    }

    /// @dev Applies the idempotent reservation grammar and any required stale normalization.
    function _reserveExistingWindow(
        LibBuilderRegistry.Generation storage _generation,
        uint64 _window,
        ReservationContext memory _context,
        bytes calldata _witness
    )
        private
        returns (bool rootChanged_)
    {
        if (_context.closeCount == 0) {
            if (_witness.length != 1 || LibBuilderRegistry.readU8(_witness, 0) != 0) {
                revert InvalidReservationWitness();
            }
        } else {
            if (_witness.length != 193 + uint256(_context.closeCount) * 296) {
                revert InvalidReservationWitness();
            }
            _normalizeWithWitness(
                _context.activeIndex,
                _generation,
                _context.currentWindow,
                _context.staleMask,
                _witness
            );
            rootChanged_ = true;
        }
        _requireReservationIndexed(_generation, _window);
    }

    /// @dev Inserts one new reservation after closing every stale reservation in the witness.
    function _reserveNewWindow(
        LibBuilderRegistry.Generation storage _generation,
        uint64 _registrationIndex,
        uint64 _window,
        ReservationContext memory _context,
        bytes calldata _witness
    )
        private
    {
        if (
            _witness.length != 481 + uint256(_context.closeCount) * 296
                || LibBuilderRegistry.readU8(_witness, 0) != _context.closeCount
        ) {
            revert InvalidReservationWitness();
        }
        _context.balanceBefore = _builderTokenBalance(address(this));
        SlotChainTypes.RegistryCellV1 memory oldCell = LibBuilderRegistry.cell(_generation);
        uint256 offset = _closeMask(_generation, _context.staleMask, _witness, 1);
        _shiftReservationWindow(_generation, _context.currentWindow);
        offset = _insertReservedTranche(_generation, _registrationIndex, _window, _witness, offset);
        _registryRoot = _replaceRegistryRoot(
            _registryRoot,
            _context.activeIndex,
            true,
            oldCell,
            true,
            LibBuilderRegistry.cell(_generation),
            _witness[offset:offset + 192]
        );
        _trancheEscrow += _leasePerWindowAtomic;
    }

    /// @dev Replaces one reusable tranche-ring leaf and updates its generation accounting.
    function _insertReservedTranche(
        LibBuilderRegistry.Generation storage _generation,
        uint64 _registrationIndex,
        uint64 _window,
        bytes calldata _witness,
        uint256 _offset
    )
        private
        returns (uint256 nextOffset_)
    {
        uint16 trancheIndex = uint16(_window % 512);
        SlotChainTypes.TrancheLeafV1 memory oldTranche =
            _storedTranche(_registrationIndex, trancheIndex);
        if (
            oldTranche.state != LibBuilderRegistry.TRANCHE_EMPTY
                && !(oldTranche.window < _window
                    && (oldTranche.state == LibBuilderRegistry.TRANCHE_RELEASED
                        || oldTranche.state == LibBuilderRegistry.TRANCHE_SLASHED))
        ) {
            revert TrancheRingCollision();
        }
        SlotChainTypes.TrancheLeafV1 memory newTranche = SlotChainTypes.TrancheLeafV1({
            index: trancheIndex,
            window: _window,
            state: LibBuilderRegistry.TRANCHE_RESERVED,
            amount: _leasePerWindowAtomic,
            liableUntil: _trancheDeadline(_window)
        });
        bytes memory request = bytes.concat(
            _BPR1_MAGIC,
            bytes1(uint8(3)),
            _generation.trancheRoot,
            bytes1(uint8(1)),
            _trancheLeafBytes(oldTranche),
            _trancheLeafBytes(newTranche),
            _witness[_offset:_offset + 288]
        );
        _generation.trancheRoot = _replaceTrancheRoot(request);
        _tranches[_registrationIndex][trancheIndex] = newTranche;
        uint64 offsetWindow = _window - _generation.reservationBaseWindow;
        if (offsetWindow > 16) revert InvalidReservationBitmap();
        _generation.reservationBitmap |= uint32(1) << uint8(offsetWindow);
        ++_generation.unreleasedTrancheCount;
        if (_window > _generation.maxReservedWindow) _generation.maxReservedWindow = _window;
        if (newTranche.liableUntil > _generation.maximumLiableUntil) {
            _generation.maximumLiableUntil = newTranche.liableUntil;
        }
        return _offset + 288;
    }

    /// @dev Implements {IBuilderRegistry-requestBuilderExitV1}.
    function requestBuilderExitV1(uint64 _expectedRegistrationIndex)
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        returns (bytes4 magic_, uint64 registrationIndex_, uint64 matureWindow_, uint8 activeIndex_)
    {
        if (msg.data.length != 36) revert NonCanonicalCalldata();
        (uint8 activeIndex, LibBuilderRegistry.Generation storage generation) =
            _activeGeneration(msg.sender, _expectedRegistrationIndex);
        uint256 currentWindow256 = _currentL2Slot() / 384;
        if (
            currentWindow256 > _lastManagedWindow || generation.reservationsClosed
                || generation.tombstonedAtL2Slot != _LIVE_TOMBSTONE || generation.hasExit
                || _nextExitSequence == type(uint64).max
        ) {
            revert InvalidBuilderExit();
        }
        uint256 mature = currentWindow256 + LibBuilderRegistry.EXIT_DELAY_WINDOWS;
        if (mature > type(uint64).max) revert ExitMaturityOverflow();
        uint64 sequence = _nextExitSequence++;
        matureWindow_ = uint64(mature);
        _exitRequests[sequence] = LibBuilderRegistry.ExitRequest({
            registrationIndex: _expectedRegistrationIndex,
            requestWindow: uint64(currentWindow256),
            matureWindow: matureWindow_,
            resolved: false
        });
        _exitByRegistration[_expectedRegistrationIndex] = uint256(sequence) + 1;
        generation.reservationsClosed = true;
        generation.hasExit = true;
        generation.exitSequence = sequence;
        emit IBuilderRegistry.BuilderExitRequested(
            msg.sender,
            _expectedRegistrationIndex,
            uint64(currentWindow256),
            matureWindow_,
            sequence
        );
        return (_BRE1_MAGIC, _expectedRegistrationIndex, matureWindow_, activeIndex);
    }

    /// @dev Implements {IBuilderRegistry-processBuilderMaintenanceV1}.
    function processBuilderMaintenanceV1(
        uint8 _maxMoves,
        bytes calldata _witness
    )
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        returns (
            bytes4 magic_,
            uint8 inspected_,
            uint8 moved_,
            uint64 admissionVersion_,
            bytes32 admissionRoot_
        )
    {
        _requireCanonicalDynamicCalldata(_witness, 2);
        _requireProofVerifier();
        if (_maxMoves == 0 || _maxMoves > 4) {
            revert InvalidMaintenanceLimit();
        }
        uint256 currentWindow256 = _currentL2Slot() / 384;
        if (currentWindow256 > _lastManagedWindow) {
            if (_witness.length != 0) revert InvalidMaintenanceWitness();
            return (_BRM1_MAGIC, 0, 0, _admissionVersion, _admissionRoot);
        }
        MaintenanceCursor memory cursor;
        cursor.currentWindow = uint64(currentWindow256);
        uint8 remaining = _remainingMoves(cursor.currentWindow);
        if (remaining == 0) {
            if (_witness.length != 0) revert InvalidMaintenanceWitness();
            return (_BRM1_MAGIC, 0, 0, _admissionVersion, _admissionRoot);
        }
        cursor.moveLimit = _maxMoves < remaining ? _maxMoves : remaining;

        while (_exitHeadSequence < _nextExitSequence && cursor.inspected < 64) {
            LibBuilderRegistry.ExitRequest storage request = _exitRequests[_exitHeadSequence];
            ++cursor.inspected;
            LibBuilderRegistry.Location memory location = _locations[request.registrationIndex];
            if (request.resolved || location.kind != LibBuilderRegistry.LOCATION_ACTIVE) {
                request.resolved = true;
                ++_exitHeadSequence;
                continue;
            }
            _requireLocatedGeneration(request.registrationIndex, location);
            if (request.matureWindow > cursor.currentWindow) break;
            if (cursor.moved == cursor.moveLimit) break;
            cursor.witnessOffset += _maintenanceMove(
                location.index, cursor.currentWindow, _witness, cursor.witnessOffset
            );
            request.resolved = true;
            ++_exitHeadSequence;
            ++cursor.moved;
        }

        bool inspectionBoundHit = cursor.inspected == 64 && _exitHeadSequence < _nextExitSequence;
        if (!inspectionBoundHit && !_hasMatureHead(cursor.currentWindow)) {
            while (cursor.moved < cursor.moveLimit) {
                (bool found, uint8 tombstoneIndex) = _selectTombstone();
                if (!found) break;
                cursor.witnessOffset += _maintenanceMove(
                    tombstoneIndex, cursor.currentWindow, _witness, cursor.witnessOffset
                );
                ++cursor.moved;
            }
        }
        if (cursor.witnessOffset != _witness.length) revert InvalidMaintenanceWitness();
        if (cursor.moved != 0) {
            _incrementRegistryVersion();
            _incrementAdmissionVersion();
            _syncHistoricalSlots();
        }
        inspected_ = cursor.inspected;
        moved_ = cursor.moved;
        return (_BRM1_MAGIC, inspected_, moved_, _admissionVersion, _admissionRoot);
    }

    /// @dev Implements {IBuilderRegistry-normalizeBuilderTranchesV1}.
    function normalizeBuilderTranchesV1(
        address _builder,
        uint64 _expectedRegistrationIndex,
        bytes calldata _witness
    )
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint8 closedCount_,
            uint64 registryMutationVersion_,
            bytes32 registryRoot_
        )
    {
        _requireCanonicalDynamicCalldata(_witness, 3);
        _requireProofVerifier();
        closedCount_ = _normalizeBuilderTranches(_builder, _expectedRegistrationIndex, _witness);
        return (
            _BRN1_MAGIC,
            _expectedRegistrationIndex,
            closedCount_,
            _registryMutationVersion,
            _registryRoot
        );
    }

    /// @dev Normalizes every currently stale tranche and returns the number closed.
    function _normalizeBuilderTranches(
        address _builder,
        uint64 _expectedRegistrationIndex,
        bytes calldata _witness
    )
        private
        returns (uint8 closedCount_)
    {
        (uint8 activeIndex, LibBuilderRegistry.Generation storage generation) =
            _activeGeneration(_builder, _expectedRegistrationIndex);
        uint256 currentWindow256 = _currentL2Slot() / 384;
        uint32 closeMask;
        bool terminal = currentWindow256 > _lastManagedWindow;
        if (terminal) {
            _requireTerminalSchedule();
            closeMask = generation.reservationBitmap;
        } else {
            closeMask = _staleMask(generation, uint64(currentWindow256));
        }
        closedCount_ = LibBuilderRegistry.popcount(closeMask);
        if (closedCount_ == 0) {
            if (_witness.length != 1 || LibBuilderRegistry.readU8(_witness, 0) != 0) {
                revert InvalidNormalizationWitness();
            }
            if (!terminal) _shiftReservationWindow(generation, uint64(currentWindow256));
        } else {
            uint256 expectedLength = 193 + uint256(closedCount_) * 296;
            if (_witness.length != expectedLength) revert InvalidNormalizationWitness();
            SlotChainTypes.RegistryCellV1 memory oldCell = LibBuilderRegistry.cell(generation);
            uint256 offset = _closeMask(generation, closeMask, _witness, 1);
            if (terminal) {
                generation.reservationBitmap = 0;
            } else {
                _shiftReservationWindow(generation, uint64(currentWindow256));
            }
            _replaceActiveGenerationCell(
                activeIndex, oldCell, generation, _witness[offset:offset + 192]
            );
            _incrementRegistryVersion();
            _syncHistoricalSlots();
        }
    }

    /// @dev Replaces one occupied active cell against the current registry root.
    function _replaceActiveGenerationCell(
        uint8 _activeIndex,
        SlotChainTypes.RegistryCellV1 memory _oldCell,
        LibBuilderRegistry.Generation storage _generation,
        bytes calldata _proof
    )
        private
    {
        _registryRoot = _replaceRegistryRoot(
            _registryRoot,
            _activeIndex,
            true,
            _oldCell,
            true,
            LibBuilderRegistry.cell(_generation),
            _proof
        );
    }

    /// @dev Implements {IBuilderRegistry-releaseBuilderTrancheV1}.
    function releaseBuilderTrancheV1(
        address _builder,
        uint64 _expectedRegistrationIndex,
        uint64 _window,
        bytes calldata _witness
    )
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint64 window_,
            address builder_,
            uint256 creditedAmount_,
            uint64 registryMutationVersion_,
            bytes32 registryRoot_
        )
    {
        _requireCanonicalDynamicCalldata(_witness, 4);
        _requireProofVerifier();
        _releaseBuilderTranche(_builder, _expectedRegistrationIndex, _window, _witness);
        return (
            _BTR1_MAGIC,
            _expectedRegistrationIndex,
            _window,
            _builder,
            _leasePerWindowAtomic,
            _registryMutationVersion,
            _registryRoot
        );
    }

    /// @dev Releases one independently matured window tranche into the builder's pull credit.
    function _releaseBuilderTranche(
        address _builder,
        uint64 _expectedRegistrationIndex,
        uint64 _window,
        bytes calldata _witness
    )
        private
    {
        (
            LibBuilderRegistry.Location memory location,
            LibBuilderRegistry.Generation storage generation
        ) = _locatedGeneration(_builder, _expectedRegistrationIndex);
        uint16 trancheIndex = uint16(_window % 512);
        SlotChainTypes.TrancheLeafV1 storage stored =
            _tranches[_expectedRegistrationIndex][trancheIndex];
        if (
            stored.state != LibBuilderRegistry.TRANCHE_LIABLE || stored.window != _window
                || stored.amount != _leasePerWindowAtomic || block.timestamp <= stored.liableUntil
                || generation.unreleasedTrancheCount == 0
        ) {
            revert BuilderTrancheNotReleasable();
        }
        _requireExpiredSchedule(_window, false);
        uint256 expectedLength = location.kind == LibBuilderRegistry.LOCATION_ACTIVE ? 480 : 288;
        if (_witness.length != expectedLength) revert InvalidTrancheReleaseWitness();
        SlotChainTypes.RegistryCellV1 memory oldCell;
        if (location.kind == LibBuilderRegistry.LOCATION_ACTIVE) {
            oldCell = LibBuilderRegistry.cell(generation);
        }
        SlotChainTypes.TrancheLeafV1 memory oldTranche = stored;
        generation.trancheRoot =
            _releasedTrancheRoot(generation.trancheRoot, oldTranche, _witness[:288]);
        stored.state = LibBuilderRegistry.TRANCHE_RELEASED;
        stored.amount = 0;
        --generation.unreleasedTrancheCount;
        if (location.kind == LibBuilderRegistry.LOCATION_ACTIVE) {
            _replaceActiveGenerationCell(
                uint8(location.index), oldCell, generation, _witness[288:480]
            );
            _incrementRegistryVersion();
            _syncHistoricalSlots();
        }
        _trancheEscrow -= _leasePerWindowAtomic;
        _credit(_builder, _leasePerWindowAtomic);
        _assertSolvent();
        emit IBuilderRegistry.BuilderTrancheReleased(
            _builder, _expectedRegistrationIndex, _window, _leasePerWindowAtomic
        );
    }

    /// @dev Verifies one LIABILE-to-RELEASED tranche transition and returns its new root.
    function _releasedTrancheRoot(
        bytes32 _oldRoot,
        SlotChainTypes.TrancheLeafV1 memory _oldTranche,
        bytes calldata _proof
    )
        private
        view
        returns (bytes32 root_)
    {
        SlotChainTypes.TrancheLeafV1 memory newTranche = SlotChainTypes.TrancheLeafV1({
            index: _oldTranche.index,
            window: _oldTranche.window,
            state: LibBuilderRegistry.TRANCHE_RELEASED,
            amount: 0,
            liableUntil: _oldTranche.liableUntil
        });
        bytes memory request = bytes.concat(
            _BPR1_MAGIC,
            bytes1(uint8(3)),
            _oldRoot,
            bytes1(uint8(1)),
            _trancheLeafBytes(_oldTranche),
            _trancheLeafBytes(newTranche),
            _proof
        );
        return _replaceTrancheRoot(request);
    }

    /// @dev Implements {IBuilderRegistry-releaseBuilderGenerationV1}.
    function releaseBuilderGenerationV1(
        address _builder,
        uint64 _expectedRegistrationIndex,
        bytes calldata _witness
    )
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            address builder_,
            uint256 creditedBond_,
            uint64 admissionVersion_,
            bytes32 admissionRoot_
        )
    {
        _requireCanonicalDynamicCalldata(_witness, 3);
        _requireProofVerifier();
        creditedBond_ = _releaseBuilderGeneration(_builder, _expectedRegistrationIndex, _witness);
        return (
            _BGR1_MAGIC,
            _expectedRegistrationIndex,
            _builder,
            creditedBond_,
            _admissionVersion,
            _admissionRoot
        );
    }

    /// @dev Releases one fully matured active or retained-liability generation.
    function _releaseBuilderGeneration(
        address _builder,
        uint64 _expectedRegistrationIndex,
        bytes calldata _witness
    )
        private
        returns (uint256 creditedBond_)
    {
        (
            LibBuilderRegistry.Location memory location,
            LibBuilderRegistry.Generation storage generation
        ) = _locatedGeneration(_builder, _expectedRegistrationIndex);
        if (
            generation.unreleasedTrancheCount != 0
                || block.timestamp <= generation.maximumLiableUntil
        ) {
            revert BuilderGenerationNotReleasable();
        }
        uint256 currentWindow = _currentL2Slot() / 384;
        bool terminal = currentWindow > _lastManagedWindow;
        uint192 bond = generation.bond;
        if (location.kind == LibBuilderRegistry.LOCATION_ACTIVE) {
            if (!terminal || _witness.length != 544) revert InvalidGenerationReleaseWitness();
            _requireTerminalSchedule();
            _releaseActiveGeneration(uint8(location.index), generation, _witness);
            --_activeCount;
            _incrementRegistryVersion();
        } else {
            if (_witness.length != 352) revert InvalidGenerationReleaseWitness();
            if (terminal) {
                _requireTerminalSchedule();
            } else if (currentWindow < generation.releaseWindow) {
                revert BuilderGenerationNotReleasable();
            }
            _releaseLiabilityGeneration(location.index, generation, _witness);
        }
        creditedBond_ = bond;
        _baseBondEscrow -= creditedBond_;
        _credit(_builder, creditedBond_);
        _markExitResolved(_expectedRegistrationIndex);
        delete _locations[_expectedRegistrationIndex];
        delete _liveIndexPlusOne[_builder];
        _incrementAdmissionVersion();
        _syncHistoricalSlots();
        _assertSolvent();
        emit IBuilderRegistry.BuilderGenerationReleased(
            _builder, _expectedRegistrationIndex, creditedBond_
        );
    }

    /// @dev Implements {IBuilderRegistry-claimBuilderLeaseCreditV1}.
    function claimBuilderLeaseCreditV1(address _recipient)
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        operationNonReentrant
        tokenNonReentrant
        returns (bytes4 magic_, address recipient_, uint256 paidAmount_)
    {
        if (msg.data.length != 36) revert NonCanonicalCalldata();
        if (_recipient == address(0) || _recipient == address(this)) {
            revert InvalidBuilderCreditRecipient();
        }
        paidAmount_ = _credits[msg.sender];
        if (paidAmount_ == 0) revert EmptyBuilderCredit();
        uint256 registryBalanceBefore = _builderTokenBalance(address(this));
        uint256 recipientBalanceBefore = _builderTokenBalance(_recipient);
        if (recipientBalanceBefore > type(uint256).max - paidAmount_) {
            revert BuilderTokenBalanceOverflow();
        }
        delete _credits[msg.sender];
        _totalCredits -= paidAmount_;
        _transferBuilderToken(
            _recipient, paidAmount_, registryBalanceBefore, recipientBalanceBefore
        );
        emit IBuilderRegistry.BuilderLeaseCreditClaimed(msg.sender, _recipient, paidAmount_);
        return (_BCL1_MAGIC, _recipient, paidAmount_);
    }

    /// @dev Implements {IBuilderRegistry-submitBuilderEquivocationV1}.
    function submitBuilderEquivocationV1(bytes calldata _evidence)
        external
        virtual
        onlyActivatedRegistry
        onlyRegistryContext
        operationNonReentrant
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint64 window_,
            address builder_,
            uint256 l2ChainId_,
            uint256 reporterAmount_,
            uint256 penaltyAmount_,
            uint64 admissionVersion_,
            bytes32 admissionRoot_
        )
    {
        _requireCanonicalDynamicCalldata(_evidence, 1);
        _requireProofVerifier();
        if (_evidence.length != 2366) revert InvalidEquivocationEvidence();
        (uint64 protocolVersion, address verifyingContract) = _precheckEvidenceDomain(_evidence);
        _requireSettlementVersion(protocolVersion, verifyingContract);
        EvidenceIdentity memory identity =
            _verifyEvidenceIdentity(_evidence, protocolVersion, verifyingContract);
        builder_ = identity.builder;
        window_ = identity.window;
        l2ChainId_ = identity.l2ChainId;
        if (window_ < _firstManagedWindow || window_ > _lastManagedWindow) {
            revert InvalidEvidenceWindow();
        }
        EvidenceTransition memory transition = _prepareEvidenceTransition(_evidence, identity);
        registrationIndex_ = transition.registrationIndex;
        _commitEvidenceTransition(transition);
        _trancheEscrow -= _leasePerWindowAtomic;
        reporterAmount_ = _reporterRewardCapAtomic;
        penaltyAmount_ = uint256(_leasePerWindowAtomic) - reporterAmount_;
        _credit(msg.sender, reporterAmount_);
        _credit(_builderPenaltySink, penaltyAmount_);
        if (transition.locationKind == LibBuilderRegistry.LOCATION_ACTIVE) {
            _incrementRegistryVersion();
        }
        if (transition.firstTombstone) _incrementAdmissionVersion();
        _syncHistoricalSlots();
        _assertSolvent();
        emit IBuilderRegistry.BuilderEquivocationSubmitted(
            builder_, registrationIndex_, window_, msg.sender, reporterAmount_, penaltyAmount_
        );
        return (
            _BEV1_MAGIC,
            registrationIndex_,
            window_,
            builder_,
            l2ChainId_,
            reporterAmount_,
            penaltyAmount_,
            _admissionVersion,
            _admissionRoot
        );
    }

    /// @dev Pair-checks the cheap signed domain fields before any signature recovery: both
    ///      settlement-chain IDs equal the local chain, both L2 chain IDs equal the pinned
    ///      `l2ChainId`, both protocol versions agree and fit uint64, and both verifying
    ///      contracts are the same nonzero address.
    function _precheckEvidenceDomain(bytes calldata _evidence)
        private
        view
        returns (uint64 protocolVersion_, address verifyingContract_)
    {
        uint256 chainA = uint256(LibBuilderRegistry.readBytes32(_evidence, 0));
        uint256 chainB = uint256(LibBuilderRegistry.readBytes32(_evidence, 586));
        uint256 l2ChainA = uint256(LibBuilderRegistry.readBytes32(_evidence, 32));
        uint256 l2ChainB = uint256(LibBuilderRegistry.readBytes32(_evidence, 618));
        uint256 versionA = uint256(LibBuilderRegistry.readBytes32(_evidence, 64));
        uint256 versionB = uint256(LibBuilderRegistry.readBytes32(_evidence, 650));
        address verifyingA = _readPackedAddress(_evidence, 96);
        address verifyingB = _readPackedAddress(_evidence, 682);
        if (
            chainA != _settlementChainId || chainB != chainA || l2ChainA != _l2ChainId
                || l2ChainB != l2ChainA || versionA != versionB || versionA > type(uint64).max
                || verifyingA == address(0) || verifyingB != verifyingA
        ) {
            revert InvalidEvidenceDomain();
        }
        return (uint64(versionA), verifyingA);
    }

    /// @dev Requires the signed verifying contract to be the pinned Settlement and the signed
    ///      protocol version to equal the version its SST1 view currently reports. Every SST1
    ///      mode is accepted, so evidence stays admissible while the Settlement drains or
    ///      recovers.
    function _requireSettlementVersion(
        uint64 _protocolVersion,
        address _verifyingContract
    )
        private
        view
    {
        if (_verifyingContract != _activeSettlementRouter) revert InvalidEvidenceDomain();
        (uint64 settlementVersion,) = _readSettlementState();
        if (settlementVersion != _protocolVersion) revert InvalidEvidenceDomain();
    }

    /// @dev Calls EIV1 and independently binds every returned identity field.
    function _verifyEvidenceIdentity(
        bytes calldata _evidence,
        uint64 _protocolVersion,
        address _verifyingContract
    )
        private
        view
        returns (EvidenceIdentity memory identity_)
    {
        bytes memory output = LibExactCall.staticcallExact(
            _builderProofVerifier,
            _builderProofVerifierRuntimeHash,
            abi.encodeWithSelector(
                IBuilderRegistryProofVerifierV1.verifyBuilderEquivocationIdentityV1.selector,
                _settlementChainId,
                _evidence
            ),
            350_000,
            352,
            0
        );
        identity_.evidenceHash = keccak256(_evidence);
        identity_.identityCommitment = LibExactCall.word(output, 3);
        identity_.builder = LibExactCall.addressWord(output, 4);
        identity_.window = LibExactCall.u64Word(output, 5);
        identity_.protocolVersion = LibExactCall.u64Word(output, 6);
        identity_.verifyingContract = LibExactCall.addressWord(output, 7);
        identity_.l2ChainId = uint256(LibExactCall.word(output, 8));
        identity_.signedAdmissionVersion = LibExactCall.u64Word(output, 9);
        identity_.signedAdmissionRoot = LibExactCall.word(output, 10);
        bytes32 expectedCommitment = keccak256(
            abi.encodePacked(
                "slot-chain-builder-equivocation-identity-v2",
                uint16(224),
                _builderProofVerifierConfigurationHash,
                identity_.evidenceHash,
                _settlementChainId,
                identity_.l2ChainId,
                identity_.protocolVersion,
                identity_.verifyingContract,
                identity_.window,
                identity_.signedAdmissionVersion,
                identity_.signedAdmissionRoot,
                identity_.builder
            )
        );
        if (
            LibExactCall.bytes4Word(output, 0) != bytes4(0x45495631)
                || LibExactCall.word(output, 1) != _builderProofVerifierConfigurationHash
                || LibExactCall.word(output, 2) != identity_.evidenceHash
                || identity_.identityCommitment != expectedCommitment
                || identity_.builder == address(0) || identity_.protocolVersion != _protocolVersion
                || identity_.verifyingContract != _verifyingContract
                || identity_.l2ChainId != _l2ChainId
                || identity_.window != LibBuilderRegistry.readU64(_evidence, 1526)
                || identity_.signedAdmissionVersion != LibBuilderRegistry.readU64(_evidence, 433)
                || identity_.signedAdmissionRoot != LibBuilderRegistry.readBytes32(_evidence, 441)
        ) {
            revert InvalidBuilderEvidenceIdentity();
        }
    }

    /// @dev Authenticates all evidence proofs and derives the complete slash poststate.
    function _prepareEvidenceTransition(
        bytes calldata _evidence,
        EvidenceIdentity memory _identity
    )
        private
        view
        returns (EvidenceTransition memory transition_)
    {
        uint256 registrationPlusOne = _liveIndexPlusOne[_identity.builder];
        if (registrationPlusOne == 0) revert BuilderGenerationNotFound();
        EvidenceRequestContext memory context;
        context.registrationIndex = uint64(registrationPlusOne - 1);
        (
            LibBuilderRegistry.Location memory location,
            LibBuilderRegistry.Generation storage generation
        ) = _locatedGeneration(_identity.builder, context.registrationIndex);
        context.locationKind = location.kind;
        context.position = location.kind == LibBuilderRegistry.LOCATION_ACTIVE
            ? location.index
            : uint16(64 + location.index);
        uint16 trancheIndex = uint16(_identity.window % 512);
        SlotChainTypes.TrancheLeafV1 storage stored =
            _tranches[context.registrationIndex][trancheIndex];
        _requireSlashableTranche(location, generation, stored, _identity.window);
        uint256 currentSlot = _currentL2Slot();
        if (currentSlot > type(uint64).max) revert L2SlotOutOfRange();
        context.currentL2Slot = uint64(currentSlot);
        context.oldCell = LibBuilderRegistry.cell(generation);
        context.oldTranche = stored;
        bytes memory request = _buildEvidenceRequest(_evidence, _identity, generation, context);
        if (request.length != 2727) revert InvalidBuilderProofRequest();
        bytes memory output = _verifyProof(request, 450_000);
        bool firstTombstone = context.oldCell.tombstonedAtL2Slot == _LIVE_TOMBSTONE;
        bytes32 newRegistryRoot = LibExactCall.word(output, 3);
        bytes32 newAdmissionRoot = LibExactCall.word(output, 4);
        bytes32 newTrancheRoot = LibExactCall.word(output, 5);
        if (
            (context.locationKind == LibBuilderRegistry.LOCATION_ACTIVE)
                    != (newRegistryRoot != bytes32(0))
                || firstTombstone != (newAdmissionRoot != bytes32(0))
                || newTrancheRoot == bytes32(0)
        ) {
            revert InvalidBuilderProofResult();
        }

        transition_.builder = _identity.builder;
        transition_.registrationIndex = context.registrationIndex;
        transition_.window = _identity.window;
        transition_.locationKind = context.locationKind;
        transition_.locationIndex = location.index;
        transition_.trancheIndex = trancheIndex;
        transition_.oldTrancheState = stored.state;
        transition_.firstTombstone = firstTombstone;
        transition_.tombstonedAtL2Slot =
            firstTombstone ? context.currentL2Slot : context.oldCell.tombstonedAtL2Slot;
        transition_.newTrancheRoot = newTrancheRoot;
        transition_.newAdmissionRoot = firstTombstone ? newAdmissionRoot : _admissionRoot;
        transition_.newRegistryRoot = context.locationKind == LibBuilderRegistry.LOCATION_ACTIVE
            ? newRegistryRoot
            : _registryRoot;
    }

    /// @dev Encodes the exact 2,727-byte operation-four proof request.
    function _buildEvidenceRequest(
        bytes calldata _evidence,
        EvidenceIdentity memory _identity,
        LibBuilderRegistry.Generation storage _generation,
        EvidenceRequestContext memory _context
    )
        private
        view
        returns (bytes memory request_)
    {
        request_ = bytes.concat(
            abi.encodePacked(_BPR1_MAGIC, uint8(4), _evidence),
            abi.encodePacked(
                _settlementChainId,
                _identity.evidenceHash,
                _identity.identityCommitment,
                _identity.builder,
                _context.registrationIndex,
                _context.locationKind,
                _context.position,
                _context.currentL2Slot
            ),
            abi.encodePacked(
                _registryRoot,
                _admissionRoot,
                _registryCellBytes(_context.oldCell),
                _generation.reservationBaseWindow,
                _generation.reservationBitmap,
                _generation.unreleasedTrancheCount,
                _trancheLeafBytes(_context.oldTranche)
            )
        );
    }

    /// @dev Requires the retained tranche and bitmap to be slashable for this exact window.
    function _requireSlashableTranche(
        LibBuilderRegistry.Location memory _location,
        LibBuilderRegistry.Generation storage _generation,
        SlotChainTypes.TrancheLeafV1 storage _stored,
        uint64 _window
    )
        private
        view
    {
        if (
            _stored.window != _window || _stored.amount != _leasePerWindowAtomic
                || (_stored.state != LibBuilderRegistry.TRANCHE_RESERVED
                    && _stored.state != LibBuilderRegistry.TRANCHE_LIABLE)
                || _stored.liableUntil != _trancheDeadline(_window)
                || block.timestamp > _stored.liableUntil || _generation.unreleasedTrancheCount == 0
        ) {
            revert EvidenceTrancheNotSlashable();
        }
        if (
            _location.kind == LibBuilderRegistry.LOCATION_ACTIVE
                && _stored.state == LibBuilderRegistry.TRANCHE_RESERVED
        ) {
            _requireReservationIndexed(_generation, _window);
        } else if (
            _location.kind == LibBuilderRegistry.LOCATION_LIABILITY
                && (_generation.reservationBitmap != 0
                    || _stored.state != LibBuilderRegistry.TRANCHE_LIABLE)
        ) {
            revert ReservationBitmapMismatch();
        }
    }

    /// @dev Commits one already fully verified evidence transition.
    function _commitEvidenceTransition(EvidenceTransition memory _transition) private {
        LibBuilderRegistry.Generation storage generation = _transition.locationKind
            == LibBuilderRegistry.LOCATION_ACTIVE
            ? _active[_transition.locationIndex]
            : _liabilities[_transition.locationIndex];
        if (
            generation.builder != _transition.builder
                || generation.registrationIndex != _transition.registrationIndex
        ) {
            revert BuilderLocatorMismatch();
        }
        SlotChainTypes.TrancheLeafV1 storage stored =
            _tranches[_transition.registrationIndex][_transition.trancheIndex];
        if (
            stored.state != _transition.oldTrancheState || stored.window != _transition.window
                || stored.amount != _leasePerWindowAtomic
        ) {
            revert TrancheStorageMismatch();
        }
        stored.state = LibBuilderRegistry.TRANCHE_SLASHED;
        stored.amount = 0;
        generation.trancheRoot = _transition.newTrancheRoot;
        generation.tombstonedAtL2Slot = _transition.tombstonedAtL2Slot;
        generation.reservationsClosed = true;
        --generation.unreleasedTrancheCount;
        if (
            _transition.locationKind == LibBuilderRegistry.LOCATION_ACTIVE
                && _transition.oldTrancheState == LibBuilderRegistry.TRANCHE_RESERVED
        ) {
            uint8 bitmapOffset = uint8(_transition.window - generation.reservationBaseWindow);
            generation.reservationBitmap &= ~(uint32(1) << bitmapOffset);
        }
        _registryRoot = _transition.newRegistryRoot;
        _admissionRoot = _transition.newAdmissionRoot;
    }

    /// @dev Registers one generation into a proven lowest vacant active position.
    function _registerVacant(
        uint8 _activeIndex,
        LibBuilderRegistry.Generation memory _newcomer,
        bytes calldata _witness
    )
        private
    {
        if (_witness.length != 544) revert InvalidVacantRegistrationWitness();
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        SlotChainTypes.RegistryCellV1 memory newcomerCell = LibBuilderRegistry.memoryCell(_newcomer);
        _registryRoot = _replaceRegistryRoot(
            _registryRoot, _activeIndex, false, emptyCell, true, newcomerCell, _witness[:192]
        );
        _admissionRoot = _replaceAdmissionRoot(
            _admissionRoot,
            _activeIndex,
            false,
            0,
            emptyCell,
            true,
            LibBuilderRegistry.LOCATION_ACTIVE,
            newcomerCell,
            _witness[192:544]
        );
        _active[_activeIndex] = _newcomer;
        _locations[_newcomer.registrationIndex] = LibBuilderRegistry.Location({
            kind: LibBuilderRegistry.LOCATION_ACTIVE, index: _activeIndex
        });
        _liveIndexPlusOne[_newcomer.builder] = uint256(_newcomer.registrationIndex) + 1;
    }

    /// @dev Moves one derived active victim into the next liability position.
    function _moveActiveToLiability(
        uint8 _activeIndex,
        LibBuilderRegistry.Generation memory _replacement,
        bool _hasReplacement,
        uint64 _currentWindow,
        bytes calldata _witness
    )
        private
    {
        LibBuilderRegistry.Generation storage victim = _active[_activeIndex];
        MovementContext memory context;
        uint8 closeCount = LibBuilderRegistry.popcount(victim.reservationBitmap);
        if (
            _witness.length
                    != LibBuilderRegistry.MOVE_BASE_LENGTH + uint256(closeCount)
                        * LibBuilderRegistry.CLOSE_RECORD_LENGTH
                || LibBuilderRegistry.readU8(_witness, 0) != closeCount
        ) {
            revert InvalidMovementWitness();
        }
        context.oldVictimCell = LibBuilderRegistry.cell(victim);
        context.offset = _closeMask(victim, victim.reservationBitmap, _witness, 1);
        victim.reservationBitmap = 0;
        victim.reservationBaseWindow = _currentWindow;
        victim.reservationsClosed = true;

        context.replacementCell = LibBuilderRegistry.memoryCell(_replacement);
        _registryRoot = _replaceRegistryRoot(
            _registryRoot,
            _activeIndex,
            true,
            context.oldVictimCell,
            _hasReplacement,
            context.replacementCell,
            _witness[context.offset:context.offset + 192]
        );
        context.offset += 192;

        if (_movementSequence == type(uint64).max) revert MovementSequenceExhausted();
        context.ringIndex = uint16(_movementSequence % 1072);
        context.liabilityPosition = uint16(64 + context.ringIndex);
        LibBuilderRegistry.Generation storage prior = _liabilities[context.ringIndex];
        context.priorOccupied = prior.builder != address(0);
        if (context.priorOccupied) {
            _requireLiabilityReusable(prior, _currentWindow);
            context.priorCell = LibBuilderRegistry.cell(prior);
        }
        context.retained = victim;
        uint256 releaseWindow = uint256(context.retained.maxReservedWindow) + 1
            + (_evidenceDelaySeconds + _reorgMarginSeconds + 383) / 384 + 2;
        if (releaseWindow > type(uint64).max) revert LiabilityReleaseWindowOverflow();
        context.retained.releaseWindow = uint64(releaseWindow);

        SlotChainTypes.RegistryCellV1 memory retainedCell =
            LibBuilderRegistry.memoryCell(context.retained);
        bytes32 r1 = _replaceLiabilityAdmissionRoot(
            context.liabilityPosition,
            context.priorOccupied,
            context.priorCell,
            retainedCell,
            _witness[context.offset:context.offset + 352]
        );
        context.offset += 352;
        _admissionRoot = _replaceActiveAdmissionRoot(
            r1,
            _activeIndex,
            context.oldVictimCell,
            _hasReplacement,
            context.replacementCell,
            _witness[context.offset:context.offset + 352]
        );

        if (context.priorOccupied) _releaseOverwrittenLiability(context.ringIndex, prior);

        _liabilities[context.ringIndex] = context.retained;
        _locations[context.retained.registrationIndex] = LibBuilderRegistry.Location({
            kind: LibBuilderRegistry.LOCATION_LIABILITY, index: context.ringIndex
        });
        _markExitResolved(context.retained.registrationIndex);
        if (_hasReplacement) {
            _active[_activeIndex] = _replacement;
            _locations[_replacement.registrationIndex] = LibBuilderRegistry.Location({
                kind: LibBuilderRegistry.LOCATION_ACTIVE, index: _activeIndex
            });
            _liveIndexPlusOne[_replacement.builder] = uint256(_replacement.registrationIndex) + 1;
        } else {
            delete _active[_activeIndex];
            --_activeCount;
        }
        uint64 sequence = _movementSequence++;
        _consumeMove(_currentWindow);
        emit IBuilderRegistry.BuilderGenerationMoved(
            context.retained.builder,
            context.retained.registrationIndex,
            _activeIndex,
            context.liabilityPosition,
            sequence
        );
    }

    /// @dev Replaces the next retained-liability admission leaf.
    function _replaceLiabilityAdmissionRoot(
        uint16 _position,
        bool _priorOccupied,
        SlotChainTypes.RegistryCellV1 memory _priorCell,
        SlotChainTypes.RegistryCellV1 memory _retainedCell,
        bytes calldata _proof
    )
        private
        view
        returns (bytes32 root_)
    {
        return _replaceAdmissionRoot(
            _admissionRoot,
            _position,
            _priorOccupied,
            _priorOccupied ? LibBuilderRegistry.LOCATION_LIABILITY : 0,
            _priorCell,
            true,
            LibBuilderRegistry.LOCATION_LIABILITY,
            _retainedCell,
            _proof
        );
    }

    /// @dev Replaces or clears the former active admission leaf after liability insertion.
    function _replaceActiveAdmissionRoot(
        bytes32 _baseRoot,
        uint8 _activeIndex,
        SlotChainTypes.RegistryCellV1 memory _oldCell,
        bool _hasReplacement,
        SlotChainTypes.RegistryCellV1 memory _replacementCell,
        bytes calldata _proof
    )
        private
        view
        returns (bytes32 root_)
    {
        return _replaceAdmissionRoot(
            _baseRoot,
            _activeIndex,
            true,
            LibBuilderRegistry.LOCATION_ACTIVE,
            _oldCell,
            _hasReplacement,
            _hasReplacement ? LibBuilderRegistry.LOCATION_ACTIVE : 0,
            _replacementCell,
            _proof
        );
    }

    /// @dev Parses and executes one length-prefixed maintenance movement record.
    function _maintenanceMove(
        uint16 _activeIndex,
        uint64 _currentWindow,
        bytes calldata _witness,
        uint256 _offset
    )
        private
        returns (uint256 consumed_)
    {
        if (_offset > _witness.length || _witness.length - _offset < 5) {
            revert InvalidMaintenanceWitness();
        }
        uint32 moveLength = LibBuilderRegistry.readU32(_witness, _offset);
        uint256 start = _offset + 4;
        if (moveLength > _witness.length - start) revert InvalidMaintenanceWitness();
        bytes calldata moveWitness = _witness[start:start + moveLength];
        uint8 closeCount = LibBuilderRegistry.readU8(moveWitness, 0);
        if (
            moveLength
                != LibBuilderRegistry.MOVE_BASE_LENGTH + uint256(closeCount)
                    * LibBuilderRegistry.CLOSE_RECORD_LENGTH
        ) {
            revert InvalidMaintenanceWitness();
        }
        LibBuilderRegistry.Generation memory emptyReplacement;
        _moveActiveToLiability(
            uint8(_activeIndex), emptyReplacement, false, _currentWindow, moveWitness
        );
        return uint256(moveLength) + 4;
    }

    /// @dev Converts exactly the set reservation-mask leaves to LIABILE in ascending-window order.
    function _closeMask(
        LibBuilderRegistry.Generation storage _generation,
        uint32 _mask,
        bytes calldata _witness,
        uint256 _offset
    )
        private
        returns (uint256 offset_)
    {
        uint8 count = LibBuilderRegistry.popcount(_mask);
        if (LibBuilderRegistry.readU8(_witness, 0) != count) revert InvalidCloseRecordCount();
        offset_ = _offset;
        if (count == 0) return offset_;
        uint32 commitMask = _mask;
        bytes memory request =
            abi.encodePacked(_BPR1_MAGIC, uint8(3), _generation.trancheRoot, count);
        uint64 previousWindow;
        bool hasPrevious;
        while (_mask != 0) {
            (uint8 bitOffset, uint32 rest) = LibBuilderRegistry.takeLowest(_mask);
            uint64 window = _generation.reservationBaseWindow + bitOffset;
            if (LibBuilderRegistry.readU64(_witness, offset_) != window) {
                revert InvalidCloseRecordWindow();
            }
            if (hasPrevious && window <= previousWindow) revert InvalidCloseRecordOrder();
            hasPrevious = true;
            previousWindow = window;
            request = _appendCloseRecord(
                request, _generation.registrationIndex, window, _witness, offset_
            );
            offset_ += 296;
            _mask = rest;
        }
        _generation.trancheRoot = _replaceTrancheRoot(request);
        _commitCloseMask(
            _generation.registrationIndex, _generation.reservationBaseWindow, commitMask
        );
    }

    /// @dev Commits exactly the already-verified RESERVED-to-LIABLE state changes.
    function _commitCloseMask(
        uint64 _registrationIndex,
        uint64 _reservationBaseWindow,
        uint32 _mask
    )
        private
    {
        while (_mask != 0) {
            (uint8 bitOffset, uint32 rest) = LibBuilderRegistry.takeLowest(_mask);
            uint64 window = _reservationBaseWindow + bitOffset;
            _tranches[_registrationIndex][uint16(window % 512)].state =
            LibBuilderRegistry.TRANCHE_LIABLE;
            _mask = rest;
        }
    }

    /// @dev Validates and appends one RESERVED-to-LIABLE tranche proof record.
    function _appendCloseRecord(
        bytes memory _request,
        uint64 _registrationIndex,
        uint64 _window,
        bytes calldata _witness,
        uint256 _offset
    )
        private
        view
        returns (bytes memory request_)
    {
        SlotChainTypes.TrancheLeafV1 storage leaf =
            _tranches[_registrationIndex][uint16(_window % 512)];
        if (
            leaf.state != LibBuilderRegistry.TRANCHE_RESERVED || leaf.window != _window
                || leaf.amount != _leasePerWindowAtomic
        ) {
            revert ReservationBitmapMismatch();
        }
        SlotChainTypes.TrancheLeafV1 memory oldLeaf = leaf;
        SlotChainTypes.TrancheLeafV1 memory newLeaf = SlotChainTypes.TrancheLeafV1({
            index: oldLeaf.index,
            window: oldLeaf.window,
            state: LibBuilderRegistry.TRANCHE_LIABLE,
            amount: oldLeaf.amount,
            liableUntil: oldLeaf.liableUntil
        });
        return bytes.concat(
            _request,
            _trancheLeafBytes(oldLeaf),
            _trancheLeafBytes(newLeaf),
            _witness[_offset + 8:_offset + 296]
        );
    }

    /// @dev Applies the exact ordinary normalization grammar and active-root update.
    function _normalizeWithWitness(
        uint8 _activeIndex,
        LibBuilderRegistry.Generation storage _generation,
        uint64 _currentWindow,
        uint32 _staleMaskValue,
        bytes calldata _witness
    )
        private
    {
        uint8 count = LibBuilderRegistry.popcount(_staleMaskValue);
        if (LibBuilderRegistry.readU8(_witness, 0) != count) {
            revert InvalidNormalizationWitness();
        }
        SlotChainTypes.RegistryCellV1 memory oldCell = LibBuilderRegistry.cell(_generation);
        uint256 offset = _closeMask(_generation, _staleMaskValue, _witness, 1);
        _shiftReservationWindow(_generation, _currentWindow);
        _registryRoot = _replaceRegistryRoot(
            _registryRoot,
            _activeIndex,
            true,
            oldCell,
            true,
            LibBuilderRegistry.cell(_generation),
            _witness[offset:offset + 192]
        );
    }

    /// @dev Clears one active generation from both committed trees.
    function _releaseActiveGeneration(
        uint8 _activeIndex,
        LibBuilderRegistry.Generation storage _generation,
        bytes calldata _witness
    )
        private
    {
        SlotChainTypes.RegistryCellV1 memory cell = LibBuilderRegistry.cell(_generation);
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        _registryRoot = _replaceRegistryRoot(
            _registryRoot, _activeIndex, true, cell, false, emptyCell, _witness[:192]
        );
        _admissionRoot = _replaceAdmissionRoot(
            _admissionRoot,
            _activeIndex,
            true,
            LibBuilderRegistry.LOCATION_ACTIVE,
            cell,
            false,
            0,
            emptyCell,
            _witness[192:544]
        );
        delete _active[_activeIndex];
    }

    /// @dev Clears one liability generation from the admission tree.
    function _releaseLiabilityGeneration(
        uint16 _liabilityIndex,
        LibBuilderRegistry.Generation storage _generation,
        bytes calldata _witness
    )
        private
    {
        uint16 position = uint16(64 + _liabilityIndex);
        SlotChainTypes.RegistryCellV1 memory cell = LibBuilderRegistry.cell(_generation);
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        _admissionRoot = _replaceAdmissionRoot(
            _admissionRoot,
            position,
            true,
            LibBuilderRegistry.LOCATION_LIABILITY,
            cell,
            false,
            0,
            emptyCell,
            _witness[:352]
        );
        delete _liabilities[_liabilityIndex];
    }

    /// @dev Releases a safe collision occupant inside the movement transaction.
    function _releaseOverwrittenLiability(
        uint16 _liabilityIndex,
        LibBuilderRegistry.Generation storage _prior
    )
        private
    {
        address builder = _prior.builder;
        uint64 registrationIndex = _prior.registrationIndex;
        uint192 bond = _prior.bond;
        _baseBondEscrow -= bond;
        _credit(builder, bond);
        _markExitResolved(registrationIndex);
        delete _locations[registrationIndex];
        delete _liveIndexPlusOne[builder];
        delete _liabilities[_liabilityIndex];
        emit IBuilderRegistry.BuilderGenerationReleased(builder, registrationIndex, bond);
    }

    /// @dev Returns the caller-selected generation after checking both authoritative indexes.
    function _activeGeneration(
        address _builder,
        uint64 _registrationIndex
    )
        private
        view
        returns (uint8 activeIndex_, LibBuilderRegistry.Generation storage generation_)
    {
        (LibBuilderRegistry.Location memory location, LibBuilderRegistry.Generation storage found) =
            _locatedGeneration(_builder, _registrationIndex);
        if (location.kind != LibBuilderRegistry.LOCATION_ACTIVE) revert BuilderNotActive();
        return (uint8(location.index), found);
    }

    /// @dev Returns one retained generation after exact-checking both reverse locators.
    function _locatedGeneration(
        address _builder,
        uint64 _registrationIndex
    )
        private
        view
        returns (
            LibBuilderRegistry.Location memory location_,
            LibBuilderRegistry.Generation storage generation_
        )
    {
        if (
            _builder == address(0) || _liveIndexPlusOne[_builder] != uint256(_registrationIndex) + 1
        ) {
            revert BuilderGenerationNotFound();
        }
        location_ = _locations[_registrationIndex];
        generation_ = location_.kind == LibBuilderRegistry.LOCATION_ACTIVE
            ? _active[location_.index]
            : _liabilities[location_.index];
        if (
            (location_.kind != LibBuilderRegistry.LOCATION_ACTIVE
                    && location_.kind != LibBuilderRegistry.LOCATION_LIABILITY)
                || generation_.builder != _builder
                || generation_.registrationIndex != _registrationIndex
        ) {
            revert BuilderLocatorMismatch();
        }
    }

    /// @dev Exact-checks a locator whose builder address was not supplied by the caller.
    function _requireLocatedGeneration(
        uint64 _registrationIndex,
        LibBuilderRegistry.Location memory _location
    )
        private
        view
    {
        LibBuilderRegistry.Generation storage generation = _location.kind
            == LibBuilderRegistry.LOCATION_ACTIVE
            ? _active[_location.index]
            : _liabilities[_location.index];
        if (
            generation.builder == address(0) || generation.registrationIndex != _registrationIndex
                || _liveIndexPlusOne[generation.builder] != uint256(_registrationIndex) + 1
        ) {
            revert BuilderLocatorMismatch();
        }
    }

    /// @dev Selects the lowest vacancy, otherwise the deterministic live minimum-bond victim.
    function _selectVacancyOrVictim(uint192 _newBond)
        private
        view
        returns (bool vacancy_, uint8 index_)
    {
        if (_activeCount < 64) {
            for (uint8 i; i < 64; ++i) {
                if (_active[i].builder == address(0)) return (true, i);
            }
            revert ActiveCountMismatch();
        }
        uint192 minimumBond = type(uint192).max;
        uint64 greatestRegistration;
        bool found;
        for (uint8 i; i < 64; ++i) {
            LibBuilderRegistry.Generation storage generation = _active[i];
            if (generation.builder == address(0)) revert ActiveCountMismatch();
            if (
                generation.tombstonedAtL2Slot == _LIVE_TOMBSTONE
                    && (!found
                        || generation.bond < minimumBond
                        || (generation.bond == minimumBond
                            && generation.registrationIndex > greatestRegistration))
            ) {
                found = true;
                index_ = i;
                minimumBond = generation.bond;
                greatestRegistration = generation.registrationIndex;
            }
        }
        if (!found || _newBond <= minimumBond) revert InsufficientReplacementBond();
    }

    /// @dev Applies bounded queue/tombstone and movement-budget checks before replacement.
    function _requireReplacementReady(uint64 _currentWindow) private {
        if (_remainingMoves(_currentWindow) == 0) revert MovementBudgetExhausted();
        uint8 inspected;
        while (_exitHeadSequence < _nextExitSequence && inspected < 64) {
            LibBuilderRegistry.ExitRequest storage request = _exitRequests[_exitHeadSequence];
            ++inspected;
            LibBuilderRegistry.Location memory location = _locations[request.registrationIndex];
            if (request.resolved || location.kind != LibBuilderRegistry.LOCATION_ACTIVE) {
                request.resolved = true;
                ++_exitHeadSequence;
                continue;
            }
            _requireLocatedGeneration(request.registrationIndex, location);
            if (request.matureWindow <= _currentWindow) revert MaintenanceRequired();
            break;
        }
        if (inspected == 64 && _exitHeadSequence < _nextExitSequence) {
            revert MaintenanceRequired();
        }
        for (uint8 i; i < 64; ++i) {
            if (
                _active[i].builder != address(0) && _active[i].tombstonedAtL2Slot != _LIVE_TOMBSTONE
            ) {
                revert MaintenanceRequired();
            }
        }
    }

    /// @dev Selects the oldest active tombstone by (slot, registration index).
    function _selectTombstone() private view returns (bool found_, uint8 index_) {
        uint64 earliest = type(uint64).max;
        uint64 registration = type(uint64).max;
        for (uint8 i; i < 64; ++i) {
            LibBuilderRegistry.Generation storage generation = _active[i];
            if (
                generation.builder != address(0) && generation.tombstonedAtL2Slot != _LIVE_TOMBSTONE
                    && (!found_
                        || generation.tombstonedAtL2Slot < earliest
                        || (generation.tombstonedAtL2Slot == earliest
                            && generation.registrationIndex < registration))
            ) {
                found_ = true;
                index_ = i;
                earliest = generation.tombstonedAtL2Slot;
                registration = generation.registrationIndex;
            }
        }
    }

    /// @dev Returns whether the current FIFO head is a live matured active exit.
    function _hasMatureHead(uint64 _currentWindow) private view returns (bool pending_) {
        if (_exitHeadSequence >= _nextExitSequence) return false;
        LibBuilderRegistry.ExitRequest storage request = _exitRequests[_exitHeadSequence];
        if (request.resolved) return false;
        LibBuilderRegistry.Location memory location = _locations[request.registrationIndex];
        return location.kind == LibBuilderRegistry.LOCATION_ACTIVE
            && request.matureWindow <= _currentWindow;
    }

    /// @dev Requires the ring occupant to satisfy every ordinary generation-release predicate.
    function _requireLiabilityReusable(
        LibBuilderRegistry.Generation storage _generation,
        uint64 _currentWindow
    )
        private
        view
    {
        if (
            _generation.unreleasedTrancheCount != 0
                || block.timestamp <= _generation.maximumLiableUntil
                || _currentWindow < _generation.releaseWindow
        ) {
            revert LiabilityRingBlocked();
        }
    }

    /// @dev Returns the exact complete stale mask for an ordinary current window.
    function _staleMask(
        LibBuilderRegistry.Generation storage _generation,
        uint64 _currentWindow
    )
        private
        view
        returns (uint32 mask_)
    {
        if (_currentWindow < _generation.reservationBaseWindow) {
            revert ReservationBaseMovedBackward();
        }
        uint64 shift = _currentWindow - _generation.reservationBaseWindow;
        return shift > 16
            ? _generation.reservationBitmap
            : _generation.reservationBitmap & ((uint32(1) << uint8(shift)) - 1);
    }

    /// @dev Slides one active generation's canonical 17-bit reservation window.
    function _shiftReservationWindow(
        LibBuilderRegistry.Generation storage _generation,
        uint64 _currentWindow
    )
        private
    {
        if (_currentWindow < _generation.reservationBaseWindow) {
            revert ReservationBaseMovedBackward();
        }
        uint64 shift = _currentWindow - _generation.reservationBaseWindow;
        _generation.reservationBitmap =
            shift > 16 ? 0 : _generation.reservationBitmap >> uint8(shift);
        _generation.reservationBaseWindow = _currentWindow;
    }

    /// @dev Requires that one idempotent reservation agrees with the bitmap index.
    function _requireReservationIndexed(
        LibBuilderRegistry.Generation storage _generation,
        uint64 _window
    )
        private
        view
    {
        if (_window < _generation.reservationBaseWindow) revert ReservationBitmapMismatch();
        uint64 offset = _window - _generation.reservationBaseWindow;
        if (offset > 16 || _generation.reservationBitmap & (uint32(1) << uint8(offset)) == 0) {
            revert ReservationBitmapMismatch();
        }
    }

    /// @dev Returns a retained leaf or the position-bound canonical EMPTY preimage.
    function _storedTranche(
        uint64 _registrationIndex,
        uint16 _index
    )
        private
        view
        returns (SlotChainTypes.TrancheLeafV1 memory leaf_)
    {
        leaf_ = _tranches[_registrationIndex][_index];
        if (leaf_.state == LibBuilderRegistry.TRANCHE_EMPTY) {
            return LibBuilderRegistry.emptyTranche(_index);
        }
        if (leaf_.index != _index) revert TrancheStorageMismatch();
    }

    /// @dev Derives the inclusive evidence replay deadline for one managed window.
    function _trancheDeadline(uint64 _window) private view returns (uint64 deadline_) {
        uint256 deadline = uint256(_genesisTimestamp) + 384 * (uint256(_window) + 1)
            + _evidenceDelaySeconds + _reorgMarginSeconds;
        if (deadline > type(uint64).max) revert TrancheDeadlineOverflow();
        return uint64(deadline);
    }

    /// @dev Requires the pinned Settlement's exact SST1 view to report a nonzero mode: a new
    ///      reservation is refused while the Settlement is DRAINING (mode 0).
    function _requireSettlementOpen() private view {
        (, uint8 mode) = _readSettlementState();
        if (mode == 0) revert SettlementDraining();
    }

    /// @dev Exact-reads the 128-byte `settlementStateV1()` (SST1) view of the constructor-pinned
    ///      Settlement, the Inbox proxy held in the retained `_activeSettlementRouter` slot,
    ///      with a zero-value 50,000-gas STATICCALL. The proxy's runtime is deliberately not
    ///      pinned; the magic, the mode range and canonical narrow-word padding are required.
    function _readSettlementState() private view returns (uint64 protocolVersion_, uint8 mode_) {
        bytes memory state = LibExactCall.staticcallExactUnpinned(
            _activeSettlementRouter, abi.encodePacked(_SST1_SELECTOR), _EXTERNAL_READ_GAS, 128, 0
        );
        protocolVersion_ = LibExactCall.u64Word(state, 1);
        mode_ = LibExactCall.u8Word(state, 2);
        LibExactCall.u64Word(state, 3);
        if (LibExactCall.bytes4Word(state, 0) != _SST1_MAGIC || mode_ > 2) {
            revert SettlementStateMalformed();
        }
    }

    /// @dev Requires one exact Schedule EXPIRED row, optionally with the terminal cursor. The
    ///      ScheduleOracle proxy is pinned by address only.
    function _requireExpiredSchedule(uint64 _window, bool _terminal) private view {
        bytes memory state = LibExactCall.staticcallExactUnpinned(
            _scheduleOracle, abi.encodeWithSelector(_SWR1_SELECTOR, _window), 50_000, 160, 0
        );
        uint64 cursor = LibExactCall.u64Word(state, 3);
        bool cursorValid = cursor == _TERMINAL_CURSOR
            || (cursor >= _firstManagedWindow && cursor <= _lastManagedWindow);
        if (
            LibExactCall.bytes4Word(state, 0) != _SWR1_MAGIC
                || LibExactCall.u64Word(state, 1) != _window || LibExactCall.u8Word(state, 2) != 3
                || LibExactCall.word(state, 4) != bytes32(0) || !cursorValid || _window >= cursor
                || (_terminal && cursor != _TERMINAL_CURSOR)
        ) {
            revert ScheduleWindowNotExpired();
        }
    }

    /// @dev Requires the exact terminal Schedule sentinel at the final managed window.
    function _requireTerminalSchedule() private view {
        _requireExpiredSchedule(_lastManagedWindow, true);
    }

    /// @dev Reads one exact builder-token balance after authenticating its runtime.
    function _builderTokenBalance(address _account) private view returns (uint256 balance_) {
        bytes memory output = LibExactCall.staticcallExact(
            _builderLeaseToken,
            _builderLeaseTokenRuntimeHash,
            abi.encodeWithSelector(_BALANCE_OF_SELECTOR, _account),
            50_000,
            32,
            0
        );
        return uint256(LibExactCall.word(output, 0));
    }

    /// @dev Pulls an exact nominal amount after state/accounting have been committed locally.
    function _pullBuilderToken(address _from, uint256 _amount, uint256 _balanceBefore) private {
        _callOptionalTrue(
            abi.encodeWithSelector(_TRANSFER_FROM_SELECTOR, _from, address(this), _amount)
        );
        uint256 balanceAfter = _builderTokenBalance(address(this));
        if (
            _balanceBefore > type(uint256).max - _amount || balanceAfter != _balanceBefore + _amount
        ) {
            revert BuilderTokenIncomingDeltaMismatch();
        }
        _assertSolventAt(balanceAfter);
    }

    /// @dev Sends an exact nominal amount and checks both Registry and recipient balance deltas.
    function _transferBuilderToken(
        address _recipient,
        uint256 _amount,
        uint256 _registryBalanceBefore,
        uint256 _recipientBalanceBefore
    )
        private
    {
        _callOptionalTrue(abi.encodeWithSelector(_TRANSFER_SELECTOR, _recipient, _amount));
        uint256 registryBalanceAfter = _builderTokenBalance(address(this));
        uint256 recipientBalanceAfter = _builderTokenBalance(_recipient);
        if (
            _registryBalanceBefore < _amount
                || registryBalanceAfter != _registryBalanceBefore - _amount
                || recipientBalanceAfter != _recipientBalanceBefore + _amount
        ) {
            revert BuilderTokenOutgoingDeltaMismatch();
        }
        _assertSolventAt(registryBalanceAfter);
    }

    /// @dev Executes transfer/transferFrom without copying unbounded returndata.
    function _callOptionalTrue(bytes memory _input) private {
        LibExactCall.requireRuntime(_builderLeaseToken, _builderLeaseTokenRuntimeHash);
        bool success;
        uint256 size;
        bytes32 result;
        address token = _builderLeaseToken;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(_input, 32), mload(_input), 0, 0)
            size := returndatasize()
            if and(success, eq(size, 32)) {
                returndatacopy(0, 0, 32)
                result := mload(0)
            }
        }
        if (!success || (size != 0 && (size != 32 || result != bytes32(uint256(1))))) {
            revert BuilderTokenTransferFailed();
        }
    }

    /// @dev Adds one nonzero beneficiary pull credit and its authoritative aggregate.
    function _credit(address _beneficiary, uint256 _amount) private {
        if (_beneficiary == address(0)) revert InvalidCreditBeneficiary();
        if (_amount == 0) return;
        _credits[_beneficiary] += _amount;
        _totalCredits += _amount;
    }

    /// @dev Requires current exact-balance custody to cover all authoritative accounting.
    function _assertSolvent() private view {
        _assertSolventAt(_builderTokenBalance(address(this)));
    }

    /// @dev Requires one already authenticated balance to cover all authoritative accounting.
    function _assertSolventAt(uint256 _balance) private view {
        if (_balance < _baseBondEscrow + _trancheEscrow + _totalCredits) {
            revert BuilderTokenInsolvent();
        }
    }

    /// @dev Creates or advances the window-scoped movement counter.
    function _consumeMove(uint64 _currentWindow) private {
        if (_moveCounterWindow != _currentWindow) {
            _moveCounterWindow = _currentWindow;
            _movesInCounterWindow = 0;
        }
        if (_movesInCounterWindow >= 4) revert MovementBudgetExhausted();
        ++_movesInCounterWindow;
    }

    /// @dev Returns the remaining movement budget in one current window.
    function _remainingMoves(uint64 _currentWindow) private view returns (uint8 remaining_) {
        if (_moveCounterWindow != _currentWindow) return 4;
        return 4 - _movesInCounterWindow;
    }

    /// @dev Marks an existing one-shot exit row resolved without scanning the FIFO.
    function _markExitResolved(uint64 _registrationIndex) private {
        uint256 sequencePlusOne = _exitByRegistration[_registrationIndex];
        if (sequencePlusOne != 0) {
            _exitRequests[uint64(sequencePlusOne - 1)].resolved = true;
        }
    }

    /// @dev Checked per-call registry version increment.
    function _incrementRegistryVersion() private {
        if (_registryMutationVersion == type(uint64).max) revert RegistryVersionExhausted();
        ++_registryMutationVersion;
    }

    /// @dev Checked per-call admission version increment.
    function _incrementAdmissionVersion() private {
        if (_admissionVersion == type(uint64).max) revert AdmissionVersionExhausted();
        ++_admissionVersion;
    }

    /// @dev Writes the exact BRH1 word and raw registry root beside their ordinary mirrors.
    function _syncHistoricalSlots() private {
        bool exhausted = _nextRegistrationIndex > type(uint64).max;
        uint64 low = exhausted ? 0 : uint64(_nextRegistrationIndex);
        uint256 header = uint256(uint32(0x42524831)) << 224 | uint256(1) << 216
            | uint256(_activeCount) << 208 | uint256(exhausted ? 1 : 0) << 200
            | uint256(_registryMutationVersion) << 128 | uint256(_admissionVersion) << 64 | low;
        bytes32 registryRoot = _registryRoot;
        bytes32 headerSlot = _HEADER_SLOT;
        bytes32 rootSlot = _ROOT_SLOT;
        assembly ("memory-safe") {
            sstore(headerSlot, header)
            sstore(rootSlot, registryRoot)
        }
    }

    /// @dev Stores one complete ABI word in an already allocated exact return buffer.
    function _storeWord(bytes memory _output, uint256 _index, bytes32 _value) private pure {
        assembly ("memory-safe") {
            mstore(add(add(_output, 32), mul(_index, 32)), _value)
        }
    }

    /// @dev Loads one exact packed address from a bounded calldata region.
    function _readPackedAddress(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (address value_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < 20) {
            revert InvalidEquivocationEvidence();
        }
        assembly ("memory-safe") {
            value_ := shr(96, calldataload(add(_encoded.offset, _offset)))
        }
    }

    /// @dev Returns the nonnegative timestamp-derived L2 slot without narrowing it.
    function _currentL2Slot() private view returns (uint256 slot_) {
        return block.timestamp > _genesisTimestamp ? block.timestamp - _genesisTimestamp : 0;
    }

    /// @dev Derives the protocol's exact final managed schedule window.
    function _deriveLastManagedWindow(
        uint64 _genesis,
        uint64 _evidence,
        uint64 _reorg
    )
        private
        pure
        returns (uint64 last_)
    {
        uint256 fixedBound = _LAST_FULL_SLOT_WINDOW;
        uint256 subtrahend = uint256(_genesis) + _evidence + _reorg;
        if (subtrahend > type(uint64).max - 1) revert InvalidManagedWindowRange();
        uint256 quotient = (type(uint64).max - 1 - subtrahend) / 384;
        if (quotient == 0) revert InvalidManagedWindowRange();
        uint256 deadlineBound = quotient - 1;
        return uint64(fixedBound < deadlineBound ? fixedBound : deadlineBound);
    }

    /// @dev Enforces the sole ABI offset, length and zero-padding encoding for one bytes tail.
    function _requireCanonicalDynamicCalldata(
        bytes calldata _tail,
        uint256 _headWords
    )
        private
        pure
    {
        uint256 encodedOffset;
        uint256 encodedLength;
        uint256 tailOffset;
        uint256 offsetWordPosition = 4 + 32 * (_headWords - 1);
        assembly ("memory-safe") {
            encodedOffset := calldataload(offsetWordPosition)
            encodedLength := calldataload(add(4, encodedOffset))
            tailOffset := _tail.offset
        }
        uint256 expectedOffset = 32 * _headWords;
        uint256 expectedTailOffset = 36 + expectedOffset;
        uint256 paddedLength = (_tail.length + 31) & ~uint256(31);
        if (
            encodedOffset != expectedOffset || encodedLength != _tail.length
                || tailOffset != expectedTailOffset
                || msg.data.length != expectedTailOffset + paddedLength
        ) {
            revert NonCanonicalCalldata();
        }
        for (uint256 i = expectedTailOffset + _tail.length; i < msg.data.length; ++i) {
            if (msg.data[i] != 0) revert NonCanonicalCalldata();
        }
    }

    /// @dev Restricts every functional surface to a Registry that its activator has activated.
    modifier onlyActivatedRegistry() {
        if (_protocolRootActivationState != 1) revert RegistryInactive();
        _;
    }

    /// @dev Rejects direct facet calls and delegation from any uninitialized foreign storage.
    modifier onlyRegistryContext() {
        if (_registrySelf == address(0) || _registrySelf != address(this)) {
            revert InvalidRegistryExecutionContext();
        }
        _;
    }

    /// @dev Prevents any nested Registry mutation across core and lifecycle-facet boundaries.
    modifier operationNonReentrant() {
        if (_operationLock != 0) revert RegistryOperationReentry();
        _operationLock = 1;
        _;
        _operationLock = 0;
    }

    /// @dev Prevents every builder-token callback from entering another token-moving path.
    modifier tokenNonReentrant() {
        if (_tokenLock != 0) revert BuilderTokenReentry();
        _tokenLock = 1;
        _;
        _tokenLock = 0;
    }

    error ActiveCountMismatch();
    error ActiveIndexRace();
    error AdmissionVersionExhausted();
    error BuilderEntryBeyondManagedRange();
    error BuilderGenerationNotFound();
    error BuilderGenerationNotReleasable();
    error BuilderLocatorMismatch();
    error BuilderNotActive();
    error BuilderTokenBalanceOverflow();
    error BuilderTokenDecimalsMismatch();
    error BuilderTokenIncomingDeltaMismatch();
    error BuilderTokenInsolvent();
    error BuilderTokenOutgoingDeltaMismatch();
    error BuilderTokenReentry();
    error BuilderTokenTransferFailed();
    error BuilderTrancheNotReleasable();
    error CurrentAdmissionProofMismatch();
    error EmptyBuilderCredit();
    error EvidenceTrancheNotSlashable();
    error ExitMaturityOverflow();
    error InsufficientReplacementBond();
    error InvalidBuilderCreditRecipient();
    error InvalidBuilderExit();
    error InvalidBuilderRegistration();
    error InvalidBuilderRegistryConfiguration();
    error InvalidBuilderProofVerifier();
    error InvalidBuilderProofRequest();
    error InvalidBuilderProofResult();
    error InvalidBuilderEvidenceIdentity();
    error InvalidBuilderReservation();
    error InvalidCloseRecordCount();
    error InvalidCloseRecordOrder();
    error InvalidCloseRecordWindow();
    error InvalidCreditBeneficiary();
    error InvalidEquivocationEvidence();
    error InvalidEvidenceDomain();
    error InvalidEvidenceWindow();
    error InvalidGenerationReleaseWitness();
    error InvalidHistoricalAdmissionPosition();
    error InvalidLiabilityResidence();
    error InvalidMaintenanceLimit();
    error InvalidMaintenanceWitness();
    error InvalidManagedWindowRange();
    error InvalidMovementWitness();
    error InvalidNormalizationWitness();
    error InvalidReservationBitmap();
    error InvalidReservationWitness();
    error InvalidRewardClassConfiguration();
    error InvalidRegistryExecutionContext();
    error InvalidRewardClass();
    error InvalidTrancheReleaseWitness();
    error InvalidVacantRegistrationWitness();
    error L2SlotOutOfRange();
    error LiabilityReleaseWindowOverflow();
    error LiabilityRingBlocked();
    error MaintenanceRequired();
    error MovementBudgetExhausted();
    error MovementSequenceExhausted();
    error NonCanonicalCalldata();
    error NonCanonicalLiabilityRegistryProof();
    error RegistryInactive();
    error RegistryVersionExhausted();
    error RegistryOperationReentry();
    error ReservationBaseMovedBackward();
    error ReservationBitmapMismatch();
    error ScheduleWindowNotExpired();
    error SettlementDraining();
    error SettlementStateMalformed();
    error TrancheDeadlineOverflow();
    error TrancheRingCollision();
    error TrancheStorageMismatch();
    error HistoricalAdmissionProofMismatch();
}

/// @title Permissionless Slot Chain builder registry
/// @notice Owns all Registry state and custody while dispatching lifecycle operations to two
///         immutable, codehash-pinned execution facets. Every functional surface stays closed
///         until the constructor-pinned activator activates the Registry exactly once.
/// @custom:security-contact security@taiko.xyz
contract BuilderRegistry is BuilderRegistryLogicV1 {
    bytes4 private constant _COMPONENT_CONFIG_SELECTOR = 0xf6c0f7d2;
    bytes32 private constant _SEAT_FACET_CONFIGURATION_HASH =
        0x5844c0d5e26f8e8006907c41fcf7c121537202827fa671a15099730c1dd38d6b;
    bytes32 private constant _LEASE_FACET_CONFIGURATION_HASH =
        0x768f741248a8cd1b1fc84f9134261736305ad3d373ac5a5b346057a7c1b9680a;
    bytes32 private constant _SEAT_FACET_SELECTOR_SET_HASH =
        0x92e9dd5f246684dbc6137c40eb276993130005222bc31be614359dbc1164bbf5;
    bytes32 private constant _LEASE_FACET_SELECTOR_SET_HASH =
        0x895e8723291f0a1f397a981815290e003eab16a87807eadc3b3bc0d805b8fb78;
    uint256 private constant _MAXIMUM_FACET_RETURNDATA = 224;
    bytes4 private constant _BRK1_MAGIC = 0x42524b31;
    bytes4 private constant _BRA1_MAGIC = 0x42524131;
    uint8 private constant _ACTIVATION_INACTIVE = 0;
    uint8 private constant _ACTIVATION_ACTIVE = 1;

    address private immutable _seatLifecycleFacet;
    bytes32 private immutable _seatLifecycleFacetRuntimeHash;
    address private immutable _leaseLifecycleFacet;
    bytes32 private immutable _leaseLifecycleFacetRuntimeHash;

    /// @notice Pins the activator and initializes the frozen facet graph and Registry
    ///         configuration. The Registry stays inactive until `activateRegistryV1()`.
    /// @dev The complete constructor encoding is the activator word followed by the 43 static
    ///      words of `BuilderRegistryConstructorV1`: 44 words, 1,408 bytes, no dynamic offset.
    /// @param _registryActivator The sole account allowed to activate this Registry, such as the
    ///                           DAO controller or a deployment script.
    /// @param _config The exact static Registry configuration.
    constructor(
        address _registryActivator,
        IBuilderRegistry.BuilderRegistryConstructorV1 memory _config
    ) {
        if (_registryActivator == address(0)) revert InvalidRegistryActivator();
        _activator = _registryActivator;
        _l2ChainId = _config.l2ChainId;
        if (
            _config.seatLifecycleFacet == address(0)
                || _config.seatLifecycleFacetRuntimeHash == bytes32(0)
                || _config.leaseLifecycleFacet == address(0)
                || _config.leaseLifecycleFacetRuntimeHash == bytes32(0)
                || _config.seatLifecycleFacet == _config.leaseLifecycleFacet
                || _config.seatLifecycleFacet == address(this)
                || _config.leaseLifecycleFacet == address(this)
                || _config.builderProofVerifier == address(this)
                || _config.seatLifecycleFacet == _config.builderProofVerifier
                || _config.leaseLifecycleFacet == _config.builderProofVerifier
                || _config.seatLifecycleFacetConfigurationHash != _SEAT_FACET_CONFIGURATION_HASH
                || _config.leaseLifecycleFacetConfigurationHash != _LEASE_FACET_CONFIGURATION_HASH
        ) {
            revert InvalidLifecycleFacetConfiguration();
        }
        _seatLifecycleFacet = _config.seatLifecycleFacet;
        _seatLifecycleFacetRuntimeHash = _config.seatLifecycleFacetRuntimeHash;
        _leaseLifecycleFacet = _config.leaseLifecycleFacet;
        _leaseLifecycleFacetRuntimeHash = _config.leaseLifecycleFacetRuntimeHash;
        _requireLifecycleFacet(
            _seatLifecycleFacet,
            _seatLifecycleFacetRuntimeHash,
            1,
            _SEAT_FACET_SELECTOR_SET_HASH,
            _SEAT_FACET_CONFIGURATION_HASH
        );
        _requireLifecycleFacet(
            _leaseLifecycleFacet,
            _leaseLifecycleFacetRuntimeHash,
            2,
            _LEASE_FACET_SELECTOR_SET_HASH,
            _LEASE_FACET_CONFIGURATION_HASH
        );
        _initializeRegistry(_config);
    }

    /// @notice Permanently activates every functional Registry surface.
    /// @dev Callable exactly once, only by the constructor-pinned activator and only in Registry
    ///      context. Activation changes the single activation word, makes no external call,
    ///      emits no event and returns exactly one padded `BRK1` word (32 bytes).
    /// @return magic_ The fixed `BRK1` magic.
    function activateRegistryV1() external onlyRegistryContext returns (bytes4 magic_) {
        if (msg.sender != _activator) revert UnauthorizedRegistryActivator();
        if (_protocolRootActivationState != _ACTIVATION_INACTIVE) {
            revert RegistryAlreadyActivated();
        }
        if (_builderPenaltySink == address(this)) revert InvalidBuilderRegistryConfiguration();
        _protocolRootActivationState = _ACTIVATION_ACTIVE;
        return _BRK1_MAGIC;
    }

    /// @notice Returns the constructor-pinned activator and the activation state.
    /// @dev Readable before activation; the exact `BRA1` return is 96 bytes.
    /// @return magic_ The fixed `BRA1` magic.
    /// @return activator_ The sole account allowed to activate this Registry.
    /// @return state_ `0` (INACTIVE) until `activateRegistryV1()` succeeds, then `1` (ACTIVE).
    function registryActivationV1()
        external
        view
        returns (bytes4 magic_, address activator_, uint8 state_)
    {
        return (_BRA1_MAGIC, _activator, _protocolRootActivationState);
    }

    /// @dev Overrides the seat admission entry and delegates its unchanged calldata.
    function registerBuilderV1(
        uint192,
        uint64,
        uint8,
        bytes calldata
    )
        external
        override
        onlyActivatedRegistry
        returns (bytes4, uint64, uint8, uint64, uint64, bytes32)
    {
        _delegateAndReturn(_seatLifecycleFacet, _seatLifecycleFacetRuntimeHash);
    }

    /// @dev Overrides the lease reservation entry and delegates its unchanged calldata.
    function reserveBuilderWindowV1(
        uint64,
        uint64,
        bytes calldata
    )
        external
        override
        onlyActivatedRegistry
        returns (bytes4, uint64, uint64, uint64, bytes32)
    {
        _delegateAndReturn(_leaseLifecycleFacet, _leaseLifecycleFacetRuntimeHash);
    }

    /// @dev Overrides the exit request entry and delegates its unchanged calldata.
    function requestBuilderExitV1(uint64)
        external
        override
        onlyActivatedRegistry
        returns (bytes4, uint64, uint64, uint8)
    {
        _delegateAndReturn(_seatLifecycleFacet, _seatLifecycleFacetRuntimeHash);
    }

    /// @dev Overrides the maintenance entry and delegates its unchanged calldata.
    function processBuilderMaintenanceV1(
        uint8,
        bytes calldata
    )
        external
        override
        onlyActivatedRegistry
        returns (bytes4, uint8, uint8, uint64, bytes32)
    {
        _delegateAndReturn(_seatLifecycleFacet, _seatLifecycleFacetRuntimeHash);
    }

    /// @dev Overrides the normalization entry and delegates its unchanged calldata.
    function normalizeBuilderTranchesV1(
        address,
        uint64,
        bytes calldata
    )
        external
        override
        onlyActivatedRegistry
        returns (bytes4, uint64, uint8, uint64, bytes32)
    {
        _delegateAndReturn(_leaseLifecycleFacet, _leaseLifecycleFacetRuntimeHash);
    }

    /// @dev Overrides the tranche release entry and delegates its unchanged calldata.
    function releaseBuilderTrancheV1(
        address,
        uint64,
        uint64,
        bytes calldata
    )
        external
        override
        onlyActivatedRegistry
        returns (bytes4, uint64, uint64, address, uint256, uint64, bytes32)
    {
        _delegateAndReturn(_leaseLifecycleFacet, _leaseLifecycleFacetRuntimeHash);
    }

    /// @dev Overrides the generation release entry and delegates its unchanged calldata.
    function releaseBuilderGenerationV1(
        address,
        uint64,
        bytes calldata
    )
        external
        override
        onlyActivatedRegistry
        returns (bytes4, uint64, address, uint256, uint64, bytes32)
    {
        _delegateAndReturn(_leaseLifecycleFacet, _leaseLifecycleFacetRuntimeHash);
    }

    /// @dev Authenticates one generic lifecycle facet before construction can finish.
    function _requireLifecycleFacet(
        address _facet,
        bytes32 _expectedRuntimeHash,
        uint8 _expectedKind,
        bytes32 _expectedSelectorSetHash,
        bytes32 _configurationHash
    )
        private
        view
    {
        bytes memory facetConfig = LibExactCall.staticcallExact(
            _facet, _expectedRuntimeHash, abi.encodePacked(_BRF1_SELECTOR), 100_000, 192, 0
        );
        if (
            LibExactCall.bytes4Word(facetConfig, 0) != _BRF1_MAGIC
                || LibExactCall.u8Word(facetConfig, 1) != 1
                || LibExactCall.u8Word(facetConfig, 2) != _expectedKind
                || LibExactCall.word(facetConfig, 3) != _BUILDER_REGISTRY_STORAGE_LAYOUT_HASH
                || LibExactCall.word(facetConfig, 4) != _expectedSelectorSetHash
                || LibExactCall.word(facetConfig, 5) != _configurationHash
        ) {
            revert InvalidLifecycleFacetConfiguration();
        }
        LibExactCall.requireConfiguration(
            _facet, _expectedRuntimeHash, _COMPONENT_CONFIG_SELECTOR, _configurationHash, 50_000, 0
        );
    }

    /// @dev Exact-codehash-checks and delegates original calldata under the global operation lock.
    function _delegateAndReturn(address _facet, bytes32 _expectedRuntimeHash) private {
        if (_operationLock != 0) revert RegistryOperationReentry();
        if (_runtimeHash(_facet) != _expectedRuntimeHash) revert LifecycleFacetCodeChanged();
        _operationLock = 1;
        bool success;
        uint256 returnSize;
        assembly ("memory-safe") {
            let inputPtr := mload(0x40)
            calldatacopy(inputPtr, 0, calldatasize())
            success := delegatecall(gas(), _facet, inputPtr, calldatasize(), 0, 0)
            returnSize := returndatasize()
        }
        _operationLock = 0;
        if (returnSize > _MAXIMUM_FACET_RETURNDATA) {
            revert LifecycleFacetReturnDataTooLarge();
        }
        assembly ("memory-safe") {
            let outputPtr := mload(0x40)
            returndatacopy(outputPtr, 0, returnSize)
            if iszero(success) { revert(outputPtr, returnSize) }
            return(outputPtr, returnSize)
        }
    }

    /// @dev Returns EXTCODEHASH while rejecting code-empty accounts.
    function _runtimeHash(address _target) private view returns (bytes32 hash_) {
        uint256 codeSize;
        assembly ("memory-safe") {
            hash_ := extcodehash(_target)
            codeSize := extcodesize(_target)
        }
        if (codeSize == 0) return bytes32(0);
    }

    error InvalidLifecycleFacetConfiguration();
    error InvalidRegistryActivator();
    error LifecycleFacetCodeChanged();
    error LifecycleFacetReturnDataTooLarge();
    error RegistryAlreadyActivated();
    error UnauthorizedRegistryActivator();
}
