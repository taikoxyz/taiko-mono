// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../shared/slotchain/SlotChainTypes.sol";
import { LibSlotChainEncoding } from "../../../shared/slotchain/libs/LibSlotChainEncoding.sol";
import { LibSlotChainEvidence } from "../../../shared/slotchain/libs/LibSlotChainEvidence.sol";
import { LibSlotChainFixedTrees } from "../../../shared/slotchain/libs/LibSlotChainFixedTrees.sol";

/// @title Immutable Slot Chain builder-registry proof verifier
/// @notice Computes bounded fixed-tree and signed-equivocation proof results without holding state.
/// @dev Implements {IBuilderRegistryProofVerifierV1} without inheriting it: two of its exact
///      fixed-width returns exceed the non-IR stack limit as typed Solidity outputs and are
///      written with assembly returns under the identical selectors.
/// @custom:security-contact security@taiko.xyz
contract BuilderRegistryProofVerifierV1 {
    bytes4 private constant _BPV1_MAGIC = 0x42505631;
    bytes4 private constant _EIV1_MAGIC = 0x45495631;
    bytes4 private constant _BPR1_MAGIC = 0x42505231;
    bytes4 private constant _BPO1_MAGIC = 0x42504f31;

    uint8 private constant _OP_REGISTRY_REPLACE = 1;
    uint8 private constant _OP_ADMISSION_REPLACE = 2;
    uint8 private constant _OP_TRANCHE_BATCH = 3;
    uint8 private constant _OP_EQUIVOCATION = 4;

    uint8 private constant _LOCATION_ACTIVE = 1;
    uint8 private constant _LOCATION_LIABILITY = 2;
    uint8 private constant _TRANCHE_EMPTY = 0;
    uint8 private constant _TRANCHE_FREE = 1;
    uint8 private constant _TRANCHE_RESERVED = 2;
    uint8 private constant _TRANCHE_LIABLE = 3;
    uint8 private constant _TRANCHE_RELEASED = 4;
    uint8 private constant _TRANCHE_SLASHED = 5;

    uint256 private constant _EVIDENCE_LENGTH = 2366;
    uint256 private constant _IDENTITY_CALLDATA_LENGTH = 2468;
    uint256 private constant _REGISTRY_REQUEST_LENGTH = 432;
    uint256 private constant _ADMISSION_REQUEST_LENGTH = 531;
    uint256 private constant _EVIDENCE_REQUEST_LENGTH = 2727;
    uint256 private constant _MAXIMUM_REQUEST_LENGTH = 6770;
    uint256 private constant _WINDOW_SLOTS = 384;
    uint64 private constant _LIVE_TOMBSTONE = type(uint64).max;

    /// @dev `H("slot-chain-builder-proof-verifier-config-v1" || u16(71) || C)` where C is the
    ///      fixed BPV1 row, both selectors, the four magics and the widths
    ///      `u16(512),u16(352),u16(224),u16(432),u16(531),u16(6770),u16(2727)`: the BPV1 return,
    ///      the EIV1 return, the identity preimage, the two fixed proof requests, the maximum
    ///      request and the evidence request.
    bytes32 private constant _CONFIGURATION_HASH =
        0xe3e45065c704e9bdad17d5b1a8de56115576b30d7e4e09d50a3a07aa66aac80b;

    struct IdentityResult {
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

    struct EvidenceRequest {
        uint256 expectedSettlementChainId;
        bytes32 evidenceHash;
        bytes32 identityCommitment;
        address builder;
        uint64 registrationIndex;
        uint8 location;
        uint16 admissionPosition;
        uint64 currentL2Slot;
        bytes32 registryRoot;
        bytes32 admissionRoot;
        SlotChainTypes.RegistryCellV1 cell;
        uint64 reservationBaseWindow;
        uint32 reservationBitmap;
        uint16 unreleasedTrancheCount;
        SlotChainTypes.TrancheLeafV1 tranche;
    }

    /// @notice Returns the exact immutable verifier configuration commitment.
    /// @return configHash_ The `builderProofVerifierConfigurationHash` value.
    function componentConfigHashV2() external pure returns (bytes32 configHash_) {
        return _CONFIGURATION_HASH;
    }

    /// @notice Returns the exact raw 512-byte BPV1 configuration row.
    /// @dev Implements {IBuilderRegistryProofVerifierV1-builderRegistryProofVerifierConfigV1}.
    ///      The source signature deliberately declares no Solidity outputs: solc 0.8.30 cannot
    ///      compile the frozen sixteen-output signature without via-IR. Return types do not
    ///      affect the selector, and the assembly return remains byte-identical to the typed
    ///      interface.
    function builderRegistryProofVerifierConfigV1() external pure {
        bytes32 configurationHash = _CONFIGURATION_HASH;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(224, 0x42505631))
            mstore(add(ptr, 0x20), 1)
            mstore(add(ptr, 0x40), 64)
            mstore(add(ptr, 0x60), 1136)
            mstore(add(ptr, 0x80), 2048)
            mstore(add(ptr, 0xa0), 512)
            mstore(add(ptr, 0xc0), 6)
            mstore(add(ptr, 0xe0), 11)
            mstore(add(ptr, 0x100), 9)
            mstore(add(ptr, 0x120), 18)
            mstore(add(ptr, 0x140), 350000)
            mstore(add(ptr, 0x160), 120000)
            mstore(add(ptr, 0x180), 160000)
            mstore(add(ptr, 0x1a0), 700000)
            mstore(add(ptr, 0x1c0), 450000)
            mstore(add(ptr, 0x1e0), configurationHash)
            return(ptr, 0x200)
        }
    }

    /// @notice Verifies the signature-bound identity of canonical equivocation evidence.
    /// @dev Implements {IBuilderRegistryProofVerifierV1-verifyBuilderEquivocationIdentityV1}. The
    ///      exact 352-byte EIV1 return `(magic, verifierConfigurationHash, evidenceHash,
    ///      identityCommitment, builder, window, protocolVersion, verifyingContract, l2ChainId,
    ///      signedAdmissionVersion, signedAdmissionRoot)` is written with an assembly return so
    ///      that the eleven-output signature needs no via-IR build; the selector and word order
    ///      equal the typed interface.
    /// @param _expectedSettlementChainId The Registry-authenticated settlement-chain identifier.
    /// @param _evidence The exact 2,366-byte canonical evidence payload.
    function verifyBuilderEquivocationIdentityV1(
        uint256 _expectedSettlementChainId,
        bytes calldata _evidence
    )
        external
        pure
        returns (
            bytes4,
            bytes32,
            bytes32,
            bytes32,
            address,
            uint64,
            uint64,
            address,
            uint256,
            uint64,
            bytes32
        )
    {
        _requireCanonicalDynamicCalldata(_evidence, 64, _IDENTITY_CALLDATA_LENGTH);
        IdentityResult memory result = _verifyIdentity(_expectedSettlementChainId, _evidence);
        bytes32 configurationHash = _CONFIGURATION_HASH;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(224, 0x45495631))
            mstore(add(ptr, 0x20), configurationHash)
            mstore(add(ptr, 0x40), mload(result))
            mstore(add(ptr, 0x60), mload(add(result, 0x20)))
            mstore(add(ptr, 0x80), mload(add(result, 0x40)))
            mstore(add(ptr, 0xa0), mload(add(result, 0x60)))
            mstore(add(ptr, 0xc0), mload(add(result, 0x80)))
            mstore(add(ptr, 0xe0), mload(add(result, 0xa0)))
            mstore(add(ptr, 0x100), mload(add(result, 0xc0)))
            mstore(add(ptr, 0x120), mload(add(result, 0xe0)))
            mstore(add(ptr, 0x140), mload(add(result, 0x100)))
            return(ptr, 0x160)
        }
    }

    /// @notice Verifies one exact packed fixed-tree or equivocation proof request.
    /// @dev Implements {IBuilderRegistryProofVerifierV1-verifyBuilderRegistryProofV1}.
    /// @param _request The canonical `BPR1` proof request.
    /// @return magic_ The fixed `BPO1` magic.
    /// @return verifierConfigurationHash_ The exact verifier configuration commitment.
    /// @return requestCommitment_ The complete request commitment.
    /// @return newRegistryRoot_ The replacement Registry root, or zero when masked off.
    /// @return newAdmissionRoot_ The replacement admission root, or zero when masked off.
    /// @return newTrancheRoot_ The replacement tranche root, or zero when masked off.
    function verifyBuilderRegistryProofV1(bytes calldata _request)
        external
        pure
        returns (
            bytes4 magic_,
            bytes32 verifierConfigurationHash_,
            bytes32 requestCommitment_,
            bytes32 newRegistryRoot_,
            bytes32 newAdmissionRoot_,
            bytes32 newTrancheRoot_
        )
    {
        if (_request.length < 5 || _request.length > _MAXIMUM_REQUEST_LENGTH) {
            revert InvalidProofRequest();
        }
        _requireCanonicalDynamicCalldata(_request, 32, 68 + _ceil32(_request.length));
        if (_readBytes4(_request, 0) != _BPR1_MAGIC) revert InvalidProofRequest();
        uint8 opcode = _readU8(_request, 4);
        if (opcode == _OP_REGISTRY_REPLACE) {
            newRegistryRoot_ = _verifyRegistryReplace(_request);
        } else if (opcode == _OP_ADMISSION_REPLACE) {
            newAdmissionRoot_ = _verifyAdmissionReplace(_request);
        } else if (opcode == _OP_TRANCHE_BATCH) {
            newTrancheRoot_ = _verifyTrancheBatch(_request);
        } else if (opcode == _OP_EQUIVOCATION) {
            (newRegistryRoot_, newAdmissionRoot_, newTrancheRoot_) = _verifyEvidence(_request);
        } else {
            revert InvalidProofOpcode();
        }
        requestCommitment_ = keccak256(
            abi.encodePacked(
                "slot-chain-builder-proof-request-v1", uint32(_request.length), _request
            )
        );
        return (
            _BPO1_MAGIC,
            _CONFIGURATION_HASH,
            requestCommitment_,
            newRegistryRoot_,
            newAdmissionRoot_,
            newTrancheRoot_
        );
    }

    /// @dev Verifies one registry-leaf replacement and returns only its post-root.
    function _verifyRegistryReplace(bytes calldata _request) private pure returns (bytes32 root_) {
        if (_request.length != _REGISTRY_REQUEST_LENGTH) revert InvalidProofRequestLength();
        bytes32 oldRoot = _readBytes32(_request, 5);
        uint8 index = _readU8(_request, 37);
        if (index >= 64) revert InvalidRegistryIndex();
        bool oldOccupied = _readFlag(_request, 38);
        SlotChainTypes.RegistryCellV1 memory oldCell = _registryCell(_request, 39, oldOccupied);
        bool newOccupied = _readFlag(_request, 139);
        SlotChainTypes.RegistryCellV1 memory newCell = _registryCell(_request, 140, newOccupied);
        bytes32[6] memory siblings = _siblings6(_request, 240);
        return LibSlotChainFixedTrees.updateRegistryRoot(
            oldRoot,
            index,
            LibSlotChainEncoding.hashRegistryLeaf(index, oldOccupied, oldCell),
            LibSlotChainEncoding.hashRegistryLeaf(index, newOccupied, newCell),
            siblings
        );
    }

    /// @dev Verifies one used admission-leaf replacement and returns only its post-root.
    function _verifyAdmissionReplace(bytes calldata _request) private pure returns (bytes32 root_) {
        if (_request.length != _ADMISSION_REQUEST_LENGTH) revert InvalidProofRequestLength();
        bytes32 oldRoot = _readBytes32(_request, 5);
        uint16 position = _readU16(_request, 37);
        if (position >= 1136) revert InvalidAdmissionPosition();
        bool oldOccupied = _readFlag(_request, 39);
        uint8 oldLocation = _readU8(_request, 40);
        SlotChainTypes.RegistryCellV1 memory oldCell =
            _admissionCell(_request, 41, position, oldOccupied, oldLocation);
        bool newOccupied = _readFlag(_request, 109);
        uint8 newLocation = _readU8(_request, 110);
        SlotChainTypes.RegistryCellV1 memory newCell =
            _admissionCell(_request, 111, position, newOccupied, newLocation);
        bytes32[11] memory siblings = _siblings11(_request, 179);
        return LibSlotChainFixedTrees.updateAdmissionUsedRoot(
            oldRoot,
            position,
            LibSlotChainEncoding.hashAdmissionLeaf(position, oldOccupied, oldLocation, oldCell),
            LibSlotChainEncoding.hashAdmissionLeaf(position, newOccupied, newLocation, newCell),
            siblings
        );
    }

    /// @dev Verifies one to eighteen root-chained legal tranche transitions.
    function _verifyTrancheBatch(bytes calldata _request) private pure returns (bytes32 root_) {
        uint8 count = _readU8(_request, 37);
        if (count == 0 || count > 18 || _request.length != 38 + uint256(count) * 374) {
            revert InvalidTrancheBatch();
        }
        root_ = _readBytes32(_request, 5);
        uint256 offset = 38;
        for (uint256 i; i < count; ++i) {
            SlotChainTypes.TrancheLeafV1 memory oldLeaf = _trancheLeaf(_request, offset);
            SlotChainTypes.TrancheLeafV1 memory newLeaf = _trancheLeaf(_request, offset + 43);
            _requireTrancheTransition(oldLeaf, newLeaf);
            root_ = LibSlotChainFixedTrees.updateTrancheRoot(
                root_,
                oldLeaf.index,
                LibSlotChainEncoding.hashTrancheLeaf(oldLeaf),
                LibSlotChainEncoding.hashTrancheLeaf(newLeaf),
                _siblings9(_request, offset + 86)
            );
            offset += 374;
        }
    }

    /// @dev Verifies the complete evidence proof and returns its exact root mask.
    function _verifyEvidence(bytes calldata _request)
        private
        pure
        returns (bytes32 registryRoot_, bytes32 admissionRoot_, bytes32 trancheRoot_)
    {
        if (_request.length != _EVIDENCE_REQUEST_LENGTH) revert InvalidProofRequestLength();
        bytes calldata evidence = _request[5:2371];
        EvidenceRequest memory request = _decodeEvidenceRequest(_request);
        IdentityResult memory identity =
            _verifyIdentity(request.expectedSettlementChainId, evidence);
        if (
            request.evidenceHash != identity.evidenceHash
                || request.identityCommitment != identity.identityCommitment
                || request.builder != identity.builder || request.cell.builder != identity.builder
                || request.cell.registrationIndex != request.registrationIndex
        ) {
            revert EvidenceIdentityMismatch();
        }

        _verifyHistoricalAdmission(evidence, identity.signedAdmissionRoot, request.cell);
        _verifyCurrentAdmission(evidence, request);
        trancheRoot_ = _verifyEvidenceTranche(evidence, identity.window, request);

        SlotChainTypes.RegistryCellV1 memory newCell = _copyCell(request.cell);
        newCell.trancheRoot = trancheRoot_;
        bool firstTombstone = request.cell.tombstonedAtL2Slot == _LIVE_TOMBSTONE;
        if (firstTombstone) {
            newCell.tombstonedAtL2Slot = request.currentL2Slot;
            admissionRoot_ = LibSlotChainFixedTrees.computeAdmissionRoot(
                request.admissionPosition,
                LibSlotChainEncoding.hashAdmissionLeaf(
                    request.admissionPosition, true, request.location, newCell
                ),
                _siblings11(evidence, 1822)
            );
        } else if (request.cell.tombstonedAtL2Slot > request.currentL2Slot) {
            revert InvalidCurrentTombstone();
        }

        if (request.location == _LOCATION_ACTIVE) {
            uint8 activeIndex = uint8(request.admissionPosition);
            registryRoot_ = LibSlotChainFixedTrees.updateRegistryRoot(
                request.registryRoot,
                activeIndex,
                LibSlotChainEncoding.hashRegistryLeaf(activeIndex, true, request.cell),
                LibSlotChainEncoding.hashRegistryLeaf(activeIndex, true, newCell),
                _siblings6(evidence, 2174)
            );
        } else {
            for (uint256 i; i < 6; ++i) {
                if (_readBytes32(evidence, 2174 + i * 32) != bytes32(0)) {
                    revert NonCanonicalLiabilityRegistryProof();
                }
            }
        }
    }

    /// @dev Decodes the Registry-authenticated suffix of an evidence request.
    function _decodeEvidenceRequest(bytes calldata _request)
        private
        pure
        returns (EvidenceRequest memory value_)
    {
        value_.expectedSettlementChainId = _readU256(_request, 2371);
        value_.evidenceHash = _readBytes32(_request, 2403);
        value_.identityCommitment = _readBytes32(_request, 2435);
        value_.builder = _readAddress(_request, 2467);
        value_.registrationIndex = _readU64(_request, 2487);
        value_.location = _readU8(_request, 2495);
        value_.admissionPosition = _readU16(_request, 2496);
        value_.currentL2Slot = _readU64(_request, 2498);
        value_.registryRoot = _readBytes32(_request, 2506);
        value_.admissionRoot = _readBytes32(_request, 2538);
        value_.cell = _registryCell(_request, 2570, true);
        value_.reservationBaseWindow = _readU64(_request, 2670);
        value_.reservationBitmap = _readU32(_request, 2678);
        value_.unreleasedTrancheCount = _readU16(_request, 2682);
        value_.tranche = _trancheLeaf(_request, 2684);
        if (
            value_.admissionPosition >= 1136
                || (value_.location == _LOCATION_ACTIVE && value_.admissionPosition >= 64)
                || (value_.location == _LOCATION_LIABILITY && value_.admissionPosition < 64)
                || (value_.location != _LOCATION_ACTIVE && value_.location != _LOCATION_LIABILITY)
                || value_.reservationBitmap >> 17 != 0
        ) {
            revert InvalidEvidenceLocation();
        }
    }

    /// @dev Proves the untombstoned builder identity under the signed admission root.
    function _verifyHistoricalAdmission(
        bytes calldata _evidence,
        bytes32 _signedAdmissionRoot,
        SlotChainTypes.RegistryCellV1 memory _currentCell
    )
        private
        pure
    {
        uint16 position = _readU16(_evidence, 1172);
        if (position >= 1136) revert InvalidHistoricalAdmissionPosition();
        uint8 location = position < 64 ? _LOCATION_ACTIVE : _LOCATION_LIABILITY;
        SlotChainTypes.RegistryCellV1 memory historicalCell = _copyCell(_currentCell);
        historicalCell.tombstonedAtL2Slot = _LIVE_TOMBSTONE;
        if (
            LibSlotChainFixedTrees.computeAdmissionRoot(
                    position,
                    LibSlotChainEncoding.hashAdmissionLeaf(
                        position, true, location, historicalCell
                    ),
                    _siblings11(_evidence, 1174)
                ) != _signedAdmissionRoot
        ) {
            revert HistoricalAdmissionProofMismatch();
        }
    }

    /// @dev Proves the exact current generation under the current admission root.
    function _verifyCurrentAdmission(
        bytes calldata _evidence,
        EvidenceRequest memory _request
    )
        private
        pure
    {
        if (
            LibSlotChainFixedTrees.computeAdmissionRoot(
                    _request.admissionPosition,
                    LibSlotChainEncoding.hashAdmissionLeaf(
                        _request.admissionPosition, true, _request.location, _request.cell
                    ),
                    _siblings11(_evidence, 1822)
                ) != _request.admissionRoot
        ) {
            revert CurrentAdmissionProofMismatch();
        }
    }

    /// @dev Proves and derives the exact current tranche transition to SLASHED.
    function _verifyEvidenceTranche(
        bytes calldata _evidence,
        uint64 _window,
        EvidenceRequest memory _request
    )
        private
        pure
        returns (bytes32 root_)
    {
        SlotChainTypes.TrancheLeafV1 memory oldLeaf = _request.tranche;
        if (
            oldLeaf.index != uint16(_window % 512) || oldLeaf.window != _window
                || (oldLeaf.state != _TRANCHE_RESERVED && oldLeaf.state != _TRANCHE_LIABLE)
                || oldLeaf.amount == 0 || oldLeaf.liableUntil == 0
                || _request.unreleasedTrancheCount == 0
        ) {
            revert EvidenceTrancheNotSlashable();
        }
        if (_request.location == _LOCATION_ACTIVE && oldLeaf.state == _TRANCHE_RESERVED) {
            if (
                _window < _request.reservationBaseWindow
                    || _window - _request.reservationBaseWindow > 16
                    || (_request.reservationBitmap
                                & (uint32(1) << uint8(_window - _request.reservationBaseWindow)))
                        == 0
            ) {
                revert ReservationBitmapMismatch();
            }
        } else if (
            _request.location == _LOCATION_LIABILITY
                && (_request.reservationBitmap != 0 || oldLeaf.state != _TRANCHE_LIABLE)
        ) {
            revert ReservationBitmapMismatch();
        }
        SlotChainTypes.TrancheLeafV1 memory newLeaf = _copyTranche(oldLeaf);
        newLeaf.state = _TRANCHE_SLASHED;
        newLeaf.amount = 0;
        return LibSlotChainFixedTrees.updateTrancheRoot(
            _request.cell.trancheRoot,
            oldLeaf.index,
            LibSlotChainEncoding.hashTrancheLeaf(oldLeaf),
            LibSlotChainEncoding.hashTrancheLeaf(newLeaf),
            _siblings9(_evidence, 1534)
        );
    }

    /// @dev Verifies the common signed header, signer and evidence-window identity.
    function _verifyIdentity(
        uint256 _expectedSettlementChainId,
        bytes calldata _evidence
    )
        private
        pure
        returns (IdentityResult memory result_)
    {
        if (_evidence.length != _EVIDENCE_LENGTH || _expectedSettlementChainId == 0) {
            revert InvalidEquivocationEvidence();
        }
        SlotChainTypes.SlotChainBlock memory blockA =
            LibSlotChainEvidence.decodePackedBlock(_evidence, 0);
        SlotChainTypes.SlotChainBlock memory blockB =
            LibSlotChainEvidence.decodePackedBlock(_evidence, 586);
        if (
            blockA.settlementChainId != _expectedSettlementChainId
                || blockB.settlementChainId != _expectedSettlementChainId
                || blockA.protocolVersion > type(uint64).max || blockA.l2ChainId == 0
        ) {
            revert InvalidEvidenceDomain();
        }
        (result_.builder,,) =
            LibSlotChainEvidence.validateEquivocationPair(blockA, blockB, _evidence, 521, 1107);
        result_.window = uint64(blockA.slot / _WINDOW_SLOTS);
        if (_readU64(_evidence, 1526) != result_.window) revert InvalidEvidenceWindow();
        result_.protocolVersion = uint64(blockA.protocolVersion);
        result_.verifyingContract = blockA.verifyingContract;
        result_.l2ChainId = blockA.l2ChainId;
        result_.signedAdmissionVersion = blockA.admissionVersion;
        result_.signedAdmissionRoot = blockA.admissionRoot;
        result_.evidenceHash = keccak256(_evidence);
        result_.identityCommitment = _identityCommitment(result_, _expectedSettlementChainId);
    }

    /// @dev Derives the exact EIV1 identity commitment
    ///      `H("slot-chain-builder-equivocation-identity-v2" || u16(224) ||
    ///      verifierConfigurationHash || evidenceHash || u256(expectedSettlementChainId) ||
    ///      u256(l2ChainId) || u64(protocolVersion) || address20(verifyingContract) ||
    ///      u64(window) || u64(signedAdmissionVersion) || signedAdmissionRoot ||
    ///      address20(builder))`. The pair-equal signed `l2ChainId` is bound so evidence for a
    ///      different L2 chain that shares the settlement chain is a different identity.
    function _identityCommitment(
        IdentityResult memory _result,
        uint256 _expectedSettlementChainId
    )
        private
        pure
        returns (bytes32 commitment_)
    {
        return keccak256(
            abi.encodePacked(
                "slot-chain-builder-equivocation-identity-v2",
                uint16(224),
                _CONFIGURATION_HASH,
                _result.evidenceHash,
                _expectedSettlementChainId,
                _result.l2ChainId,
                _result.protocolVersion,
                _result.verifyingContract,
                _result.window,
                _result.signedAdmissionVersion,
                _result.signedAdmissionRoot,
                _result.builder
            )
        );
    }

    /// @dev Decodes and validates a canonical registry-cell preimage.
    function _registryCell(
        bytes calldata _encoded,
        uint256 _offset,
        bool _occupied
    )
        private
        pure
        returns (SlotChainTypes.RegistryCellV1 memory cell_)
    {
        if (!_occupied) {
            if (!_isZero(_encoded, _offset, 100)) revert DirtyEmptyCell();
            return cell_;
        }
        cell_.builder = _readAddress(_encoded, _offset);
        cell_.bond = _readU192(_encoded, _offset + 20);
        cell_.registrationIndex = _readU64(_encoded, _offset + 44);
        cell_.effectiveL2Slot = _readU64(_encoded, _offset + 52);
        cell_.trancheRoot = _readBytes32(_encoded, _offset + 60);
        cell_.tombstonedAtL2Slot = _readU64(_encoded, _offset + 92);
        if (cell_.builder == address(0) || cell_.bond == 0 || cell_.trancheRoot == bytes32(0)) {
            revert InvalidOccupiedCell();
        }
    }

    /// @dev Decodes and validates a canonical admission-cell preimage.
    function _admissionCell(
        bytes calldata _encoded,
        uint256 _offset,
        uint16 _position,
        bool _occupied,
        uint8 _location
    )
        private
        pure
        returns (SlotChainTypes.RegistryCellV1 memory cell_)
    {
        if (!_occupied) {
            if (_location != 0 || !_isZero(_encoded, _offset, 68)) revert DirtyEmptyCell();
            return cell_;
        }
        if (
            (_location == _LOCATION_ACTIVE && _position >= 64)
                || (_location == _LOCATION_LIABILITY && _position < 64)
                || (_location != _LOCATION_ACTIVE && _location != _LOCATION_LIABILITY)
        ) {
            revert InvalidAdmissionLocation();
        }
        cell_.builder = _readAddress(_encoded, _offset);
        cell_.bond = _readU192(_encoded, _offset + 20);
        cell_.registrationIndex = _readU64(_encoded, _offset + 44);
        cell_.effectiveL2Slot = _readU64(_encoded, _offset + 52);
        cell_.tombstonedAtL2Slot = _readU64(_encoded, _offset + 60);
        if (cell_.builder == address(0) || cell_.bond == 0) revert InvalidOccupiedCell();
    }

    /// @dev Decodes and validates a canonical tranche-leaf preimage.
    function _trancheLeaf(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (SlotChainTypes.TrancheLeafV1 memory leaf_)
    {
        leaf_.index = _readU16(_encoded, _offset);
        leaf_.window = _readU64(_encoded, _offset + 2);
        leaf_.state = _readU8(_encoded, _offset + 10);
        leaf_.amount = _readU192(_encoded, _offset + 11);
        leaf_.liableUntil = _readU64(_encoded, _offset + 35);
        if (leaf_.index >= 512 || leaf_.state > _TRANCHE_SLASHED) {
            revert InvalidTrancheLeaf();
        }
        if (leaf_.state == _TRANCHE_EMPTY) {
            if (leaf_.window != type(uint64).max || leaf_.amount != 0 || leaf_.liableUntil != 0) {
                revert InvalidTrancheLeaf();
            }
        } else if (leaf_.state == _TRANCHE_FREE) {
            if (leaf_.window == type(uint64).max || leaf_.amount != 0 || leaf_.liableUntil != 0) {
                revert InvalidTrancheLeaf();
            }
        } else if (leaf_.state == _TRANCHE_RESERVED || leaf_.state == _TRANCHE_LIABLE) {
            if (leaf_.window == type(uint64).max || leaf_.amount == 0 || leaf_.liableUntil == 0) {
                revert InvalidTrancheLeaf();
            }
        } else if (leaf_.window == type(uint64).max || leaf_.amount != 0 || leaf_.liableUntil == 0)
        {
            revert InvalidTrancheLeaf();
        }
    }

    /// @dev Enforces the closed set of public Registry tranche transitions.
    function _requireTrancheTransition(
        SlotChainTypes.TrancheLeafV1 memory _oldLeaf,
        SlotChainTypes.TrancheLeafV1 memory _newLeaf
    )
        private
        pure
    {
        if (_oldLeaf.index != _newLeaf.index) revert InvalidTrancheTransition();
        if (_oldLeaf.state == _TRANCHE_RESERVED && _newLeaf.state == _TRANCHE_LIABLE) {
            if (
                _oldLeaf.window != _newLeaf.window || _oldLeaf.amount != _newLeaf.amount
                    || _oldLeaf.liableUntil != _newLeaf.liableUntil
            ) {
                revert InvalidTrancheTransition();
            }
            return;
        }
        if (_oldLeaf.state == _TRANCHE_LIABLE && _newLeaf.state == _TRANCHE_RELEASED) {
            if (
                _oldLeaf.window != _newLeaf.window || _newLeaf.amount != 0
                    || _oldLeaf.liableUntil != _newLeaf.liableUntil
            ) {
                revert InvalidTrancheTransition();
            }
            return;
        }
        if (_newLeaf.state != _TRANCHE_RESERVED) revert InvalidTrancheTransition();
        if (_oldLeaf.state == _TRANCHE_EMPTY) {
            if (_newLeaf.window == type(uint64).max) revert InvalidTrancheTransition();
        } else if (_oldLeaf.state == _TRANCHE_FREE) {
            if (_newLeaf.window != _oldLeaf.window) revert InvalidTrancheTransition();
        } else if (_oldLeaf.state == _TRANCHE_RELEASED || _oldLeaf.state == _TRANCHE_SLASHED) {
            if (_newLeaf.window <= _oldLeaf.window) revert InvalidTrancheTransition();
        } else {
            revert InvalidTrancheTransition();
        }
    }

    /// @dev Requires the sole dynamic bytes argument to use the exact canonical ABI tail.
    function _requireCanonicalDynamicCalldata(
        bytes calldata _value,
        uint256 _expectedOffset,
        uint256 _expectedLength
    )
        private
        pure
    {
        uint256 actualOffset;
        uint256 valueOffset;
        uint256 offsetWordPosition = _expectedOffset == 32 ? 4 : 36;
        assembly ("memory-safe") {
            actualOffset := calldataload(offsetWordPosition)
            valueOffset := _value.offset
        }
        if (
            actualOffset != _expectedOffset || msg.data.length != _expectedLength
                || valueOffset != 4 + _expectedOffset + 32
        ) {
            revert NonCanonicalCalldata();
        }
        uint256 end = valueOffset + _value.length;
        for (uint256 i = end; i < msg.data.length; ++i) {
            if (msg.data[i] != 0) revert NonCanonicalCalldata();
        }
    }

    /// @dev Returns a field-by-field copy that cannot alias its source.
    function _copyCell(SlotChainTypes.RegistryCellV1 memory _cell)
        private
        pure
        returns (SlotChainTypes.RegistryCellV1 memory copy_)
    {
        copy_ = SlotChainTypes.RegistryCellV1({
            builder: _cell.builder,
            bond: _cell.bond,
            registrationIndex: _cell.registrationIndex,
            effectiveL2Slot: _cell.effectiveL2Slot,
            trancheRoot: _cell.trancheRoot,
            tombstonedAtL2Slot: _cell.tombstonedAtL2Slot
        });
    }

    /// @dev Returns a field-by-field tranche copy that cannot alias its source.
    function _copyTranche(SlotChainTypes.TrancheLeafV1 memory _leaf)
        private
        pure
        returns (SlotChainTypes.TrancheLeafV1 memory copy_)
    {
        copy_ = SlotChainTypes.TrancheLeafV1({
            index: _leaf.index,
            window: _leaf.window,
            state: _leaf.state,
            amount: _leaf.amount,
            liableUntil: _leaf.liableUntil
        });
    }

    function _siblings6(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (bytes32[6] memory siblings_)
    {
        for (uint256 i; i < 6; ++i) {
            siblings_[i] = _readBytes32(_encoded, _offset + i * 32);
        }
    }

    function _siblings9(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (bytes32[9] memory siblings_)
    {
        for (uint256 i; i < 9; ++i) {
            siblings_[i] = _readBytes32(_encoded, _offset + i * 32);
        }
    }

    function _siblings11(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (bytes32[11] memory siblings_)
    {
        for (uint256 i; i < 11; ++i) {
            siblings_[i] = _readBytes32(_encoded, _offset + i * 32);
        }
    }

    function _isZero(
        bytes calldata _encoded,
        uint256 _offset,
        uint256 _length
    )
        private
        pure
        returns (bool zero_)
    {
        if (_offset > _encoded.length || _length > _encoded.length - _offset) {
            revert ProofReadOutOfBounds();
        }
        for (uint256 i; i < _length; ++i) {
            if (_encoded[_offset + i] != 0) return false;
        }
        return true;
    }

    function _readFlag(bytes calldata _encoded, uint256 _offset)
        private
        pure
        returns (bool value_)
    {
        uint8 raw = _readU8(_encoded, _offset);
        if (raw > 1) revert InvalidOccupancyFlag();
        return raw == 1;
    }

    function _readU8(bytes calldata _encoded, uint256 _offset) private pure returns (uint8 value_) {
        _requireAvailable(_encoded, _offset, 1);
        assembly ("memory-safe") {
            value_ := byte(0, calldataload(add(_encoded.offset, _offset)))
        }
    }

    function _readU16(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint16 value_)
    {
        _requireAvailable(_encoded, _offset, 2);
        assembly ("memory-safe") {
            value_ := shr(240, calldataload(add(_encoded.offset, _offset)))
        }
    }

    function _readU32(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint32 value_)
    {
        _requireAvailable(_encoded, _offset, 4);
        assembly ("memory-safe") {
            value_ := shr(224, calldataload(add(_encoded.offset, _offset)))
        }
    }

    function _readU64(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint64 value_)
    {
        _requireAvailable(_encoded, _offset, 8);
        assembly ("memory-safe") {
            value_ := shr(192, calldataload(add(_encoded.offset, _offset)))
        }
    }

    function _readU192(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint192 value_)
    {
        _requireAvailable(_encoded, _offset, 24);
        assembly ("memory-safe") {
            value_ := shr(64, calldataload(add(_encoded.offset, _offset)))
        }
    }

    function _readU256(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint256 value_)
    {
        _requireAvailable(_encoded, _offset, 32);
        assembly ("memory-safe") {
            value_ := calldataload(add(_encoded.offset, _offset))
        }
    }

    function _readAddress(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (address value_)
    {
        _requireAvailable(_encoded, _offset, 20);
        assembly ("memory-safe") {
            value_ := shr(96, calldataload(add(_encoded.offset, _offset)))
        }
    }

    function _readBytes4(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (bytes4 value_)
    {
        _requireAvailable(_encoded, _offset, 4);
        assembly ("memory-safe") {
            value_ := calldataload(add(_encoded.offset, _offset))
        }
    }

    function _readBytes32(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (bytes32 value_)
    {
        _requireAvailable(_encoded, _offset, 32);
        assembly ("memory-safe") {
            value_ := calldataload(add(_encoded.offset, _offset))
        }
    }

    function _requireAvailable(
        bytes calldata _encoded,
        uint256 _offset,
        uint256 _length
    )
        private
        pure
    {
        if (_offset > _encoded.length || _length > _encoded.length - _offset) {
            revert ProofReadOutOfBounds();
        }
    }

    function _ceil32(uint256 _value) private pure returns (uint256 rounded_) {
        unchecked {
            return (_value + 31) & ~uint256(31);
        }
    }

    error CurrentAdmissionProofMismatch();
    error DirtyEmptyCell();
    error EvidenceIdentityMismatch();
    error EvidenceTrancheNotSlashable();
    error HistoricalAdmissionProofMismatch();
    error InvalidAdmissionLocation();
    error InvalidAdmissionPosition();
    error InvalidCurrentTombstone();
    error InvalidEquivocationEvidence();
    error InvalidEvidenceDomain();
    error InvalidEvidenceLocation();
    error InvalidEvidenceWindow();
    error InvalidHistoricalAdmissionPosition();
    error InvalidOccupancyFlag();
    error InvalidOccupiedCell();
    error InvalidProofOpcode();
    error InvalidProofRequest();
    error InvalidProofRequestLength();
    error InvalidRegistryIndex();
    error InvalidTrancheBatch();
    error InvalidTrancheLeaf();
    error InvalidTrancheTransition();
    error NonCanonicalCalldata();
    error NonCanonicalLiabilityRegistryProof();
    error ProofReadOutOfBounds();
    error ReservationBitmapMismatch();
}
