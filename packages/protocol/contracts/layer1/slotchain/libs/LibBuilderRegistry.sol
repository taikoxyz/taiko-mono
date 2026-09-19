// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../shared/slotchain/SlotChainTypes.sol";
import { LibSlotChainEncoding } from "../../../shared/slotchain/libs/LibSlotChainEncoding.sol";
import { IBuilderRegistry } from "../iface/IBuilderRegistry.sol";

/// @title Builder registry bounded codecs and state primitives
/// @custom:security-contact security@taiko.xyz
library LibBuilderRegistry {
    uint8 internal constant LOCATION_NONE = 0;
    uint8 internal constant LOCATION_ACTIVE = 1;
    uint8 internal constant LOCATION_LIABILITY = 2;

    uint8 internal constant TRANCHE_EMPTY = 0;
    uint8 internal constant TRANCHE_FREE = 1;
    uint8 internal constant TRANCHE_RESERVED = 2;
    uint8 internal constant TRANCHE_LIABLE = 3;
    uint8 internal constant TRANCHE_RELEASED = 4;
    uint8 internal constant TRANCHE_SLASHED = 5;

    uint16 internal constant ACTIVE_COUNT = 64;
    uint16 internal constant MAX_ASSIGNED_SLOTS = 76;
    uint16 internal constant ENTRY_DELAY_WINDOWS = 8;
    uint16 internal constant EXIT_DELAY_WINDOWS = 268;
    uint16 internal constant MAX_LIVE_WINDOWS = EXIT_DELAY_WINDOWS;
    uint16 internal constant MAX_TRANCHE_AHEAD_WINDOWS = 16;
    uint16 internal constant LIABILITY_COUNT = 1072;
    uint8 internal constant MAX_MOVES_PER_WINDOW = 4;

    uint256 internal constant TRANCHE_PATH_LENGTH = 288;
    uint256 internal constant REGISTRY_PATH_LENGTH = 192;
    uint256 internal constant ADMISSION_PATH_LENGTH = 352;
    uint256 internal constant CLOSE_RECORD_LENGTH = 296;
    uint256 internal constant MOVE_BASE_LENGTH = 897;

    struct Generation {
        address builder;
        uint192 bond;
        uint64 registrationIndex;
        uint64 effectiveL2Slot;
        bytes32 trancheRoot;
        uint64 tombstonedAtL2Slot;
        uint64 reservationBaseWindow;
        uint32 reservationBitmap;
        uint16 unreleasedTrancheCount;
        uint64 maximumLiableUntil;
        uint64 maxReservedWindow;
        uint64 releaseWindow;
        uint64 exitSequence;
        bool reservationsClosed;
        bool hasExit;
    }

    struct Location {
        uint8 kind;
        uint16 index;
    }

    struct ExitRequest {
        uint64 registrationIndex;
        uint64 requestWindow;
        uint64 matureWindow;
        bool resolved;
    }

    struct EconomicConfig {
        uint256 settlementChainId;
        address builderLeaseToken;
        bytes32 builderLeaseTokenRuntimeHash;
        uint8 builderLeaseTokenDecimals;
        uint192 leasePerWindowAtomic;
        uint192 maximumBondAtomic;
        uint192 reporterRewardCapAtomic;
        uint64 evidenceDelaySeconds;
        uint64 reorgMarginSeconds;
        address builderPenaltySink;
        uint64 rewardClaimWindowSeconds;
        IBuilderRegistry.BuilderRewardClassConfigV1[3] rewardClasses;
    }

    struct TopologyConfig {
        uint256 settlementChainId;
        address builderLeaseToken;
        bytes32 builderLeaseTokenRuntimeHash;
        uint8 builderLeaseTokenDecimals;
        uint64 genesisTimestamp;
        uint64 evidenceDelaySeconds;
        uint64 reorgMarginSeconds;
        uint64 firstManagedWindow;
        uint64 lastManagedWindow;
        address builderPenaltySink;
        uint64 rewardClaimWindowSeconds;
        address activeSettlementRouter;
        bytes32 routerRuntimeHash;
        bytes32 routerConfigurationHash;
        address scheduleOracle;
        bytes32 scheduleOracleRuntimeHash;
        address builderProofVerifier;
        bytes32 builderProofVerifierRuntimeHash;
        bytes32 builderProofVerifierConfigurationHash;
        address seatLifecycleFacet;
        bytes32 seatLifecycleFacetRuntimeHash;
        bytes32 seatLifecycleFacetConfigurationHash;
        address leaseLifecycleFacet;
        bytes32 leaseLifecycleFacetRuntimeHash;
        bytes32 leaseLifecycleFacetConfigurationHash;
        bytes32 economicConfigurationHash;
    }

    struct ConstructorConfig {
        uint256 settlementChainId;
        address builderLeaseToken;
        bytes32 builderLeaseTokenRuntimeHash;
        uint8 builderLeaseTokenDecimals;
        uint192 leasePerWindowAtomic;
        uint192 maximumBondAtomic;
        uint192 reporterRewardCapAtomic;
        uint64 genesisTimestamp;
        uint64 evidenceDelaySeconds;
        uint64 reorgMarginSeconds;
        uint64 firstManagedWindow;
        address builderPenaltySink;
        uint64 rewardClaimWindowSeconds;
        address activeSettlementRouter;
        bytes32 routerRuntimeHash;
        bytes32 routerConfigurationHash;
        address scheduleOracle;
        bytes32 scheduleOracleRuntimeHash;
        address builderProofVerifier;
        bytes32 builderProofVerifierRuntimeHash;
        bytes32 builderProofVerifierConfigurationHash;
        address seatLifecycleFacet;
        bytes32 seatLifecycleFacetRuntimeHash;
        bytes32 seatLifecycleFacetConfigurationHash;
        address leaseLifecycleFacet;
        bytes32 leaseLifecycleFacetRuntimeHash;
        bytes32 leaseLifecycleFacetConfigurationHash;
    }

    /// @dev Returns the exact economic configuration commitment over its 722-byte payload.
    function economicConfigurationHash(EconomicConfig memory _config)
        internal
        pure
        returns (bytes32 hash_)
    {
        bytes memory classes;
        for (uint256 i; i < 3; ++i) {
            IBuilderRegistry.BuilderRewardClassConfigV1 memory row = _config.rewardClasses[i];
            classes = bytes.concat(
                classes,
                abi.encodePacked(
                    row.classId,
                    row.nameHash,
                    row.fixedWei,
                    row.perExecutionGasWei,
                    row.perPublishedByteWei,
                    row.capWei
                )
            );
        }
        bytes memory payload = bytes.concat(
            abi.encodePacked(
                _config.settlementChainId,
                _config.builderLeaseToken,
                _config.builderLeaseTokenRuntimeHash,
                _config.builderLeaseTokenDecimals,
                uint256(_config.leasePerWindowAtomic),
                uint256(_config.maximumBondAtomic),
                uint256(_config.reporterRewardCapAtomic)
            ),
            abi.encodePacked(
                _config.evidenceDelaySeconds,
                _config.reorgMarginSeconds,
                ACTIVE_COUNT,
                MAX_ASSIGNED_SLOTS,
                ENTRY_DELAY_WINDOWS,
                EXIT_DELAY_WINDOWS,
                MAX_TRANCHE_AHEAD_WINDOWS
            ),
            abi.encodePacked(
                LIABILITY_COUNT,
                MAX_MOVES_PER_WINDOW,
                _config.builderPenaltySink,
                _config.rewardClaimWindowSeconds,
                uint8(3)
            ),
            classes
        );
        if (payload.length != 722) revert InvalidEconomicPayloadLength();
        return keccak256(
            bytes.concat(
                bytes("slot-chain-builder-registry-economic-config-v2"),
                bytes4(uint32(payload.length)),
                payload
            )
        );
    }

    /// @dev Returns the exact topology commitment over its 573-byte payload.
    function topologyHash(TopologyConfig memory _config) internal pure returns (bytes32 hash_) {
        bytes memory payload = bytes.concat(
            abi.encodePacked(
                _config.settlementChainId,
                _config.builderLeaseToken,
                _config.builderLeaseTokenRuntimeHash,
                _config.builderLeaseTokenDecimals,
                _config.genesisTimestamp,
                _config.evidenceDelaySeconds,
                _config.reorgMarginSeconds
            ),
            abi.encodePacked(
                _config.firstManagedWindow,
                _config.lastManagedWindow,
                _config.builderPenaltySink,
                _config.rewardClaimWindowSeconds,
                _config.activeSettlementRouter,
                _config.routerRuntimeHash,
                _config.routerConfigurationHash
            ),
            abi.encodePacked(
                _config.scheduleOracle,
                _config.scheduleOracleRuntimeHash,
                _config.builderProofVerifier,
                _config.builderProofVerifierRuntimeHash,
                _config.builderProofVerifierConfigurationHash
            ),
            abi.encodePacked(
                _config.seatLifecycleFacet,
                _config.seatLifecycleFacetRuntimeHash,
                _config.seatLifecycleFacetConfigurationHash,
                _config.leaseLifecycleFacet,
                _config.leaseLifecycleFacetRuntimeHash,
                _config.leaseLifecycleFacetConfigurationHash,
                _config.economicConfigurationHash
            )
        );
        if (payload.length != 573) revert InvalidTopologyPayloadLength();
        return keccak256(
            bytes.concat(
                bytes("slot-chain-builder-registry-topology-v2"), bytes2(uint16(573)), payload
            )
        );
    }

    /// @dev Converts retained generation storage into the exact committed cell payload.
    function cell(Generation storage _generation)
        internal
        view
        returns (SlotChainTypes.RegistryCellV1 memory cell_)
    {
        cell_ = SlotChainTypes.RegistryCellV1({
            builder: _generation.builder,
            bond: _generation.bond,
            registrationIndex: _generation.registrationIndex,
            effectiveL2Slot: _generation.effectiveL2Slot,
            trancheRoot: _generation.trancheRoot,
            tombstonedAtL2Slot: _generation.tombstonedAtL2Slot
        });
    }

    /// @dev Converts a memory generation into the exact committed cell payload.
    function memoryCell(Generation memory _generation)
        internal
        pure
        returns (SlotChainTypes.RegistryCellV1 memory cell_)
    {
        cell_ = SlotChainTypes.RegistryCellV1({
            builder: _generation.builder,
            bond: _generation.bond,
            registrationIndex: _generation.registrationIndex,
            effectiveL2Slot: _generation.effectiveL2Slot,
            trancheRoot: _generation.trancheRoot,
            tombstonedAtL2Slot: _generation.tombstonedAtL2Slot
        });
    }

    /// @dev Returns the position-bound canonical EMPTY tranche preimage.
    function emptyTranche(uint16 _index)
        internal
        pure
        returns (SlotChainTypes.TrancheLeafV1 memory leaf_)
    {
        leaf_ = SlotChainTypes.TrancheLeafV1({
            index: _index, window: type(uint64).max, state: TRANCHE_EMPTY, amount: 0, liableUntil: 0
        });
    }

    /// @dev Loads a bottom-up nine-sibling tranche path.
    function tranchePath(
        bytes calldata _witness,
        uint256 _offset
    )
        internal
        pure
        returns (bytes32[9] memory siblings_)
    {
        _requireAvailable(_witness, _offset, TRANCHE_PATH_LENGTH);
        for (uint256 i; i < 9; ++i) {
            siblings_[i] = readBytes32(_witness, _offset + i * 32);
        }
    }

    /// @dev Loads a bottom-up six-sibling registry path.
    function registryPath(
        bytes calldata _witness,
        uint256 _offset
    )
        internal
        pure
        returns (bytes32[6] memory siblings_)
    {
        _requireAvailable(_witness, _offset, REGISTRY_PATH_LENGTH);
        for (uint256 i; i < 6; ++i) {
            siblings_[i] = readBytes32(_witness, _offset + i * 32);
        }
    }

    /// @dev Loads a bottom-up eleven-sibling admission path.
    function admissionPath(
        bytes calldata _witness,
        uint256 _offset
    )
        internal
        pure
        returns (bytes32[11] memory siblings_)
    {
        _requireAvailable(_witness, _offset, ADMISSION_PATH_LENGTH);
        for (uint256 i; i < 11; ++i) {
            siblings_[i] = readBytes32(_witness, _offset + i * 32);
        }
    }

    /// @dev Loads one calldata byte without accepting an out-of-range read.
    function readU8(
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (uint8 value_)
    {
        _requireAvailable(_encoded, _offset, 1);
        assembly ("memory-safe") {
            value_ := byte(0, calldataload(add(_encoded.offset, _offset)))
        }
    }

    /// @dev Loads one canonical big-endian u32.
    function readU32(
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (uint32 value_)
    {
        _requireAvailable(_encoded, _offset, 4);
        assembly ("memory-safe") {
            value_ := shr(224, calldataload(add(_encoded.offset, _offset)))
        }
    }

    /// @dev Loads one canonical big-endian u64.
    function readU64(
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (uint64 value_)
    {
        _requireAvailable(_encoded, _offset, 8);
        assembly ("memory-safe") {
            value_ := shr(192, calldataload(add(_encoded.offset, _offset)))
        }
    }

    /// @dev Loads one bytes32 word from an exact packed tail.
    function readBytes32(
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (bytes32 value_)
    {
        _requireAvailable(_encoded, _offset, 32);
        assembly ("memory-safe") {
            value_ := calldataload(add(_encoded.offset, _offset))
        }
    }

    /// @dev Counts the set bits in the canonical 17-bit reservation bitmap.
    function popcount(uint32 _bitmap) internal pure returns (uint8 count_) {
        if (_bitmap >> 17 != 0) revert InvalidReservationBitmap();
        while (_bitmap != 0) {
            _bitmap &= _bitmap - 1;
            ++count_;
        }
    }

    /// @dev Returns the lowest set-bit offset and removes it from the bitmap.
    function takeLowest(uint32 _bitmap) internal pure returns (uint8 offset_, uint32 rest_) {
        if (_bitmap == 0 || _bitmap >> 17 != 0) revert InvalidReservationBitmap();
        uint32 lowest = _bitmap & (~_bitmap + 1);
        while ((lowest >> offset_) != 1) ++offset_;
        rest_ = _bitmap ^ lowest;
    }

    /// @dev Hashes an occupied active registry leaf.
    function activeLeaf(
        uint8 _index,
        Generation storage _generation
    )
        internal
        view
        returns (bytes32 leaf_)
    {
        return LibSlotChainEncoding.hashRegistryLeaf(_index, true, cell(_generation));
    }

    /// @dev Hashes an occupied admission leaf at its retained location.
    function admissionLeaf(
        uint16 _position,
        uint8 _location,
        Generation storage _generation
    )
        internal
        view
        returns (bytes32 leaf_)
    {
        return LibSlotChainEncoding.hashAdmissionLeaf(_position, true, _location, cell(_generation));
    }

    /// @dev Checks one packed calldata region without overflowing offset arithmetic.
    function _requireAvailable(
        bytes calldata _encoded,
        uint256 _offset,
        uint256 _length
    )
        private
        pure
    {
        if (_offset > _encoded.length || _length > _encoded.length - _offset) {
            revert WitnessReadOutOfBounds();
        }
    }

    error InvalidEconomicPayloadLength();
    error InvalidReservationBitmap();
    error InvalidTopologyPayloadLength();
    error WitnessReadOutOfBounds();
}
