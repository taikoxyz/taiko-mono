// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    IBuilderRegistry
} from "../../../../contracts/layer1/slotchain/iface/IBuilderRegistry.sol";
import {
    BuilderRegistryLogicV1 as BuilderRegistry
} from "../../../../contracts/layer1/slotchain/impl/BuilderRegistry.sol";
import {
    BuilderRegistryProofVerifierV1
} from "../../../../contracts/layer1/slotchain/impl/BuilderRegistryProofVerifierV1.sol";
import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import { LibExactCall } from "../../../../contracts/shared/slotchain/libs/LibExactCall.sol";
import {
    LibSlotChainEncoding
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainEncoding.sol";
import {
    LibSlotChainFixedTrees
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainFixedTrees.sol";
import { BuilderRegistryTestBase } from "./BuilderRegistry.t.sol";
import { BuilderRegistryMerkleTracker } from "./BuilderRegistryTestHelpers.sol";

contract BuilderEvidenceTest is BuilderRegistryTestBase {
    using BuilderRegistryMerkleTracker for BuilderRegistryMerkleTracker.Tree;

    uint256 private constant BUILDER_KEY = 0xB017D3;
    uint64 private constant PROTOCOL_VERSION = 7;
    uint64 private constant L2_CHAIN_ID = 167_000;
    bytes4 private constant IDENTITY_SELECTOR = 0x7c09d62d;
    bytes4 private constant PROOF_SELECTOR = 0xa9ca9190;

    struct EvidenceContext {
        BuilderRegistryMerkleTracker.Tree registryTree;
        BuilderRegistryMerkleTracker.Tree admissionTree;
        BuilderRegistryMerkleTracker.Tree trancheTree;
        SlotChainTypes.RegistryCellV1 cell;
        SlotChainTypes.TrancheLeafV1 tranche;
        address builder;
        uint64 window;
        uint64 slot;
    }

    struct SignedEvidenceBlocks {
        SlotChainTypes.SlotChainBlock a;
        SlotChainTypes.SlotChainBlock b;
        bytes32 rA;
        bytes32 sA;
        bytes32 rB;
        bytes32 sB;
        uint8 vA;
        uint8 vB;
    }

    struct EvidenceMaskContext {
        EvidenceContext evidenceContext;
        BuilderRegistryProofVerifierV1 verifier;
        SlotChainTypes.RegistryCellV1 currentCell;
        SlotChainTypes.TrancheLeafV1 currentTranche;
        bytes evidence;
        bytes32 verifierConfigurationHash;
        bytes32 evidenceHash;
        bytes32 identityCommitment;
        uint64 currentL2Slot;
        uint64 reservationBaseWindow;
        uint32 reservationBitmap;
        uint16 admissionPosition;
        uint8 location;
    }

    function test_validEvidenceUses512ByteRTR2AndSlashesAtDeadlineEquality() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory evidence = _evidence(context, block.chainid, L2_CHAIN_ID);
        uint64 deadline = context.tranche.liableUntil;
        vm.warp(deadline);
        address reporter = address(0x5151);

        vm.prank(reporter);
        (bool ok, bytes memory raw) = address(registry)
            .call(abi.encodeCall(IBuilderRegistry.submitBuilderEquivocationV1, (evidence)));
        assertTrue(ok);
        assertEq(raw.length, 256);

        context.tranche.state = uint8(SlotChainTypes.TrancheState.SLASHED);
        context.tranche.amount = 0;
        context.trancheTree
            .update(
                uint16(context.window % 512),
                BuilderRegistryMerkleTracker.trancheLeaf(context.tranche)
            );
        context.cell.trancheRoot = context.trancheTree.root();
        context.cell.tombstonedAtL2Slot = deadline - GENESIS;
        context.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, context.cell));
        context.admissionTree
            .update(0, BuilderRegistryMerkleTracker.admissionLeaf(0, true, 1, context.cell));

        assertEq(bytes4(_readWord(raw, 0)), BEV1);
        assertEq(uint64(uint256(_readWord(raw, 32))), 0);
        assertEq(uint64(uint256(_readWord(raw, 64))), context.window);
        assertEq(address(uint160(uint256(_readWord(raw, 96)))), context.builder);
        assertEq(uint256(_readWord(raw, 128)), REPORTER_CAP);
        assertEq(uint256(_readWord(raw, 160)), LEASE - REPORTER_CAP);
        assertEq(uint64(uint256(_readWord(raw, 192))), 2);
        assertEq(_readWord(raw, 224), context.admissionTree.root());
        (,,,,,, bytes32 registryRoot) = registry.scheduleRegistryStateV1();
        assertEq(registryRoot, context.registryTree.root());
        assertEq(token.rawBalance(address(registry)), uint256(LEASE) * 2);

        _claimAndAssert(reporter, reporter, REPORTER_CAP);
        _claimAndAssert(PENALTY_SINK, PENALTY_SINK, LEASE - REPORTER_CAP);
        assertEq(token.rawBalance(address(registry)), LEASE);
    }

    function _claimAndAssert(address _owner, address _recipient, uint256 _amount) private {
        vm.prank(_owner);
        (bytes4 magic, address recipient, uint256 paid) =
            registry.claimBuilderLeaseCreditV1(_recipient);
        assertEq(magic, BCL1);
        assertEq(recipient, _recipient);
        assertEq(paid, _amount);
    }

    function test_pairEqualForeignSettlementChainRejectsByteIdenticalState() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory foreignEvidence = _evidence(context, block.chainid + 1, L2_CHAIN_ID);
        bytes32 beforeDigest = _stateDigest(context.builder);

        vm.expectRevert(BuilderRegistry.InvalidEvidenceDomain.selector);
        registry.submitBuilderEquivocationV1(foreignEvidence);
        assertEq(_stateDigest(context.builder), beforeDigest);
        assertEq(token.rawBalance(address(registry)), uint256(LEASE) * 2);
    }

    function test_l2ChainIdIsPairEqualButIntentionallyNotRegistryLocal() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory evidence = _evidence(context, block.chainid, type(uint64).max);

        (bytes4 magic,,,,,,,) = registry.submitBuilderEquivocationV1(evidence);
        assertEq(magic, BEV1);
    }

    function test_evidenceOneSecondAfterReplayDeadlineRejectsWithFullRollback() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory evidence = _evidence(context, block.chainid, L2_CHAIN_ID);
        vm.warp(uint256(context.tranche.liableUntil) + 1);
        bytes32 beforeDigest = _stateDigest(context.builder);

        vm.expectRevert(BuilderRegistry.EvidenceTrancheNotSlashable.selector);
        registry.submitBuilderEquivocationV1(evidence);
        assertEq(_stateDigest(context.builder), beforeDigest);
    }

    function test_duplicateAndWrongWindowEvidenceRejectWithoutSecondCredit() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory evidence = _evidence(context, block.chainid, L2_CHAIN_ID);
        registry.submitBuilderEquivocationV1(evidence);
        bytes32 afterFirst = _stateDigest(context.builder);

        vm.expectRevert(BuilderRegistry.EvidenceTrancheNotSlashable.selector);
        registry.submitBuilderEquivocationV1(evidence);
        assertEq(_stateDigest(context.builder), afterFirst);
    }

    function test_wrongWindowAndIndependentHistoricalAdmissionArmsReject() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory evidence = _evidence(context, block.chainid, L2_CHAIN_ID);
        bytes32 beforeDigest = _stateDigest(context.builder);

        bytes memory wrongWindow = _copy(evidence);
        _writeU64(wrongWindow, 1526, context.window + 1);
        _assertVerifierEvidenceFailsWithRollback(wrongWindow, context.builder, beforeDigest);

        bytes memory badHistorical = _copy(evidence);
        badHistorical[1174] ^= 0x01;
        _assertVerifierEvidenceFailsWithRollback(badHistorical, context.builder, beforeDigest);

        bytes memory badCurrent = _copy(evidence);
        badCurrent[1822] ^= 0x01;
        _assertVerifierEvidenceFailsWithRollback(badCurrent, context.builder, beforeDigest);
    }

    function test_evidenceRejectsShortTrailingAndSubstitutedRTR2() external {
        _evidenceRejectsShortTrailingAndSubstitutedRTR2();
    }

    function _evidenceRejectsShortTrailingAndSubstitutedRTR2() internal virtual {
        (bytes memory evidence, address builder) = _preparedEvidence(block.chainid, L2_CHAIN_ID);
        bytes32 beforeDigest = _stateDigest(builder);

        router.setMode(TARGET_RELEASE_REGISTRATION_SELECTOR, 3);
        vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
        _submitEvidence(evidence);
        assertEq(_stateDigest(builder), beforeDigest);

        router.setMode(TARGET_RELEASE_REGISTRATION_SELECTOR, 4);
        vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
        _submitEvidence(evidence);
        assertEq(_stateDigest(builder), beforeDigest);

        router.setMode(TARGET_RELEASE_REGISTRATION_SELECTOR, 0);
        router.setResponse(
            TARGET_RELEASE_REGISTRATION_SELECTOR,
            _targetReleaseRegistration(PROTOCOL_VERSION, address(0xBAD))
        );
        vm.expectRevert(BuilderRegistry.InvalidEvidenceReleaseRegistration.selector);
        _submitEvidence(evidence);
        assertEq(_stateDigest(builder), beforeDigest);
    }

    function _submitEvidence(bytes memory _evidenceBytes) internal virtual {
        registry.submitBuilderEquivocationV1(_evidenceBytes);
    }

    function _preparedEvidence(
        uint256 _settlementChainId,
        uint256 _l2ChainId
    )
        internal
        virtual
        returns (bytes memory evidence_, address builder_)
    {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        evidence_ = _evidence(context, _settlementChainId, _l2ChainId);
        builder_ = context.builder;
    }

    function test_highSSignatureRejectsBeforeAnyRootOrCustodyWrite() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory evidence = _evidence(context, block.chainid, L2_CHAIN_ID);
        uint256 n = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;
        bytes32 s;
        assembly ("memory-safe") {
            s := mload(add(add(evidence, 32), 553))
        }
        _writeWord(evidence, 553, n - uint256(s));
        evidence[585] = evidence[585] == bytes1(uint8(27)) ? bytes1(uint8(28)) : bytes1(uint8(27));
        bytes32 beforeDigest = _stateDigest(context.builder);

        _assertVerifierEvidenceFailsWithRollback(evidence, context.builder, beforeDigest);
    }

    function test_evidenceRejectsLengthPositionTierPairAndOrderSubstitutions() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory evidence = _evidence(context, block.chainid, L2_CHAIN_ID);
        bytes32 beforeDigest = _stateDigest(context.builder);

        bytes memory shortEvidence = new bytes(evidence.length - 1);
        for (uint256 i; i < shortEvidence.length; ++i) {
            shortEvidence[i] = evidence[i];
        }
        vm.expectRevert(BuilderRegistry.InvalidEquivocationEvidence.selector);
        registry.submitBuilderEquivocationV1(shortEvidence);
        vm.expectRevert(BuilderRegistry.InvalidEquivocationEvidence.selector);
        registry.submitBuilderEquivocationV1(bytes.concat(evidence, hex"00"));

        bytes memory badPosition = _copy(evidence);
        badPosition[1172] = bytes1(uint8(1136 >> 8));
        badPosition[1173] = bytes1(uint8(uint16(1136)));
        _assertVerifierEvidenceFailsWithRollback(badPosition, context.builder, beforeDigest);

        bytes memory zeroContext = _copy(evidence);
        _writeWord(zeroContext, 401, 0);
        _writeWord(zeroContext, 987, 0);
        _assertVerifierEvidenceFailsWithRollback(zeroContext, context.builder, beforeDigest);

        bytes memory invalidTier = _copy(evidence);
        invalidTier[400] = 0;
        invalidTier[986] = 0;
        _assertVerifierEvidenceFailsWithRollback(invalidTier, context.builder, beforeDigest);

        bytes memory invalidTierTwo = _copy(evidence);
        invalidTierTwo[400] = bytes1(uint8(2));
        invalidTierTwo[986] = bytes1(uint8(2));
        _assertVerifierEvidenceFailsWithRollback(invalidTierTwo, context.builder, beforeDigest);

        bytes memory mismatchedL2 = _copy(evidence);
        mismatchedL2[649] ^= 0x01;
        _assertVerifierEvidenceFailsWithRollback(mismatchedL2, context.builder, beforeDigest);

        bytes memory reversed = _copy(evidence);
        for (uint256 i; i < 586; ++i) {
            (reversed[i], reversed[586 + i]) = (reversed[586 + i], reversed[i]);
        }
        _assertVerifierEvidenceFailsWithRollback(reversed, context.builder, beforeDigest);
    }

    function test_proofVerifierEvidenceMaskActiveFirstTombstoneReturnsRAT() external {
        _assertProofVerifierEvidenceMask(true, true);
    }

    function test_proofVerifierEvidenceMaskActiveExistingTombstoneReturnsR0T() external {
        _assertProofVerifierEvidenceMask(true, false);
    }

    function test_proofVerifierEvidenceMaskLiabilityFirstTombstoneReturns0AT() external {
        _assertProofVerifierEvidenceMask(false, true);
    }

    function test_proofVerifierEvidenceMaskLiabilityExistingTombstoneReturns00T() external {
        _assertProofVerifierEvidenceMask(false, false);
    }

    function test_proofVerifierIdentityRejectsChainOffsetPaddingSuffixLengthAndValue() external {
        EvidenceContext memory context;
        _prepareEvidenceContext(context);
        bytes memory evidence = _evidence(context, block.chainid, L2_CHAIN_ID);
        BuilderRegistryProofVerifierV1 verifier = new BuilderRegistryProofVerifierV1();
        bytes memory canonical = abi.encodeWithSelector(IDENTITY_SELECTOR, block.chainid, evidence);
        assertEq(canonical.length, 2468);

        _assertVerifierCallFails(
            address(verifier),
            abi.encodeWithSelector(IDENTITY_SELECTOR, block.chainid + 1, evidence),
            0
        );
        bytes memory badOffset = _copy(canonical);
        _writeWord(badOffset, 36, 96);
        _assertVerifierCallFails(address(verifier), badOffset, 0);
        bytes memory dirtyPadding = _copy(canonical);
        dirtyPadding[dirtyPadding.length - 1] = 0x01;
        _assertVerifierCallFails(address(verifier), dirtyPadding, 0);
        _assertVerifierCallFails(address(verifier), bytes.concat(canonical, hex"00"), 0);

        bytes memory shortEvidence = new bytes(2365);
        for (uint256 i; i < shortEvidence.length; ++i) {
            shortEvidence[i] = evidence[i];
        }
        _assertVerifierCallFails(
            address(verifier),
            abi.encodeWithSelector(IDENTITY_SELECTOR, block.chainid, shortEvidence),
            0
        );
        vm.deal(address(this), 1);
        _assertVerifierCallFails(address(verifier), canonical, 1);
    }

    function _assertProofVerifierEvidenceMask(
        bool _activeLocation,
        bool _firstTombstone
    )
        internal
        virtual
    {
        EvidenceMaskContext memory context =
            _prepareEvidenceMaskContext(_activeLocation, _firstTombstone);
        bytes memory request = _evidenceProofRequest(context);
        _assertEvidenceProofResult(context, request, _activeLocation, _firstTombstone);
    }

    function _prepareEvidenceMaskContext(
        bool _activeLocation,
        bool _firstTombstone
    )
        internal
        virtual
        returns (EvidenceMaskContext memory context_)
    {
        _prepareEvidenceContext(context_.evidenceContext);
        context_.evidence = _evidence(context_.evidenceContext, block.chainid, L2_CHAIN_ID);
        context_.verifier = new BuilderRegistryProofVerifierV1();
        context_.verifierConfigurationHash = _verifierConfigurationHash(address(context_.verifier));
        context_.evidenceHash = keccak256(context_.evidence);
        {
            bytes memory identityCalldata =
                abi.encodeWithSelector(IDENTITY_SELECTOR, block.chainid, context_.evidence);
            assertEq(identityCalldata.length, 2468);
            (bool ok, bytes memory identityReturn) =
                address(context_.verifier).staticcall(identityCalldata);
            assertTrue(ok);
            assertEq(identityReturn.length, 320);
            assertEq(bytes4(_readWord(identityReturn, 0)), bytes4(0x45495631));
            assertEq(_readWord(identityReturn, 32), context_.verifierConfigurationHash);
            assertEq(_readWord(identityReturn, 64), context_.evidenceHash);
            context_.identityCommitment = _readWord(identityReturn, 96);
            assertEq(
                address(uint160(uint256(_readWord(identityReturn, 128)))),
                context_.evidenceContext.builder
            );
            assertEq(
                uint64(uint256(_readWord(identityReturn, 160))), context_.evidenceContext.window
            );
            assertEq(uint64(uint256(_readWord(identityReturn, 192))), PROTOCOL_VERSION);
            assertEq(address(uint160(uint256(_readWord(identityReturn, 224)))), ACTIVE_SETTLEMENT);
            assertEq(uint64(uint256(_readWord(identityReturn, 256))), 1);
        }

        context_.currentCell = context_.evidenceContext.cell;
        context_.currentTranche = context_.evidenceContext.tranche;
        context_.location = _activeLocation ? 1 : 2;
        context_.admissionPosition = _activeLocation ? 0 : 64;
        context_.currentL2Slot = context_.evidenceContext.slot;
        context_.reservationBaseWindow = CURRENT_WINDOW;
        context_.reservationBitmap =
            uint32(1) << uint8(context_.evidenceContext.window - CURRENT_WINDOW);
        if (!_activeLocation) {
            context_.currentTranche.state = uint8(SlotChainTypes.TrancheState.LIABLE);
            context_.evidenceContext.trancheTree
                .update(
                    context_.currentTranche.index,
                    BuilderRegistryMerkleTracker.trancheLeaf(context_.currentTranche)
                );
            context_.currentCell.trancheRoot = context_.evidenceContext.trancheTree.root();
            SlotChainTypes.RegistryCellV1 memory emptyCell;
            context_.evidenceContext.registryTree
                .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, false, emptyCell));
            context_.evidenceContext.admissionTree
                .update(0, BuilderRegistryMerkleTracker.admissionLeaf(0, false, 0, emptyCell));
            context_.evidenceContext.admissionTree
                .update(
                    context_.admissionPosition,
                    BuilderRegistryMerkleTracker.admissionLeaf(
                        context_.admissionPosition, true, context_.location, context_.currentCell
                    )
                );
            context_.reservationBaseWindow = context_.evidenceContext.window;
            context_.reservationBitmap = 0;
        }
        if (!_firstTombstone) {
            context_.currentCell.tombstonedAtL2Slot = context_.evidenceContext.slot + 1;
            context_.currentL2Slot = context_.evidenceContext.slot + 2;
            if (_activeLocation) {
                context_.evidenceContext.registryTree
                    .update(
                        0, BuilderRegistryMerkleTracker.registryLeaf(0, true, context_.currentCell)
                    );
            }
            context_.evidenceContext.admissionTree
                .update(
                    context_.admissionPosition,
                    BuilderRegistryMerkleTracker.admissionLeaf(
                        context_.admissionPosition, true, context_.location, context_.currentCell
                    )
                );
        }

        bytes memory currentAdmissionPath = BuilderRegistryMerkleTracker.encodeProof(
            context_.evidenceContext.admissionTree.proof(context_.admissionPosition)
        );
        _replaceBytes(context_.evidence, 1822, currentAdmissionPath);
        if (_activeLocation) {
            _replaceBytes(
                context_.evidence,
                2174,
                BuilderRegistryMerkleTracker.encodeProof(
                    context_.evidenceContext.registryTree.proof(0)
                )
            );
        } else {
            _replaceBytes(context_.evidence, 2174, new bytes(192));
        }
        context_.evidenceHash = keccak256(context_.evidence);
        bytes memory refreshedIdentityCalldata =
            abi.encodeWithSelector(IDENTITY_SELECTOR, block.chainid, context_.evidence);
        (bool refreshedOk, bytes memory refreshedIdentityReturn) =
            address(context_.verifier).staticcall(refreshedIdentityCalldata);
        assertTrue(refreshedOk);
        assertEq(refreshedIdentityReturn.length, 320);
        assertEq(_readWord(refreshedIdentityReturn, 64), context_.evidenceHash);
        context_.identityCommitment = _readWord(refreshedIdentityReturn, 96);
    }

    function _evidenceProofRequest(EvidenceMaskContext memory _context)
        internal
        view
        virtual
        returns (bytes memory request_)
    {
        request_ = bytes.concat(
            abi.encodePacked(
                bytes4(0x42505231),
                uint8(4),
                _context.evidence,
                uint256(block.chainid),
                _context.evidenceHash,
                _context.identityCommitment,
                _context.evidenceContext.builder,
                uint64(0),
                _context.location,
                _context.admissionPosition,
                _context.currentL2Slot
            ),
            abi.encodePacked(
                _context.evidenceContext.registryTree.root(),
                _context.evidenceContext.admissionTree.root(),
                _registryCell(_context.currentCell),
                _context.reservationBaseWindow,
                _context.reservationBitmap,
                uint16(1),
                _trancheLeaf(_context.currentTranche)
            )
        );
        assertEq(request_.length, 2727);
    }

    function _assertEvidenceProofResult(
        EvidenceMaskContext memory _context,
        bytes memory _request,
        bool _activeLocation,
        bool _firstTombstone
    )
        internal
        view
        virtual
    {
        bytes32 expectedRegistryRoot;
        bytes32 expectedAdmissionRoot;
        _context.currentTranche.state = uint8(SlotChainTypes.TrancheState.SLASHED);
        _context.currentTranche.amount = 0;
        _context.evidenceContext.trancheTree
            .update(
                _context.currentTranche.index,
                BuilderRegistryMerkleTracker.trancheLeaf(_context.currentTranche)
            );
        bytes32 expectedTrancheRoot = _context.evidenceContext.trancheTree.root();
        uint64 expectedTombstone = _context.currentCell.tombstonedAtL2Slot;
        if (_firstTombstone) expectedTombstone = _context.currentL2Slot;
        SlotChainTypes.RegistryCellV1 memory nextCell = SlotChainTypes.RegistryCellV1({
            builder: _context.currentCell.builder,
            bond: _context.currentCell.bond,
            registrationIndex: _context.currentCell.registrationIndex,
            effectiveL2Slot: _context.currentCell.effectiveL2Slot,
            trancheRoot: expectedTrancheRoot,
            tombstonedAtL2Slot: expectedTombstone
        });
        if (_activeLocation) {
            _context.evidenceContext.registryTree
                .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, nextCell));
            expectedRegistryRoot = _context.evidenceContext.registryTree.root();
        }
        if (_firstTombstone) {
            _context.evidenceContext.admissionTree
                .update(
                    _context.admissionPosition,
                    BuilderRegistryMerkleTracker.admissionLeaf(
                        _context.admissionPosition, true, _context.location, nextCell
                    )
                );
            expectedAdmissionRoot = _context.evidenceContext.admissionTree.root();
        }

        (bool ok, bytes memory proofReturn) =
            address(_context.verifier).staticcall(abi.encodeWithSelector(PROOF_SELECTOR, _request));
        assertTrue(ok);
        assertEq(proofReturn.length, 192);
        assertEq(bytes4(_readWord(proofReturn, 0)), bytes4(0x42504f31));
        assertEq(_readWord(proofReturn, 32), _context.verifierConfigurationHash);
        assertEq(
            _readWord(proofReturn, 64),
            keccak256(
                abi.encodePacked(
                    "slot-chain-builder-proof-request-v1", uint32(_request.length), _request
                )
            )
        );
        assertEq(_readWord(proofReturn, 96), expectedRegistryRoot);
        assertEq(_readWord(proofReturn, 128), expectedAdmissionRoot);
        assertEq(_readWord(proofReturn, 160), expectedTrancheRoot);
    }

    function _prepareEvidenceContext(EvidenceContext memory context_) internal virtual {
        _initializeEvidenceContext(context_);
        _reserveEvidenceWindow(context_);
        _assertEvidenceContextStorage(context_);
        vm.warp(uint256(GENESIS) + context_.slot);
        router.setResponse(
            TARGET_RELEASE_REGISTRATION_SELECTOR,
            _targetReleaseRegistration(PROTOCOL_VERSION, ACTIVE_SETTLEMENT)
        );
    }

    function _initializeEvidenceContext(EvidenceContext memory context_) internal virtual {
        context_.registryTree = BuilderRegistryMerkleTracker.emptyRegistryTree();
        context_.admissionTree = BuilderRegistryMerkleTracker.emptyAdmissionTree();
        context_.trancheTree = BuilderRegistryMerkleTracker.emptyTrancheTree();
        context_.builder = vm.addr(BUILDER_KEY);
        context_.window = CURRENT_WINDOW + 8;
        context_.slot = context_.window * 384 + 37;
        context_.cell = _registerVacant(
            context_.registryTree,
            context_.admissionTree,
            context_.trancheTree,
            context_.builder,
            LEASE,
            0,
            0
        );
    }

    function _reserveEvidenceWindow(EvidenceContext memory context_) internal virtual {
        bytes memory reserveWitness = bytes.concat(
            hex"00",
            BuilderRegistryMerkleTracker.encodeProof(
                context_.trancheTree.proof(uint16(context_.window % 512))
            ),
            BuilderRegistryMerkleTracker.encodeProof(context_.registryTree.proof(0))
        );
        _fundAndApprove(context_.builder, LEASE);
        vm.prank(context_.builder);
        registry.reserveBuilderWindowV1(0, context_.window, reserveWitness);

        context_.tranche = SlotChainTypes.TrancheLeafV1({
            index: uint16(context_.window % 512),
            window: context_.window,
            state: uint8(SlotChainTypes.TrancheState.RESERVED),
            amount: LEASE,
            liableUntil: GENESIS + 384 * (context_.window + 1) + EVIDENCE_DELAY + REORG_MARGIN
        });
        context_.trancheTree
            .update(
                context_.tranche.index, BuilderRegistryMerkleTracker.trancheLeaf(context_.tranche)
            );
        context_.cell.trancheRoot = context_.trancheTree.root();
        context_.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, context_.cell));
    }

    function _assertEvidenceContextStorage(EvidenceContext memory context_) internal view virtual {
        (,,,,,, bytes32 registryRoot) = registry.scheduleRegistryStateV1();
        (, uint64 admissionVersion, bytes32 admissionRoot) = registry.admissionStateV1();
        assertEq(registryRoot, context_.registryTree.root());
        assertEq(admissionVersion, 1);
        assertEq(admissionRoot, context_.admissionTree.root());
        assertEq(vm.load(address(registry), bytes32(uint256(42))), context_.trancheTree.root());
        bytes32 trancheBase = keccak256(abi.encode(uint256(0), uint256(6857)));
        uint256 trancheSlot = uint256(keccak256(abi.encode(context_.tranche.index, trancheBase)));
        uint256 packedTranche = uint256(vm.load(address(registry), bytes32(trancheSlot)));
        assertEq(uint16(packedTranche), context_.tranche.index);
        assertEq(uint64(packedTranche >> 16), context_.tranche.window);
        assertEq(uint8(packedTranche >> 80), context_.tranche.state);
        uint256 packedAmount = uint256(vm.load(address(registry), bytes32(trancheSlot + 1)));
        assertEq(uint192(packedAmount), context_.tranche.amount);
        assertEq(uint64(packedAmount >> 192), context_.tranche.liableUntil);
        bytes32[] memory dynamicTranchePath = context_.trancheTree.proof(context_.tranche.index);
        bytes32[9] memory tranchePath;
        for (uint256 i; i < 9; ++i) {
            tranchePath[i] = dynamicTranchePath[i];
        }
        assertEq(
            LibSlotChainFixedTrees.computeTrancheRoot(
                context_.tranche.index,
                BuilderRegistryMerkleTracker.trancheLeaf(context_.tranche),
                tranchePath
            ),
            context_.trancheTree.root()
        );
    }

    function _evidence(
        EvidenceContext memory _context,
        uint256 _settlementChainId,
        uint256 _l2ChainId
    )
        internal
        virtual
        returns (bytes memory evidence_)
    {
        SignedEvidenceBlocks memory pair =
            _signedEvidenceBlocks(_context, _settlementChainId, _l2ChainId);
        evidence_ = _encodeEvidence(_context, pair);
        assertEq(evidence_.length, 2366);
        _assertEvidencePathsAndTransitions(_context, evidence_);
    }

    function _encodeEvidence(
        EvidenceContext memory _context,
        SignedEvidenceBlocks memory _pair
    )
        internal
        pure
        virtual
        returns (bytes memory encoded_)
    {
        bytes memory admissionProof =
            BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(0));
        bytes memory trancheProof = BuilderRegistryMerkleTracker.encodeProof(
            _context.trancheTree.proof(uint16(_context.window % 512))
        );
        bytes memory registryProof =
            BuilderRegistryMerkleTracker.encodeProof(_context.registryTree.proof(0));
        bytes memory signedPair = bytes.concat(
            _pack(_pair.a),
            abi.encodePacked(_pair.rA, _pair.sA, _pair.vA),
            _pack(_pair.b),
            abi.encodePacked(_pair.rB, _pair.sB, _pair.vB),
            abi.encodePacked(uint16(0))
        );
        bytes memory witness = bytes.concat(
            admissionProof,
            abi.encodePacked(_context.window),
            trancheProof,
            admissionProof,
            registryProof
        );
        encoded_ = bytes.concat(signedPair, witness);
    }

    function _signedEvidenceBlocks(
        EvidenceContext memory _context,
        uint256 _settlementChainId,
        uint256 _l2ChainId
    )
        internal
        virtual
        returns (SignedEvidenceBlocks memory pair_)
    {
        pair_.a = _block(
            _context, _settlementChainId, _l2ChainId, keccak256("block-a"), keccak256("state-a")
        );
        pair_.b = _block(
            _context, _settlementChainId, _l2ChainId, keccak256("block-b"), keccak256("state-b")
        );
        if (
            uint256(LibSlotChainEncoding.hashSlotChainBlock(pair_.a))
                >= uint256(LibSlotChainEncoding.hashSlotChainBlock(pair_.b))
        ) {
            (pair_.a, pair_.b) = (pair_.b, pair_.a);
        }
        bytes32 digestA = LibSlotChainEncoding.hashSlotChainDigest(
            pair_.a.settlementChainId, pair_.a.verifyingContract, pair_.a
        );
        bytes32 digestB = LibSlotChainEncoding.hashSlotChainDigest(
            pair_.b.settlementChainId, pair_.b.verifyingContract, pair_.b
        );
        (pair_.vA, pair_.rA, pair_.sA) = vm.sign(BUILDER_KEY, digestA);
        (pair_.vB, pair_.rB, pair_.sB) = vm.sign(BUILDER_KEY, digestB);
    }

    function _assertEvidencePathsAndTransitions(
        EvidenceContext memory _context,
        bytes memory _encodedEvidence
    )
        internal
        pure
        virtual
    {
        bytes32[] memory tranchePath = _context.trancheTree.proof(uint16(_context.window % 512));
        bytes32[] memory admissionPath = _context.admissionTree.proof(0);
        bytes32[] memory registryPath = _context.registryTree.proof(0);
        bytes32[9] memory fixedTranchePath;
        bytes32[6] memory fixedRegistryPath;
        for (uint256 i; i < 9; ++i) {
            assertEq(_readWord(_encodedEvidence, 1534 + 32 * i), tranchePath[i]);
            fixedTranchePath[i] = tranchePath[i];
        }
        for (uint256 i; i < 11; ++i) {
            assertEq(_readWord(_encodedEvidence, 1174 + 32 * i), admissionPath[i]);
            assertEq(_readWord(_encodedEvidence, 1822 + 32 * i), admissionPath[i]);
        }
        for (uint256 i; i < 6; ++i) {
            assertEq(_readWord(_encodedEvidence, 2174 + 32 * i), registryPath[i]);
            fixedRegistryPath[i] = registryPath[i];
        }
        SlotChainTypes.TrancheLeafV1 memory slashed = SlotChainTypes.TrancheLeafV1({
            index: _context.tranche.index,
            window: _context.tranche.window,
            state: uint8(SlotChainTypes.TrancheState.SLASHED),
            amount: 0,
            liableUntil: _context.tranche.liableUntil
        });
        LibSlotChainFixedTrees.updateTrancheRoot(
            _context.trancheTree.root(),
            _context.tranche.index,
            BuilderRegistryMerkleTracker.trancheLeaf(_context.tranche),
            BuilderRegistryMerkleTracker.trancheLeaf(slashed),
            fixedTranchePath
        );
        SlotChainTypes.RegistryCellV1 memory tombstoned = SlotChainTypes.RegistryCellV1({
            builder: _context.cell.builder,
            bond: _context.cell.bond,
            registrationIndex: _context.cell.registrationIndex,
            effectiveL2Slot: _context.cell.effectiveL2Slot,
            trancheRoot: _context.cell.trancheRoot,
            tombstonedAtL2Slot: _context.slot
        });
        LibSlotChainFixedTrees.updateRegistryRoot(
            _context.registryTree.root(),
            0,
            BuilderRegistryMerkleTracker.registryLeaf(0, true, _context.cell),
            BuilderRegistryMerkleTracker.registryLeaf(0, true, tombstoned),
            fixedRegistryPath
        );
    }

    function _block(
        EvidenceContext memory _context,
        uint256 _settlementChainId,
        uint256 _l2ChainId,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        internal
        pure
        virtual
        returns (SlotChainTypes.SlotChainBlock memory block_)
    {
        block_ = SlotChainTypes.SlotChainBlock({
            settlementChainId: _settlementChainId,
            l2ChainId: _l2ChainId,
            protocolVersion: PROTOCOL_VERSION,
            verifyingContract: ACTIVE_SETTLEMENT,
            slot: _context.slot,
            parentHash: keccak256("parent"),
            blockHash: _blockHash,
            stateRoot: _stateRoot,
            bodyRoot: keccak256("body"),
            anchorNumber: 100,
            anchorHash: keccak256("anchor"),
            forceRoot: keccak256("force"),
            forceCutoff: 5,
            messageStart: 10,
            messageEnd: 12,
            dataManifestRoot: keccak256("manifest"),
            coinbase: address(0xCAFE),
            tier: 1,
            contextId: keccak256("context"),
            admissionVersion: 1,
            admissionRoot: _context.admissionTree.root(),
            episode: 0,
            recoveryRevision: 0,
            recoveryId: bytes32(0)
        });
    }

    function _pack(SlotChainTypes.SlotChainBlock memory _value)
        internal
        pure
        virtual
        returns (bytes memory encoded_)
    {
        encoded_ = bytes.concat(
            abi.encodePacked(
                _value.settlementChainId,
                _value.l2ChainId,
                _value.protocolVersion,
                _value.verifyingContract,
                _value.slot,
                _value.parentHash,
                _value.blockHash,
                _value.stateRoot
            ),
            abi.encodePacked(
                _value.bodyRoot,
                _value.anchorNumber,
                _value.anchorHash,
                _value.forceRoot,
                _value.forceCutoff,
                _value.messageStart,
                _value.messageEnd,
                _value.dataManifestRoot
            ),
            abi.encodePacked(
                _value.coinbase,
                _value.tier,
                _value.contextId,
                _value.admissionVersion,
                _value.admissionRoot,
                _value.episode,
                _value.recoveryRevision,
                _value.recoveryId
            )
        );
        assert(encoded_.length == 521);
    }

    function _targetReleaseRegistration(
        uint64 _version,
        address _settlement
    )
        internal
        pure
        virtual
        returns (bytes memory encoded_)
    {
        encoded_ = new bytes(512);
        _writeWord(encoded_, 0, uint256(bytes32(bytes4(0x52545232))));
        _writeWord(encoded_, 32, _version);
        _writeWord(encoded_, 64, _version - 1);
        _writeWord(encoded_, 96, uint256(uint160(_settlement)));
        _writeWord(encoded_, 128, uint256(keccak256("settlement-runtime")));
        _writeWord(encoded_, 160, uint256(keccak256("settlement-config")));
        _writeWord(encoded_, 192, uint256(keccak256("deployment-descriptor")));
        _writeWord(encoded_, 224, uint256(keccak256("execution-profile")));
        _writeWord(encoded_, 256, 50_000);
        _writeWord(encoded_, 288, uint256(keccak256("migration-profile")));
        _writeWord(encoded_, 320, uint256(keccak256("data-session-config")));
        _writeWord(encoded_, 352, uint256(keccak256("release-manifest")));
        _writeWord(encoded_, 384, uint256(keccak256("bridge-expansion")));
        _writeWord(encoded_, 416, uint256(keccak256("validity-descriptor")));
        _writeWord(encoded_, 448, uint256(keccak256("ingress-id")));
        _writeWord(encoded_, 480, uint256(keccak256("registration-hash")));
    }

    function _copy(bytes memory _input) private pure returns (bytes memory output_) {
        output_ = bytes.concat(_input);
    }

    function _registryCell(SlotChainTypes.RegistryCellV1 memory _cellValue)
        internal
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encodePacked(
            _cellValue.builder,
            _cellValue.bond,
            _cellValue.registrationIndex,
            _cellValue.effectiveL2Slot,
            _cellValue.trancheRoot,
            _cellValue.tombstonedAtL2Slot
        );
    }

    function _trancheLeaf(SlotChainTypes.TrancheLeafV1 memory _leafValue)
        internal
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encodePacked(
            _leafValue.index,
            _leafValue.window,
            _leafValue.state,
            _leafValue.amount,
            _leafValue.liableUntil
        );
    }

    function _verifierConfigurationHash(address _verifier) private view returns (bytes32 hash_) {
        (bool ok, bytes memory raw) = _verifier.staticcall(hex"f6c0f7d2");
        assertTrue(ok);
        assertEq(raw.length, 32);
        hash_ = _readWord(raw, 0);
    }

    function _replaceBytes(
        bytes memory _target,
        uint256 _offset,
        bytes memory _source
    )
        private
        pure
    {
        assert(_offset + _source.length <= _target.length);
        for (uint256 i; i < _source.length; ++i) {
            _target[_offset + i] = _source[i];
        }
    }

    function _assertVerifierCallFails(
        address _target,
        bytes memory _calldata,
        uint256 _value
    )
        private
    {
        (bool ok,) = _target.call{ value: _value }(_calldata);
        assertFalse(ok);
    }

    function _assertVerifierEvidenceFailsWithRollback(
        bytes memory _evidenceBytes,
        address _builder,
        bytes32 _beforeDigest
    )
        private
    {
        (bool ok,) = address(registry)
            .call(abi.encodeCall(IBuilderRegistry.submitBuilderEquivocationV1, (_evidenceBytes)));
        assertFalse(ok);
        assertEq(_stateDigest(_builder), _beforeDigest);
    }

    function _writeU64(bytes memory _encoded, uint256 _offset, uint64 _value) private pure {
        for (uint256 i; i < 8; ++i) {
            _encoded[_offset + i] = bytes1(uint8(_value >> (56 - 8 * i)));
        }
    }

    function _writeWord(
        bytes memory _encoded,
        uint256 _offset,
        uint256 _value
    )
        private
        pure
    {
        assembly ("memory-safe") {
            mstore(add(add(_encoded, 32), _offset), _value)
        }
    }

    function _readWord(
        bytes memory _encoded,
        uint256 _offset
    )
        private
        pure
        returns (bytes32 value_)
    {
        assembly ("memory-safe") {
            value_ := mload(add(add(_encoded, 32), _offset))
        }
    }
}
