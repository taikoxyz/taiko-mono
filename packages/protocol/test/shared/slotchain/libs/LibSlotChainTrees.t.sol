// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import {
    LibSlotChainDataMmr
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainDataMmr.sol";
import {
    LibSlotChainDepth64
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainDepth64.sol";
import {
    LibSlotChainEncoding
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainEncoding.sol";
import {
    LibSlotChainFixedTrees
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainFixedTrees.sol";
import {
    LibSlotChainManifestTree
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainManifestTree.sol";
import { SlotChainGoldenVectors } from "../vectors/SlotChainGoldenVectors.sol";
import { Test } from "forge-std/src/Test.sol";

contract SlotChainTreesHarness {
    bytes32[64] private _forcedFrontier;
    bytes32[64] private _terminalFrontier;
    bytes32[12] private _dataPeaks;

    function emptyRegistryRoot() external pure returns (bytes32) {
        return LibSlotChainFixedTrees.emptyRegistryRoot();
    }

    function emptyAdmissionRoot() external pure returns (bytes32) {
        return LibSlotChainFixedTrees.emptyAdmissionRoot();
    }

    function emptyRankedEntryRoot() external pure returns (bytes32) {
        return LibSlotChainFixedTrees.emptyRankedEntryRoot();
    }

    function emptyTrancheRoot() external pure returns (bytes32) {
        return LibSlotChainFixedTrees.emptyTrancheRoot();
    }

    function registryRoot(bytes32[64] memory _leaves) external pure returns (bytes32) {
        return LibSlotChainFixedTrees.registryRoot(_leaves);
    }

    function rankedEntryRoot(bytes32[64] memory _leaves) external pure returns (bytes32) {
        return LibSlotChainFixedTrees.rankedEntryRoot(_leaves);
    }

    function computeRegistryRoot(
        uint8 _index,
        bytes32 _leaf,
        bytes32[6] memory _siblings
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainFixedTrees.computeRegistryRoot(_index, _leaf, _siblings);
    }

    function computeRankedEntryRoot(
        uint8 _index,
        bytes32 _leaf,
        bytes32[6] memory _siblings
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainFixedTrees.computeRankedEntryRoot(_index, _leaf, _siblings);
    }

    function computeAdmissionRoot(
        uint16 _index,
        bytes32 _leaf,
        bytes32[11] memory _siblings
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainFixedTrees.computeAdmissionRoot(_index, _leaf, _siblings);
    }

    function computeTrancheRoot(
        uint16 _index,
        bytes32 _leaf,
        bytes32[9] memory _siblings
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainFixedTrees.computeTrancheRoot(_index, _leaf, _siblings);
    }

    function updateRegistryRoot(
        bytes32 _expectedRoot,
        uint8 _index,
        bytes32 _oldLeaf,
        bytes32 _newLeaf,
        bytes32[6] memory _siblings
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainFixedTrees.updateRegistryRoot(
            _expectedRoot, _index, _oldLeaf, _newLeaf, _siblings
        );
    }

    function updateAdmissionUsedRoot(
        bytes32 _expectedRoot,
        uint16 _index,
        bytes32 _oldLeaf,
        bytes32 _newLeaf,
        bytes32[11] memory _siblings
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainFixedTrees.updateAdmissionUsedRoot(
            _expectedRoot, _index, _oldLeaf, _newLeaf, _siblings
        );
    }

    function updateRankedEntryRoot(
        bytes32 _expectedRoot,
        uint8 _index,
        bytes32 _oldLeaf,
        bytes32 _newLeaf,
        bytes32[6] memory _siblings
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainFixedTrees.updateRankedEntryRoot(
            _expectedRoot, _index, _oldLeaf, _newLeaf, _siblings
        );
    }

    function updateTrancheRoot(
        bytes32 _expectedRoot,
        uint16 _index,
        bytes32 _oldLeaf,
        bytes32 _newLeaf,
        bytes32[9] memory _siblings
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainFixedTrees.updateTrancheRoot(
            _expectedRoot, _index, _oldLeaf, _newLeaf, _siblings
        );
    }

    function setForcedFrontier(uint8 _height, bytes32 _node) external {
        _forcedFrontier[_height] = _node;
    }

    function setTerminalFrontier(uint8 _height, bytes32 _node) external {
        _terminalFrontier[_height] = _node;
    }

    function setDataPeak(uint8 _height, bytes32 _node) external {
        _dataPeaks[_height] = _node;
    }

    function forcedFrontier() external view returns (bytes32[64] memory frontier_) {
        for (uint8 height; height < 64; ++height) {
            frontier_[height] = _forcedFrontier[height];
        }
    }

    function terminalFrontier() external view returns (bytes32[64] memory frontier_) {
        for (uint8 height; height < 64; ++height) {
            frontier_[height] = _terminalFrontier[height];
        }
    }

    function dataPeaks() external view returns (bytes32[12] memory peaks_) {
        for (uint8 height; height < 12; ++height) {
            peaks_[height] = _dataPeaks[height];
        }
    }

    function previewForcedAppend(
        uint64 _count,
        bytes32 _leaf
    )
        external
        view
        returns (uint8, bytes32, uint64, bytes32)
    {
        return LibSlotChainDepth64.previewForcedAppend(_forcedFrontier, _count, _leaf);
    }

    function applyForcedAppend(
        uint64 _count,
        bytes32 _leaf
    )
        external
        returns (uint8 writeHeight_, bytes32 carriedNode_, uint64 newCount_, bytes32 newRoot_)
    {
        (writeHeight_, carriedNode_, newCount_, newRoot_) =
            LibSlotChainDepth64.previewForcedAppend(_forcedFrontier, _count, _leaf);
        _forcedFrontier[writeHeight_] = carriedNode_;
    }

    function forcedRoot(uint64 _count) external view returns (bytes32) {
        return LibSlotChainDepth64.forcedRoot(_forcedFrontier, _count);
    }

    function verifyForcedRange(
        uint64 _count,
        uint64 _start,
        bytes32[] calldata _revealed,
        bytes32[] calldata _proof,
        bytes32 _expectedRoot
    )
        external
        pure
        returns (bool)
    {
        return
            LibSlotChainDepth64.verifyForcedRange(_count, _start, _revealed, _proof, _expectedRoot);
    }

    function previewTerminalAppend(
        uint64 _count,
        bytes32 _leaf
    )
        external
        view
        returns (uint8, bytes32, uint64, bytes32)
    {
        return LibSlotChainDepth64.previewTerminalAppend(_terminalFrontier, _count, _leaf);
    }

    function applyTerminalAppend(
        uint64 _count,
        bytes32 _leaf
    )
        external
        returns (uint8 writeHeight_, bytes32 carriedNode_, uint64 newCount_, bytes32 newRoot_)
    {
        (writeHeight_, carriedNode_, newCount_, newRoot_) =
            LibSlotChainDepth64.previewTerminalAppend(_terminalFrontier, _count, _leaf);
        _terminalFrontier[writeHeight_] = carriedNode_;
    }

    function terminalRoot(uint64 _count) external view returns (bytes32) {
        return LibSlotChainDepth64.terminalRoot(_terminalFrontier, _count);
    }

    function verifyTerminalInclusion(
        uint64 _count,
        uint64 _index,
        bytes32 _leaf,
        bytes32[64] memory _siblings,
        bytes32 _expectedRoot
    )
        external
        pure
        returns (bool)
    {
        return LibSlotChainDepth64.verifyTerminalInclusion(
            _count, _index, _leaf, _siblings, _expectedRoot
        );
    }

    function previewDataAppend(
        uint16 _count,
        bytes32 _leaf
    )
        external
        view
        returns (uint8, bytes32, uint16, bytes32)
    {
        return LibSlotChainDataMmr.previewAppend(_dataPeaks, _count, _leaf);
    }

    function applyDataAppend(
        uint16 _count,
        bytes32 _leaf
    )
        external
        returns (uint8 writeHeight_, bytes32 carriedPeak_, uint16 newCount_, bytes32 newRoot_)
    {
        (writeHeight_, carriedPeak_, newCount_, newRoot_) =
            LibSlotChainDataMmr.previewAppend(_dataPeaks, _count, _leaf);
        _dataPeaks[writeHeight_] = carriedPeak_;
    }

    function dataRoot(uint16 _count) external view returns (bytes32) {
        return LibSlotChainDataMmr.root(_dataPeaks, _count);
    }

    function verifyDataInclusion(
        uint16 _count,
        uint16 _index,
        bytes32 _leaf,
        bytes32[] calldata _mountainSiblings,
        bytes32[] calldata _otherPeaks,
        bytes32 _expectedRoot
    )
        external
        pure
        returns (bool)
    {
        return LibSlotChainDataMmr.verifyInclusion(
            _count, _index, _leaf, _mountainSiblings, _otherPeaks, _expectedRoot
        );
    }

    function hashRegistryNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainEncoding.hashRegistryNode(_height, _left, _right);
    }

    function hashAdmissionNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainEncoding.hashAdmissionNode(_height, _left, _right);
    }

    function hashRankedEntryNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainEncoding.hashRankedEntryNode(_height, _left, _right);
    }

    function hashTrancheNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainEncoding.hashTrancheNode(_height, _left, _right);
    }

    function hashForcedNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainEncoding.hashForcedNode(_height, _left, _right);
    }

    function hashDataNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainEncoding.hashDataNode(_height, _left, _right);
    }

    function hashManifestNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainEncoding.hashManifestNode(_height, _left, _right);
    }

    function hashTerminalNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainEncoding.hashTerminalNode(_height, _left, _right);
    }

    function manifestRoot(
        uint16 _expectedBlockOrdinal,
        SlotChainTypes.ManifestEntryV1[] calldata _entries
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainManifestTree.root(_expectedBlockOrdinal, _entries);
    }
}

contract LibSlotChainTreesTest is Test {
    string private constant REGISTRY_NODE_DOMAIN = "slot-chain-registry-node-v1";
    string private constant ADMISSION_NODE_DOMAIN = "slot-chain-admission-node-v1";
    string private constant ENTRY_NODE_DOMAIN = "slot-chain-entry-node-v1";
    string private constant TRANCHE_NODE_DOMAIN = "slot-chain-tranche-node-v1";
    string private constant FORCE_NODE_DOMAIN = "slot-chain-force-node-v2";
    string private constant TERMINAL_NODE_DOMAIN = "slot-chain-terminal-node-v2";
    string private constant DATA_NODE_DOMAIN = "slot-chain-data-node-v1";
    string private constant MANIFEST_NODE_DOMAIN = "slot-chain-manifest-node-v1";

    struct RangeProofBuilder {
        uint256 count;
        uint256 start;
        uint256 end;
        uint256 cursor;
        bytes32[] leaves;
        bytes32[] empty;
        bytes32[] proof;
    }

    SlotChainTreesHarness private harness;

    function setUp() external {
        harness = new SlotChainTreesHarness();
    }

    function test_fixedTrees_PinAllReviewedRootsAndProofVectors() external view {
        (bytes32[64] memory registryLeaves, bytes32 registryLeaf) = _registryFixture();
        bytes32[] memory registryDynamic = _dynamic64(registryLeaves);
        bytes32[] memory registryProof = _fixedProof(registryDynamic, 3, REGISTRY_NODE_DOMAIN);
        bytes32[6] memory registrySiblings = _fixed6(registryProof);

        assertEq(harness.emptyRegistryRoot(), SlotChainGoldenVectors.EMPTY_REGISTRY_ROOT);
        assertEq(harness.emptyRegistryRoot(), _emptyRegistryRootOracle());
        assertEq(harness.registryRoot(registryLeaves), SlotChainGoldenVectors.REGISTRY_ROOT);
        assertEq(
            keccak256(abi.encodePacked(registryProof)), SlotChainGoldenVectors.REGISTRY_PROOF_DIGEST
        );
        assertEq(
            harness.computeRegistryRoot(3, registryLeaf, registrySiblings),
            SlotChainGoldenVectors.REGISTRY_ROOT
        );

        (bytes32[] memory admissionLeaves, bytes32 admissionLeaf) = _admissionFixture();
        bytes32[] memory admissionProof = _fixedProof(admissionLeaves, 64, ADMISSION_NODE_DOMAIN);
        assertEq(harness.emptyAdmissionRoot(), SlotChainGoldenVectors.EMPTY_ADMISSION_ROOT);
        assertEq(harness.emptyAdmissionRoot(), _emptyAdmissionRootOracle());
        assertEq(
            keccak256(abi.encodePacked(admissionProof)),
            SlotChainGoldenVectors.ADMISSION_PROOF_DIGEST
        );
        assertEq(
            harness.computeAdmissionRoot(64, admissionLeaf, _fixed11(admissionProof)),
            SlotChainGoldenVectors.ADMISSION_ROOT
        );

        (bytes32[64] memory entryLeaves, bytes32 entryLeaf) = _entryFixture();
        bytes32[] memory entryProof = _fixedProof(_dynamic64(entryLeaves), 0, ENTRY_NODE_DOMAIN);
        assertEq(harness.emptyRankedEntryRoot(), SlotChainGoldenVectors.EMPTY_ENTRY_ROOT);
        assertEq(harness.emptyRankedEntryRoot(), _emptyEntryRootOracle());
        assertEq(harness.rankedEntryRoot(entryLeaves), SlotChainGoldenVectors.ENTRY_ROOT);
        assertEq(keccak256(abi.encodePacked(entryProof)), SlotChainGoldenVectors.ENTRY_PROOF_DIGEST);
        assertEq(
            harness.computeRankedEntryRoot(0, entryLeaf, _fixed6(entryProof)),
            SlotChainGoldenVectors.ENTRY_ROOT
        );

        (bytes32[] memory trancheLeaves, bytes32 trancheLeaf) = _trancheFixture();
        bytes32[] memory trancheProof = _fixedProof(trancheLeaves, 7, TRANCHE_NODE_DOMAIN);
        assertEq(harness.emptyTrancheRoot(), SlotChainGoldenVectors.EMPTY_TRANCHE_ROOT);
        assertEq(harness.emptyTrancheRoot(), _emptyTrancheRootOracle());
        assertEq(
            keccak256(abi.encodePacked(trancheProof)), SlotChainGoldenVectors.TRANCHE_PROOF_DIGEST
        );
        assertEq(
            harness.computeTrancheRoot(7, trancheLeaf, _fixed9(trancheProof)),
            SlotChainGoldenVectors.TRANCHE_ROOT
        );
    }

    function test_fixedTrees_FirstLastAndAdmissionUsedBoundaries() external view {
        _assertFixedBoundary(0, 6, REGISTRY_NODE_DOMAIN, false);
        _assertFixedBoundary(63, 6, REGISTRY_NODE_DOMAIN, false);
        _assertFixedBoundary(0, 6, ENTRY_NODE_DOMAIN, true);
        _assertFixedBoundary(63, 6, ENTRY_NODE_DOMAIN, true);
        _assertAdmissionBoundary(0);
        _assertAdmissionBoundary(1135);
        _assertAdmissionBoundary(1136);
        _assertAdmissionBoundary(2047);
        _assertTrancheBoundary(0);
        _assertTrancheBoundary(511);
    }

    function test_fixedTrees_RevertWhen_IndexIsOutsideTree() external {
        bytes32[6] memory six;
        bytes32[11] memory eleven;
        bytes32[9] memory nine;

        vm.expectRevert(LibSlotChainFixedTrees.InvalidTreeIndex.selector);
        harness.computeRegistryRoot(64, bytes32(0), six);
        vm.expectRevert(LibSlotChainFixedTrees.InvalidTreeIndex.selector);
        harness.computeRankedEntryRoot(64, bytes32(0), six);
        vm.expectRevert(LibSlotChainFixedTrees.InvalidTreeIndex.selector);
        harness.computeAdmissionRoot(2048, bytes32(0), eleven);
        vm.expectRevert(LibSlotChainFixedTrees.InvalidTreeIndex.selector);
        harness.computeTrancheRoot(512, bytes32(0), nine);

        bytes32 oldLeaf = keccak256("old");
        bytes32 root = harness.computeAdmissionRoot(1136, oldLeaf, eleven);
        vm.expectRevert(LibSlotChainFixedTrees.InvalidTreeIndex.selector);
        harness.updateAdmissionUsedRoot(root, 1136, oldLeaf, keccak256("new"), eleven);
    }

    function test_fixedTrees_UpdateHelpersVerifyOldRoot() external {
        bytes32 oldLeaf = keccak256("old-leaf");
        bytes32 newLeaf = keccak256("new-leaf");
        bytes32[6] memory six;
        bytes32[11] memory eleven;
        bytes32[9] memory nine;
        for (uint256 i; i < 11; ++i) {
            eleven[i] = keccak256(abi.encodePacked("admission-sibling", i));
            if (i < 9) nine[i] = keccak256(abi.encodePacked("tranche-sibling", i));
            if (i < 6) six[i] = keccak256(abi.encodePacked("six-sibling", i));
        }

        bytes32 registryRoot = harness.computeRegistryRoot(17, oldLeaf, six);
        assertEq(
            harness.updateRegistryRoot(registryRoot, 17, oldLeaf, newLeaf, six),
            _computeRootOracle(17, newLeaf, _dynamic6(six), REGISTRY_NODE_DOMAIN)
        );
        bytes32 entryRoot = harness.computeRankedEntryRoot(17, oldLeaf, six);
        assertEq(
            harness.updateRankedEntryRoot(entryRoot, 17, oldLeaf, newLeaf, six),
            _computeRootOracle(17, newLeaf, _dynamic6(six), ENTRY_NODE_DOMAIN)
        );
        bytes32 admissionRoot = harness.computeAdmissionRoot(1135, oldLeaf, eleven);
        assertEq(
            harness.updateAdmissionUsedRoot(admissionRoot, 1135, oldLeaf, newLeaf, eleven),
            _computeRootOracle(1135, newLeaf, _dynamic11(eleven), ADMISSION_NODE_DOMAIN)
        );
        bytes32 trancheRoot = harness.computeTrancheRoot(511, oldLeaf, nine);
        assertEq(
            harness.updateTrancheRoot(trancheRoot, 511, oldLeaf, newLeaf, nine),
            _computeRootOracle(511, newLeaf, _dynamic9(nine), TRANCHE_NODE_DOMAIN)
        );

        vm.expectRevert(LibSlotChainFixedTrees.TreeRootMismatch.selector);
        harness.updateRegistryRoot(bytes32(uint256(1)), 17, oldLeaf, newLeaf, six);
        vm.expectRevert(LibSlotChainFixedTrees.TreeRootMismatch.selector);
        harness.updateRankedEntryRoot(bytes32(uint256(1)), 17, oldLeaf, newLeaf, six);
        vm.expectRevert(LibSlotChainFixedTrees.TreeRootMismatch.selector);
        harness.updateAdmissionUsedRoot(bytes32(uint256(1)), 1135, oldLeaf, newLeaf, eleven);
        vm.expectRevert(LibSlotChainFixedTrees.TreeRootMismatch.selector);
        harness.updateTrancheRoot(bytes32(uint256(1)), 511, oldLeaf, newLeaf, nine);
    }

    function test_nodeDomainsAndHeights_MatchRawOracle() external pure {
        bytes32 left = keccak256("left");
        bytes32 right = keccak256("right");
        assertEq(
            LibSlotChainEncoding.hashRegistryNode(5, left, right),
            _rawNode(REGISTRY_NODE_DOMAIN, 5, left, right)
        );
        assertEq(
            LibSlotChainEncoding.hashAdmissionNode(10, left, right),
            _rawNode(ADMISSION_NODE_DOMAIN, 10, left, right)
        );
        assertEq(
            LibSlotChainEncoding.hashRankedEntryNode(5, left, right),
            _rawNode(ENTRY_NODE_DOMAIN, 5, left, right)
        );
        assertEq(
            LibSlotChainEncoding.hashTrancheNode(8, left, right),
            _rawNode(TRANCHE_NODE_DOMAIN, 8, left, right)
        );
        assertEq(
            LibSlotChainEncoding.hashForcedNode(63, left, right),
            _rawNode(FORCE_NODE_DOMAIN, 63, left, right)
        );
        assertEq(
            LibSlotChainEncoding.hashTerminalNode(63, left, right),
            _rawNode(TERMINAL_NODE_DOMAIN, 63, left, right)
        );
        assertEq(
            LibSlotChainEncoding.hashDataNode(11, left, right),
            _rawNode(DATA_NODE_DOMAIN, 11, left, right)
        );
        assertEq(
            LibSlotChainEncoding.hashManifestNode(11, left, right),
            _rawNode(MANIFEST_NODE_DOMAIN, 11, left, right)
        );
        assertNotEq(
            _rawNode(FORCE_NODE_DOMAIN, 0, left, right), _rawNode(FORCE_NODE_DOMAIN, 1, left, right)
        );
        assertNotEq(
            _rawNode(FORCE_NODE_DOMAIN, 0, left, right),
            _rawNode(TERMINAL_NODE_DOMAIN, 0, left, right)
        );
    }

    function test_nodeDomains_RevertWhen_HeightIsFirstInvalid() external {
        bytes32 left = keccak256("left");
        bytes32 right = keccak256("right");

        vm.expectRevert(LibSlotChainEncoding.InvalidNodeHeight.selector);
        harness.hashRegistryNode(6, left, right);
        vm.expectRevert(LibSlotChainEncoding.InvalidNodeHeight.selector);
        harness.hashAdmissionNode(11, left, right);
        vm.expectRevert(LibSlotChainEncoding.InvalidNodeHeight.selector);
        harness.hashRankedEntryNode(6, left, right);
        vm.expectRevert(LibSlotChainEncoding.InvalidNodeHeight.selector);
        harness.hashTrancheNode(9, left, right);
        vm.expectRevert(LibSlotChainEncoding.InvalidNodeHeight.selector);
        harness.hashForcedNode(64, left, right);
        vm.expectRevert(LibSlotChainEncoding.InvalidNodeHeight.selector);
        harness.hashDataNode(12, left, right);
        vm.expectRevert(LibSlotChainEncoding.InvalidNodeHeight.selector);
        harness.hashManifestNode(12, left, right);
        vm.expectRevert(LibSlotChainEncoding.InvalidNodeHeight.selector);
        harness.hashTerminalNode(64, left, right);
    }

    function test_forcedFrontier_PinVectorAndIgnoreStaleZeroBitSlots() external {
        bytes32 leaf = SlotChainGoldenVectors.FORCED_LEAF;
        (uint8 height, bytes32 carry, uint64 count, bytes32 root) =
            harness.applyForcedAppend(0, leaf);
        assertEq(height, 0);
        assertEq(carry, leaf);
        assertEq(count, 1);
        assertEq(root, SlotChainGoldenVectors.FORCE_FRONTIER_ROOT_1);
        bytes32[64] memory frontier = harness.forcedFrontier();
        assertEq(
            keccak256(abi.encodePacked(frontier)),
            SlotChainGoldenVectors.FORCE_FRONTIER_AFTER_1_DIGEST
        );
        assertEq(root, _depth64RootOracle(frontier, 1, false));

        harness.setForcedFrontier(1, keccak256("stale-zero-bit"));
        assertEq(harness.forcedRoot(1), root);
        harness.setForcedFrontier(0, keccak256("used-bit"));
        assertNotEq(harness.forcedRoot(1), root);
    }

    function test_forcedFrontier_CountBoundariesAndCapacity() external {
        assertEq(harness.forcedRoot(0), SlotChainGoldenVectors.EMPTY_FORCED_ROOT);
        assertEq(harness.forcedRoot(0), _depth64RootOracle(_zero64(), 0, false));

        bytes32[64] memory frontier;
        for (uint8 height = 1; height < 64; ++height) {
            frontier[height] = keccak256(abi.encodePacked("forced-max-frontier", height));
            harness.setForcedFrontier(height, frontier[height]);
        }
        assertEq(
            harness.forcedRoot(type(uint64).max - 1),
            _depth64RootOracle(frontier, type(uint64).max - 1, false)
        );
        bytes32 leaf = keccak256("forced-final-usable-leaf");
        (uint8 writeHeight, bytes32 carried, uint64 newCount, bytes32 newRoot) =
            harness.previewForcedAppend(type(uint64).max - 1, leaf);
        assertEq(writeHeight, 0);
        assertEq(carried, leaf);
        assertEq(newCount, type(uint64).max);
        frontier[0] = leaf;
        assertEq(newRoot, _depth64RootOracle(frontier, type(uint64).max, false));
        harness.setForcedFrontier(0, leaf);
        assertEq(harness.forcedRoot(type(uint64).max), newRoot);

        vm.expectRevert(LibSlotChainDepth64.TreeCapacityExceeded.selector);
        harness.previewForcedAppend(type(uint64).max, leaf);
    }

    function test_forcedRange_Pin65LeafVectorAndRejectMalformedProofs() external view {
        (bytes32[] memory leaves, bytes32 root) = _forcedFixture();
        bytes32[] memory revealed = _slice(leaves, 2, 65);
        bytes32[] memory proof = _forcedRangeProof(leaves, 70, 2, 65);
        assertEq(root, SlotChainGoldenVectors.FORCED_ROOT);
        assertEq(keccak256(abi.encodePacked(proof)), SlotChainGoldenVectors.FORCE_RANGE_DIGEST);
        assertTrue(harness.verifyForcedRange(70, 2, revealed, proof, root));

        bytes32[] memory missing = _copy(proof, proof.length - 1);
        assertFalse(harness.verifyForcedRange(70, 2, revealed, missing, root));
        bytes32[] memory extra = _copy(proof, proof.length + 1);
        extra[proof.length] = keccak256("extra");
        assertFalse(harness.verifyForcedRange(70, 2, revealed, extra, root));
        bytes32[] memory swapped = _copy(proof, proof.length);
        (swapped[0], swapped[1]) = (swapped[1], swapped[0]);
        assertFalse(harness.verifyForcedRange(70, 2, revealed, swapped, root));
        bytes32[] memory changedRevealed = _copy(revealed, revealed.length);
        changedRevealed[0] = keccak256("changed-revealed");
        assertFalse(harness.verifyForcedRange(70, 2, changedRevealed, proof, root));
        assertFalse(harness.verifyForcedRange(70, 3, revealed, proof, root));
        assertFalse(harness.verifyForcedRange(69, 2, revealed, proof, root));
        assertFalse(harness.verifyForcedRange(70, 2, revealed, proof, keccak256("wrong-root")));
    }

    function test_forcedRange_SingletonAndUint64ArithmeticBoundaries() external view {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256("singleton");
        bytes32[] memory revealed = _copy(leaves, 1);
        bytes32[] memory proof = _forcedRangeProof(leaves, 1, 0, 1);
        bytes32 root = _forcedVectorRoot(leaves, 1);
        assertEq(proof.length, 64);
        assertTrue(harness.verifyForcedRange(1, 0, revealed, proof, root));

        bytes32[] memory empty;
        assertFalse(harness.verifyForcedRange(0, 0, revealed, proof, root));
        assertFalse(harness.verifyForcedRange(1, 1, revealed, proof, root));
        assertFalse(harness.verifyForcedRange(1, 0, empty, proof, root));

        bytes32[] memory two = new bytes32[](2);
        two[0] = keccak256("near-max-0");
        two[1] = keccak256("near-max-1");
        assertFalse(
            harness.verifyForcedRange(
                type(uint64).max, type(uint64).max - 1, two, empty, bytes32(0)
            )
        );
        assertFalse(
            harness.verifyForcedRange(
                type(uint64).max, type(uint64).max, revealed, empty, bytes32(0)
            )
        );
    }

    function test_terminalFrontier_PinVectorsAndVerifyBothLeaves() external {
        (,,, bytes32 root1) =
            harness.applyTerminalAppend(0, SlotChainGoldenVectors.TERMINAL_DONE_LEAF);
        assertNotEq(root1, bytes32(0));
        (uint8 height, bytes32 carry, uint64 count, bytes32 root2) =
            harness.applyTerminalAppend(1, SlotChainGoldenVectors.TERMINAL_FAILED_LEAF);
        assertEq(height, 1);
        assertEq(
            carry,
            _rawNode(
                TERMINAL_NODE_DOMAIN,
                0,
                SlotChainGoldenVectors.TERMINAL_DONE_LEAF,
                SlotChainGoldenVectors.TERMINAL_FAILED_LEAF
            )
        );
        assertEq(count, 2);
        assertEq(root2, SlotChainGoldenVectors.TERMINAL_ROOT_2);
        assertEq(root2, SlotChainGoldenVectors.TERMINAL_FRONTIER_ROOT_2);
        bytes32[64] memory frontier = harness.terminalFrontier();
        assertEq(
            keccak256(abi.encodePacked(frontier)),
            SlotChainGoldenVectors.TERMINAL_FRONTIER_AFTER_2_DIGEST
        );
        assertEq(root2, _depth64RootOracle(frontier, 2, true));

        bytes32[64] memory proof0 = _terminalProof2(0);
        bytes32[64] memory proof1 = _terminalProof2(1);
        assertTrue(
            harness.verifyTerminalInclusion(
                2, 0, SlotChainGoldenVectors.TERMINAL_DONE_LEAF, proof0, root2
            )
        );
        assertTrue(
            harness.verifyTerminalInclusion(
                2, 1, SlotChainGoldenVectors.TERMINAL_FAILED_LEAF, proof1, root2
            )
        );
    }

    function test_terminalProofAndFrontier_RejectBoundariesAndIgnoreStaleSlots() external {
        assertEq(harness.terminalRoot(0), SlotChainGoldenVectors.EMPTY_TERMINAL_ROOT);
        bytes32[64] memory proof = _terminalProof2(0);
        assertFalse(
            harness.verifyTerminalInclusion(
                0, 0, SlotChainGoldenVectors.TERMINAL_DONE_LEAF, proof, bytes32(0)
            )
        );
        assertFalse(
            harness.verifyTerminalInclusion(
                2,
                2,
                SlotChainGoldenVectors.TERMINAL_DONE_LEAF,
                proof,
                SlotChainGoldenVectors.TERMINAL_ROOT_2
            )
        );
        proof[0] = keccak256("wrong-sibling");
        assertFalse(
            harness.verifyTerminalInclusion(
                2,
                0,
                SlotChainGoldenVectors.TERMINAL_DONE_LEAF,
                proof,
                SlotChainGoldenVectors.TERMINAL_ROOT_2
            )
        );
        assertFalse(
            harness.verifyTerminalInclusion(
                2,
                0,
                SlotChainGoldenVectors.TERMINAL_DONE_LEAF,
                _terminalProof2(0),
                keccak256("wrong-terminal-root")
            )
        );

        SlotChainTreesHarness local = new SlotChainTreesHarness();
        local.applyTerminalAppend(0, SlotChainGoldenVectors.TERMINAL_DONE_LEAF);
        bytes32 expected = local.terminalRoot(1);
        local.setTerminalFrontier(1, keccak256("stale"));
        assertEq(local.terminalRoot(1), expected);
        local.setTerminalFrontier(0, keccak256("used"));
        assertNotEq(local.terminalRoot(1), expected);

        vm.expectRevert(LibSlotChainDepth64.TreeCapacityExceeded.selector);
        local.previewTerminalAppend(type(uint64).max, keccak256("overflow"));
    }

    function test_terminalFrontier_MaxMinusOneAppendMatchesOracle() external {
        bytes32[64] memory frontier;
        for (uint8 height = 1; height < 64; ++height) {
            frontier[height] = keccak256(abi.encodePacked("terminal-max-frontier", height));
            harness.setTerminalFrontier(height, frontier[height]);
        }
        assertEq(
            harness.terminalRoot(type(uint64).max - 1),
            _depth64RootOracle(frontier, type(uint64).max - 1, true)
        );
        bytes32 leaf = keccak256("terminal-final-usable-leaf");
        (uint8 writeHeight,, uint64 newCount, bytes32 newRoot) =
            harness.previewTerminalAppend(type(uint64).max - 1, leaf);
        assertEq(writeHeight, 0);
        assertEq(newCount, type(uint64).max);
        frontier[0] = leaf;
        assertEq(newRoot, _depth64RootOracle(frontier, type(uint64).max, true));
        harness.setTerminalFrontier(0, leaf);
        assertEq(harness.terminalRoot(type(uint64).max), newRoot);
    }

    function test_dataMmr_PinFrontierAndProofVectors() external {
        (bytes32 leaf0, bytes32 leaf1, bytes32 leaf2) = _dataVectorLeaves();
        harness.applyDataAppend(0, leaf0);
        harness.applyDataAppend(1, leaf1);
        (,,, bytes32 root3) = harness.applyDataAppend(2, leaf2);
        bytes32[12] memory peaks = harness.dataPeaks();
        assertEq(
            keccak256(abi.encodePacked(peaks)),
            SlotChainGoldenVectors.DATA_MMR_FRONTIER_AFTER_3_DIGEST
        );
        assertEq(root3, SlotChainGoldenVectors.DATA_MMR_FRONTIER_ROOT_3);
        assertEq(root3, SlotChainGoldenVectors.MMR_ROOT_3);
        assertEq(root3, _mmrRootOracle(peaks, 3));

        (
            bytes32[] memory proofLeaves,
            bytes32 proofLeaf,
            bytes32[] memory mountainSiblings,
            bytes32[] memory otherPeaks,
            bytes32 proofRoot
        ) = _mmrProofFixture();
        assertEq(proofLeaves.length, SlotChainGoldenVectors.DATA_MMR_PROOF_COUNT);
        assertEq(SlotChainGoldenVectors.DATA_MMR_PROOF_INDEX, 10);
        assertEq(proofLeaf, SlotChainGoldenVectors.DATA_MMR_PROOF_LEAF);
        assertEq(proofRoot, SlotChainGoldenVectors.DATA_MMR_PROOF_ROOT);
        assertEq(
            keccak256(abi.encodePacked(mountainSiblings)),
            SlotChainGoldenVectors.DATA_MMR_MOUNTAIN_SIBLINGS_DIGEST
        );
        assertEq(
            keccak256(abi.encodePacked(otherPeaks)),
            SlotChainGoldenVectors.DATA_MMR_OTHER_PEAKS_DIGEST
        );
        assertTrue(
            harness.verifyDataInclusion(
                uint16(SlotChainGoldenVectors.DATA_MMR_PROOF_COUNT),
                uint16(SlotChainGoldenVectors.DATA_MMR_PROOF_INDEX),
                proofLeaf,
                mountainSiblings,
                otherPeaks,
                proofRoot
            )
        );
    }

    function test_dataMmr_AppendAndRootBoundaries() external {
        assertEq(harness.dataRoot(0), SlotChainGoldenVectors.EMPTY_DATA_BAG);
        bytes32 leaf = keccak256("data-boundary-leaf");
        _assertDataPreview(0, leaf);

        SlotChainTreesHarness count1 = _mmrHarnessForCount(1);
        _assertDataPreviewOn(count1, 1, leaf);
        SlotChainTreesHarness count15 = _mmrHarnessForCount(15);
        _assertDataPreviewOn(count15, 15, leaf);

        SlotChainTreesHarness count2099 = new SlotChainTreesHarness();
        bytes32[12] memory peaks2099 = _syntheticPeaks(2099);
        _setPeaks(count2099, peaks2099);
        assertEq(count2099.dataRoot(2099), _mmrRootOracle(peaks2099, 2099));
        _assertDataPreviewOn(count2099, 2099, leaf);

        SlotChainTreesHarness count2100 = new SlotChainTreesHarness();
        bytes32[12] memory peaks2100 = _syntheticPeaks(2100);
        _setPeaks(count2100, peaks2100);
        assertEq(count2100.dataRoot(2100), _mmrRootOracle(peaks2100, 2100));
        vm.expectRevert(LibSlotChainDataMmr.InvalidMmrCount.selector);
        count2100.dataRoot(2101);
        vm.expectRevert(LibSlotChainDataMmr.MmrCapacityExceeded.selector);
        count2100.previewDataAppend(2100, leaf);
    }

    function test_dataMmr_RootIgnoresStaleZeroBitPeaks() external {
        harness.setDataPeak(0, keccak256("meaningful"));
        bytes32 expected = harness.dataRoot(1);
        harness.setDataPeak(1, keccak256("stale"));
        assertEq(harness.dataRoot(1), expected);
        harness.setDataPeak(0, keccak256("changed"));
        assertNotEq(harness.dataRoot(1), expected);
    }

    function test_dataMmrProof_RejectsWrongPublicInputsAndProofGrammar() external view {
        (
            bytes32[] memory leaves,
            bytes32 leaf,
            bytes32[] memory siblings,
            bytes32[] memory peaks,
            bytes32 root
        ) = _mmrProofFixture();
        assertEq(leaves.length, 15);
        assertFalse(harness.verifyDataInclusion(0, 0, leaf, siblings, peaks, root));
        assertFalse(harness.verifyDataInclusion(15, 15, leaf, siblings, peaks, root));
        assertFalse(harness.verifyDataInclusion(14, 10, leaf, siblings, peaks, root));
        assertFalse(harness.verifyDataInclusion(15, 11, leaf, siblings, peaks, root));
        assertFalse(
            harness.verifyDataInclusion(15, 10, keccak256("wrong-leaf"), siblings, peaks, root)
        );
        assertFalse(
            harness.verifyDataInclusion(15, 10, leaf, siblings, peaks, keccak256("wrong-root"))
        );

        bytes32[] memory changedSiblings = _copy(siblings, siblings.length);
        changedSiblings[0] = keccak256("changed-sibling");
        assertFalse(harness.verifyDataInclusion(15, 10, leaf, changedSiblings, peaks, root));
        assertFalse(
            harness.verifyDataInclusion(
                15, 10, leaf, _copy(siblings, siblings.length - 1), peaks, root
            )
        );
        bytes32[] memory extraSibling = _copy(siblings, siblings.length + 1);
        extraSibling[siblings.length] = keccak256("extra-sibling");
        assertFalse(harness.verifyDataInclusion(15, 10, leaf, extraSibling, peaks, root));

        bytes32[] memory changedPeaks = _copy(peaks, peaks.length);
        changedPeaks[0] = keccak256("changed-peak");
        assertFalse(harness.verifyDataInclusion(15, 10, leaf, siblings, changedPeaks, root));
        bytes32[] memory reversedPeaks = _reverse(peaks);
        assertFalse(harness.verifyDataInclusion(15, 10, leaf, siblings, reversedPeaks, root));
        assertFalse(
            harness.verifyDataInclusion(
                15, 10, leaf, siblings, _copy(peaks, peaks.length - 1), root
            )
        );
        bytes32[] memory extraPeak = _copy(peaks, peaks.length + 1);
        extraPeak[peaks.length] = keccak256("extra-peak");
        assertFalse(harness.verifyDataInclusion(15, 10, leaf, siblings, extraPeak, root));
    }

    function test_manifestRoot_EmptyOneTwoThreeAndGoldenVectors() external view {
        SlotChainTypes.ManifestEntryV1[] memory empty;
        assertEq(harness.manifestRoot(0, empty), SlotChainGoldenVectors.EMPTY_MANIFEST_ROOT);
        assertEq(harness.manifestRoot(0, empty), _manifestRootOracle(0, empty));

        SlotChainTypes.ManifestEntryV1[] memory entries = _goldenManifestEntries();
        assertEq(harness.manifestRoot(0, entries), SlotChainGoldenVectors.MANIFEST_ROOT);
        assertEq(harness.manifestRoot(0, entries), _manifestRootOracle(0, entries));
        entries[0].blockOrdinal = 1;
        entries[1].blockOrdinal = 1;
        assertEq(harness.manifestRoot(1, entries), SlotChainGoldenVectors.MANIFEST_ROOT_BLOCK_1);

        for (uint16 count = 1; count <= 3; ++count) {
            SlotChainTypes.ManifestEntryV1[] memory small = _manifestEntries(count, 7);
            assertEq(harness.manifestRoot(7, small), _manifestRootOracle(7, small));
        }
    }

    function test_manifestRoot_Count2048MatchesOracle() external view {
        _assertManifestBoundary(2048, 4095);
    }

    function test_manifestRoot_Count2049MatchesOracle() external view {
        _assertManifestBoundary(2049, 17);
    }

    function test_manifestRoot_Count2100MatchesOracle() external view {
        _assertManifestBoundary(2100, 33);
    }

    function test_manifestRoot_RevertWhen_CountOrOrdinalIsOutsideBounds() external {
        SlotChainTypes.ManifestEntryV1[] memory tooMany = _manifestEntries(2101, 0);
        vm.expectRevert(LibSlotChainManifestTree.InvalidManifestTree.selector);
        harness.manifestRoot(0, tooMany);

        SlotChainTypes.ManifestEntryV1[] memory one = _manifestEntries(1, 4096);
        vm.expectRevert(LibSlotChainManifestTree.InvalidManifestTree.selector);
        harness.manifestRoot(4096, one);
    }

    function test_manifestRoot_RevertWhen_EntryOrdinalDiffers() external {
        SlotChainTypes.ManifestEntryV1[] memory one = _manifestEntries(1, 4095);
        one[0].blockOrdinal = 4094;
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.InvalidManifestBlockOrdinal.selector, 0)
        );
        harness.manifestRoot(4095, one);
    }

    function _assertFixedBoundary(
        uint8 _index,
        uint8 _depth,
        string memory _domain,
        bool _entry
    )
        private
        view
    {
        bytes32 leaf = keccak256(abi.encodePacked("fixed-boundary-leaf", _index, _entry));
        bytes32[] memory siblings = new bytes32[](_depth);
        for (uint8 height; height < _depth; ++height) {
            siblings[height] = keccak256(abi.encodePacked("fixed-boundary-sibling", _entry, height));
        }
        bytes32 expected = _computeRootOracle(_index, leaf, siblings, _domain);
        bytes32 actual = _entry
            ? harness.computeRankedEntryRoot(_index, leaf, _fixed6(siblings))
            : harness.computeRegistryRoot(_index, leaf, _fixed6(siblings));
        assertEq(actual, expected);
    }

    function _assertAdmissionBoundary(uint16 _index) private view {
        bytes32 leaf = keccak256(abi.encodePacked("admission-boundary-leaf", _index));
        bytes32[] memory siblings = new bytes32[](11);
        for (uint8 height; height < 11; ++height) {
            siblings[height] = keccak256(abi.encodePacked("admission-boundary-sibling", height));
        }
        assertEq(
            harness.computeAdmissionRoot(_index, leaf, _fixed11(siblings)),
            _computeRootOracle(_index, leaf, siblings, ADMISSION_NODE_DOMAIN)
        );
        if (_index < 1136) {
            bytes32 root = _computeRootOracle(_index, leaf, siblings, ADMISSION_NODE_DOMAIN);
            bytes32 replacement = keccak256(abi.encodePacked("admission-replacement", _index));
            assertEq(
                harness.updateAdmissionUsedRoot(
                    root, _index, leaf, replacement, _fixed11(siblings)
                ),
                _computeRootOracle(_index, replacement, siblings, ADMISSION_NODE_DOMAIN)
            );
        }
    }

    function _assertTrancheBoundary(uint16 _index) private view {
        bytes32 leaf = keccak256(abi.encodePacked("tranche-boundary-leaf", _index));
        bytes32[] memory siblings = new bytes32[](9);
        for (uint8 height; height < 9; ++height) {
            siblings[height] = keccak256(abi.encodePacked("tranche-boundary-sibling", height));
        }
        assertEq(
            harness.computeTrancheRoot(_index, leaf, _fixed9(siblings)),
            _computeRootOracle(_index, leaf, siblings, TRANCHE_NODE_DOMAIN)
        );
    }

    function _assertDataPreview(uint16 _count, bytes32 _leaf) private view {
        _assertDataPreviewOn(harness, _count, _leaf);
    }

    function _assertDataPreviewOn(
        SlotChainTreesHarness _harness,
        uint16 _count,
        bytes32 _leaf
    )
        private
        view
    {
        bytes32[12] memory peaks = _harness.dataPeaks();
        assertEq(_harness.dataRoot(_count), _mmrRootOracle(peaks, _count));
        (uint8 expectedHeight, bytes32 expectedCarry, uint16 expectedCount, bytes32 expectedRoot) =
            _mmrAppendOracle(peaks, _count, _leaf);
        (uint8 height, bytes32 carry, uint16 count, bytes32 root) =
            _harness.previewDataAppend(_count, _leaf);
        assertEq(height, expectedHeight);
        assertEq(carry, expectedCarry);
        assertEq(count, expectedCount);
        assertEq(root, expectedRoot);
    }

    function _assertManifestBoundary(uint16 _count, uint16 _ordinal) private view {
        SlotChainTypes.ManifestEntryV1[] memory entries = _manifestEntries(_count, _ordinal);
        assertEq(harness.manifestRoot(_ordinal, entries), _manifestRootOracle(_ordinal, entries));
    }

    function _registryFixture()
        private
        pure
        returns (bytes32[64] memory leaves_, bytes32 occupiedLeaf_)
    {
        for (uint8 index; index < 64; ++index) {
            bool occupied = index == 3;
            leaves_[index] = _rawRegistryLeaf(index, occupied);
            if (occupied) occupiedLeaf_ = leaves_[index];
        }
    }

    function _admissionFixture()
        private
        pure
        returns (bytes32[] memory leaves_, bytes32 occupiedLeaf_)
    {
        leaves_ = new bytes32[](2048);
        for (uint16 index; index < 2048; ++index) {
            uint8 location = index == 3 ? 1 : (index == 64 ? 2 : 0);
            bool occupied = location != 0;
            leaves_[index] = _rawAdmissionLeaf(index, location, occupied);
            if (index == 64) occupiedLeaf_ = leaves_[index];
        }
    }

    function _entryFixture()
        private
        pure
        returns (bytes32[64] memory leaves_, bytes32 occupiedLeaf_)
    {
        for (uint8 rank; rank < 64; ++rank) {
            leaves_[rank] = _rawEntryLeaf(rank, rank == 0);
        }
        occupiedLeaf_ = leaves_[0];
    }

    function _trancheFixture()
        private
        pure
        returns (bytes32[] memory leaves_, bytes32 occupiedLeaf_)
    {
        leaves_ = new bytes32[](512);
        for (uint16 index; index < 512; ++index) {
            leaves_[index] = index == 7
                ? _rawTrancheLeaf(7, 519, 2, 10 ** 17, 999_999)
                : _rawTrancheLeaf(index, type(uint64).max, 0, 0, 0);
        }
        occupiedLeaf_ = leaves_[7];
    }

    function _rawRegistryLeaf(uint8 _index, bool _occupied) private pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encodePacked(
                    "slot-chain-registry-leaf-v1",
                    _index,
                    _occupied ? uint8(1) : uint8(0),
                    _occupied ? address(0x1234) : address(0),
                    _occupied ? uint192(10 ** 18) : uint192(0)
                ),
                abi.encodePacked(
                    _occupied ? uint64(9) : uint64(0),
                    _occupied ? uint64(777) : uint64(0),
                    _occupied ? _repeatByte(0x11) : bytes32(0),
                    _occupied ? type(uint64).max : uint64(0)
                )
            )
        );
    }

    function _rawAdmissionLeaf(
        uint16 _index,
        uint8 _location,
        bool _occupied
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encodePacked(
                    "slot-chain-admission-leaf-v1",
                    _index,
                    _occupied ? uint8(1) : uint8(0),
                    _occupied ? _location : uint8(0),
                    _occupied ? address(0x1234) : address(0)
                ),
                abi.encodePacked(
                    _occupied ? uint192(10 ** 18) : uint192(0),
                    _occupied ? uint64(9) : uint64(0),
                    _occupied ? uint64(777) : uint64(0),
                    _occupied ? type(uint64).max : uint64(0)
                )
            )
        );
    }

    function _rawEntryLeaf(uint8 _rank, bool _occupied) private pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encodePacked(
                    "slot-chain-entry-leaf-v1",
                    _rank,
                    _occupied ? uint8(1) : uint8(0),
                    _occupied ? address(0x1234) : address(0),
                    _occupied ? uint192(10 ** 18) : uint192(0)
                ),
                abi.encodePacked(
                    _occupied ? uint64(9) : uint64(0),
                    _occupied ? uint64(777) : uint64(0),
                    _occupied ? type(uint64).max : uint64(0),
                    _occupied ? _rawTrancheLeaf(7, 519, 2, 10 ** 17, 999_999) : bytes32(0)
                )
            )
        );
    }

    function _rawTrancheLeaf(
        uint16 _index,
        uint64 _window,
        uint8 _state,
        uint192 _amount,
        uint64 _liableUntil
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "slot-chain-tranche-leaf-v1", _index, _window, _state, _amount, _liableUntil
            )
        );
    }

    function _emptyRegistryRootOracle() private pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](64);
        for (uint8 index; index < 64; ++index) {
            leaves[index] = _rawRegistryLeaf(index, false);
        }
        return _fixedRoot(leaves, REGISTRY_NODE_DOMAIN);
    }

    function _emptyAdmissionRootOracle() private pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](2048);
        for (uint16 index; index < 2048; ++index) {
            leaves[index] = _rawAdmissionLeaf(index, 0, false);
        }
        return _fixedRoot(leaves, ADMISSION_NODE_DOMAIN);
    }

    function _emptyEntryRootOracle() private pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](64);
        for (uint8 rank; rank < 64; ++rank) {
            leaves[rank] = _rawEntryLeaf(rank, false);
        }
        return _fixedRoot(leaves, ENTRY_NODE_DOMAIN);
    }

    function _emptyTrancheRootOracle() private pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](512);
        for (uint16 index; index < 512; ++index) {
            leaves[index] = _rawTrancheLeaf(index, type(uint64).max, 0, 0, 0);
        }
        return _fixedRoot(leaves, TRANCHE_NODE_DOMAIN);
    }

    function _forcedFixture() private pure returns (bytes32[] memory leaves_, bytes32 root_) {
        leaves_ = new bytes32[](70);
        for (uint64 index; index < 70; ++index) {
            leaves_[index] = _rawForcedLeaf(index);
        }
        root_ = _forcedVectorRoot(leaves_, 70);
    }

    function _rawForcedLeaf(uint64 _index) private pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encodePacked(
                    "slot-chain-force-user-v2",
                    _index,
                    address(0xCAFE),
                    _index,
                    uint256(16_788),
                    keccak256(abi.encodePacked(_index))
                ),
                abi.encodePacked(
                    uint32(123),
                    uint64(80_000),
                    uint64(80_000),
                    uint256(10 ** 12),
                    uint64(9999),
                    address(0xBEEF)
                ),
                abi.encodePacked(uint64(555), uint64(2055 + _index), uint256(10 ** 15))
            )
        );
    }

    function _forcedVectorRoot(
        bytes32[] memory _leaves,
        uint256 _count
    )
        private
        pure
        returns (bytes32)
    {
        bytes32[] memory empty = _emptyLadder("slot-chain-force-empty-v2", FORCE_NODE_DOMAIN, 64);
        bytes32 treeRoot = _sparseNode(_leaves, _count, 64, 0, empty, FORCE_NODE_DOMAIN);
        return keccak256(abi.encodePacked("slot-chain-force-root-v2", uint64(_count), treeRoot));
    }

    function _forcedRangeProof(
        bytes32[] memory _leaves,
        uint256 _count,
        uint256 _start,
        uint256 _length
    )
        private
        pure
        returns (bytes32[] memory proof_)
    {
        RangeProofBuilder memory builder;
        builder.count = _count;
        builder.start = _start;
        builder.end = _start + _length - 1;
        builder.leaves = _leaves;
        builder.empty = _emptyLadder("slot-chain-force-empty-v2", FORCE_NODE_DOMAIN, 64);
        builder.proof = new bytes32[](257);
        _emitRangeProof(builder, 64, 0);
        proof_ = builder.proof;
        uint256 proofLength = builder.cursor;
        assembly {
            mstore(proof_, proofLength)
        }
    }

    function _emitRangeProof(
        RangeProofBuilder memory _builder,
        uint8 _height,
        uint256 _nodeIndex
    )
        private
        pure
    {
        uint256 left = _nodeIndex << _height;
        uint256 right = left + (uint256(1) << _height) - 1;
        if (right < _builder.start || left > _builder.end) {
            _builder.proof[_builder.cursor] = _sparseNode(
                _builder.leaves,
                _builder.count,
                _height,
                _nodeIndex,
                _builder.empty,
                FORCE_NODE_DOMAIN
            );
            ++_builder.cursor;
            return;
        }
        if (_height == 0) return;
        _emitRangeProof(_builder, _height - 1, _nodeIndex * 2);
        _emitRangeProof(_builder, _height - 1, _nodeIndex * 2 + 1);
    }

    function _sparseNode(
        bytes32[] memory _leaves,
        uint256 _count,
        uint8 _height,
        uint256 _nodeIndex,
        bytes32[] memory _empty,
        string memory _domain
    )
        private
        pure
        returns (bytes32)
    {
        uint256 start = _nodeIndex << _height;
        if (start >= _count) return _empty[_height];
        if (_height == 0) return _leaves[start];
        return _rawNode(
            _domain,
            _height - 1,
            _sparseNode(_leaves, _count, _height - 1, _nodeIndex * 2, _empty, _domain),
            _sparseNode(_leaves, _count, _height - 1, _nodeIndex * 2 + 1, _empty, _domain)
        );
    }

    function _terminalProof2(uint64 _index) private pure returns (bytes32[64] memory proof_) {
        bytes32[] memory empty =
            _emptyLadder("slot-chain-terminal-empty-v2", TERMINAL_NODE_DOMAIN, 64);
        proof_[0] = _index == 0
            ? SlotChainGoldenVectors.TERMINAL_FAILED_LEAF
            : SlotChainGoldenVectors.TERMINAL_DONE_LEAF;
        for (uint8 height = 1; height < 64; ++height) {
            proof_[height] = empty[height];
        }
    }

    function _depth64RootOracle(
        bytes32[64] memory _frontier,
        uint64 _count,
        bool _terminal
    )
        private
        pure
        returns (bytes32)
    {
        string memory emptyDomain =
            _terminal ? "slot-chain-terminal-empty-v2" : "slot-chain-force-empty-v2";
        string memory nodeDomain = _terminal ? TERMINAL_NODE_DOMAIN : FORCE_NODE_DOMAIN;
        string memory rootDomain =
            _terminal ? "slot-chain-terminal-root-v2" : "slot-chain-force-root-v2";
        bytes32 empty = keccak256(bytes(emptyDomain));
        bytes32 node = empty;
        for (uint8 height; height < 64; ++height) {
            node = ((_count >> height) & 1) == 1
                ? _rawNode(nodeDomain, height, _frontier[height], node)
                : _rawNode(nodeDomain, height, node, empty);
            empty = _rawNode(nodeDomain, height, empty, empty);
        }
        return keccak256(abi.encodePacked(rootDomain, _count, node));
    }

    function _dataVectorLeaves()
        private
        pure
        returns (bytes32 leaf0_, bytes32 leaf1_, bytes32 leaf2_)
    {
        bytes32 session = SlotChainGoldenVectors.SESSION_ID;
        bytes32 body = SlotChainGoldenVectors.BODY_ROOT;
        bytes memory alpha = bytes("alpha");
        bytes memory beta = bytes("beta");
        bytes memory gamma = bytes("gamma");
        leaf0_ = _rawDataLeaf(
            session, 0, _repeatByte(0x33), body, 0, 0, 2, alpha, address(0xCAFE), 9999, 5, 6
        );
        leaf1_ = _rawDataLeaf(
            session, 1, _repeatByte(0x55), body, 0, 1, 2, beta, address(0xCAFE), 9999, 7, 8
        );
        leaf2_ = _rawDataLeaf(
            session, 2, _repeatByte(0x77), body, 1, 0, 1, gamma, address(0xBEEF), 10_001, 9, 10
        );
    }

    function _rawDataLeaf(
        bytes32 _session,
        uint16 _index,
        bytes32 _versionedHash,
        bytes32 _bodyRoot,
        uint16 _blockOrdinal,
        uint16 _chunkIndex,
        uint16 _chunkCount,
        bytes memory _chunk,
        address _publisher,
        uint64 _validUntil,
        uint256 _z,
        uint256 _y
    )
        private
        pure
        returns (bytes32)
    {
        bytes32 chunkRoot = keccak256(
            abi.encodePacked(
                "slot-chain-body-chunk-v1",
                _bodyRoot,
                _blockOrdinal,
                _chunkIndex,
                _chunkCount,
                uint32(_chunk.length),
                _chunk
            )
        );
        return keccak256(
            bytes.concat(
                abi.encodePacked(
                    "slot-chain-data-leaf-v1", _session, _index, _versionedHash, _bodyRoot
                ),
                abi.encodePacked(
                    _blockOrdinal,
                    _chunkIndex,
                    _chunkCount,
                    uint32(_chunk.length),
                    chunkRoot,
                    _publisher,
                    _validUntil
                ),
                abi.encodePacked(_z, _y)
            )
        );
    }

    function _mmrHarnessForCount(uint16 _count) private returns (SlotChainTreesHarness local_) {
        local_ = new SlotChainTreesHarness();
        for (uint16 index; index < _count; ++index) {
            local_.applyDataAppend(
                index, keccak256(abi.encodePacked("mmr-boundary-fixture", index))
            );
        }
    }

    function _syntheticPeaks(uint16 _count) private pure returns (bytes32[12] memory peaks_) {
        for (uint8 height; height < 12; ++height) {
            peaks_[height] = keccak256(abi.encodePacked("synthetic-peak", _count, height));
        }
    }

    function _setPeaks(SlotChainTreesHarness _harness, bytes32[12] memory _peaks) private {
        for (uint8 height; height < 12; ++height) {
            _harness.setDataPeak(height, _peaks[height]);
        }
    }

    function _mmrAppendOracle(
        bytes32[12] memory _peaks,
        uint16 _count,
        bytes32 _leaf
    )
        private
        pure
        returns (uint8 height_, bytes32 carry_, uint16 newCount_, bytes32 newRoot_)
    {
        carry_ = _leaf;
        while (((_count >> height_) & 1) == 1) {
            carry_ = _rawNode(DATA_NODE_DOMAIN, height_, _peaks[height_], carry_);
            ++height_;
        }
        newCount_ = _count + 1;
        _peaks[height_] = carry_;
        newRoot_ = _mmrRootOracle(_peaks, newCount_);
    }

    function _mmrRootOracle(
        bytes32[12] memory _peaks,
        uint16 _count
    )
        private
        pure
        returns (bytes32)
    {
        bytes memory encoded;
        uint8 peakCount;
        for (uint8 height; height < 12; ++height) {
            if (((_count >> height) & 1) == 0) continue;
            encoded = bytes.concat(encoded, bytes1(height), _peaks[height]);
            ++peakCount;
        }
        return keccak256(
            bytes.concat(
                bytes("slot-chain-data-bag-v1"), bytes2(_count), bytes1(peakCount), encoded
            )
        );
    }

    function _mmrProofFixture()
        private
        pure
        returns (
            bytes32[] memory leaves_,
            bytes32 leaf_,
            bytes32[] memory siblings_,
            bytes32[] memory otherPeaks_,
            bytes32 root_
        )
    {
        leaves_ = new bytes32[](15);
        for (uint16 index; index < 15; ++index) {
            leaves_[index] = keccak256(
                abi.encodePacked("slot-chain-round3-mmr-proof-fixture-v1", bytes2(index))
            );
        }
        leaf_ = leaves_[10];
        siblings_ = new bytes32[](2);
        siblings_[0] = leaves_[11];
        siblings_[1] = _rawNode(DATA_NODE_DOMAIN, 0, leaves_[8], leaves_[9]);
        otherPeaks_ = new bytes32[](3);
        otherPeaks_[0] = leaves_[14];
        otherPeaks_[1] = _rawNode(DATA_NODE_DOMAIN, 0, leaves_[12], leaves_[13]);
        otherPeaks_[2] = _fixedRoot(_slice(leaves_, 0, 8), DATA_NODE_DOMAIN);

        bytes32[12] memory peaks;
        peaks[0] = otherPeaks_[0];
        peaks[1] = otherPeaks_[1];
        peaks[2] = _fixedRoot(_slice(leaves_, 8, 4), DATA_NODE_DOMAIN);
        peaks[3] = otherPeaks_[2];
        root_ = _mmrRootOracle(peaks, 15);
    }

    function _goldenManifestEntries()
        private
        pure
        returns (SlotChainTypes.ManifestEntryV1[] memory entries_)
    {
        entries_ = new SlotChainTypes.ManifestEntryV1[](2);
        bytes32 body = SlotChainGoldenVectors.BODY_ROOT;
        entries_[0] = SlotChainTypes.ManifestEntryV1({
            blockOrdinal: 0,
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordIndex: 0,
            chunkIndex: 0,
            chunkCount: 2,
            chunkLength: 5,
            fullBodyRoot: body,
            chunkRoot: keccak256(
                abi.encodePacked(
                    "slot-chain-body-chunk-v1",
                    body,
                    uint16(0),
                    uint16(0),
                    uint16(2),
                    uint32(5),
                    bytes("alpha")
                )
            )
        });
        entries_[1] = SlotChainTypes.ManifestEntryV1({
            blockOrdinal: 0,
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordIndex: 1,
            chunkIndex: 1,
            chunkCount: 2,
            chunkLength: 4,
            fullBodyRoot: body,
            chunkRoot: keccak256(
                abi.encodePacked(
                    "slot-chain-body-chunk-v1",
                    body,
                    uint16(0),
                    uint16(1),
                    uint16(2),
                    uint32(4),
                    bytes("beta")
                )
            )
        });
    }

    function _manifestEntries(
        uint16 _count,
        uint16 _ordinal
    )
        private
        pure
        returns (SlotChainTypes.ManifestEntryV1[] memory entries_)
    {
        entries_ = new SlotChainTypes.ManifestEntryV1[](_count);
        for (uint16 position; position < _count; ++position) {
            entries_[position] = SlotChainTypes.ManifestEntryV1({
                blockOrdinal: _ordinal,
                sessionId: keccak256(abi.encodePacked("manifest-session", position)),
                recordIndex: position,
                chunkIndex: uint16(position % 5),
                chunkCount: 5,
                chunkLength: uint32(100 + position),
                fullBodyRoot: keccak256(abi.encodePacked("manifest-body", position)),
                chunkRoot: keccak256(abi.encodePacked("manifest-chunk", position))
            });
        }
    }

    function _manifestRootOracle(
        uint16 _ordinal,
        SlotChainTypes.ManifestEntryV1[] memory _entries
    )
        private
        pure
        returns (bytes32)
    {
        uint256 count = _entries.length;
        bytes32 empty = keccak256(bytes("slot-chain-manifest-empty-v1"));
        if (count == 0) {
            return keccak256(abi.encodePacked("slot-chain-manifest-root-v1", uint16(0), empty));
        }
        uint256 size = 1;
        while (size < count) size <<= 1;
        bytes32[] memory nodes = new bytes32[](size);
        for (uint16 position; position < count; ++position) {
            require(_entries[position].blockOrdinal == _ordinal, "oracle ordinal mismatch");
            nodes[position] = _rawManifestLeaf(position, _entries[position]);
        }
        for (uint256 position = count; position < size; ++position) {
            nodes[position] = empty;
        }
        return keccak256(
            abi.encodePacked(
                "slot-chain-manifest-root-v1",
                uint16(count),
                _fixedRoot(nodes, MANIFEST_NODE_DOMAIN)
            )
        );
    }

    function _rawManifestLeaf(
        uint16 _position,
        SlotChainTypes.ManifestEntryV1 memory _entry
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encodePacked(
                    "slot-chain-manifest-leaf-v1",
                    _position,
                    _entry.blockOrdinal,
                    _entry.sessionId,
                    _entry.recordIndex,
                    _entry.chunkIndex
                ),
                abi.encodePacked(
                    _entry.chunkCount, _entry.chunkLength, _entry.fullBodyRoot, _entry.chunkRoot
                )
            )
        );
    }

    function _rawNode(
        string memory _domain,
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_domain, _height, _left, _right));
    }

    function _fixedRoot(
        bytes32[] memory _leaves,
        string memory _domain
    )
        private
        pure
        returns (bytes32)
    {
        uint256 width = _leaves.length;
        uint8 height;
        while (width > 1) {
            for (uint256 index; index < width; index += 2) {
                _leaves[index / 2] = _rawNode(_domain, height, _leaves[index], _leaves[index + 1]);
            }
            width >>= 1;
            ++height;
        }
        return _leaves[0];
    }

    function _fixedProof(
        bytes32[] memory _leaves,
        uint256 _index,
        string memory _domain
    )
        private
        pure
        returns (bytes32[] memory proof_)
    {
        uint256 depth;
        for (uint256 size = _leaves.length; size > 1; size >>= 1) {
            ++depth;
        }
        proof_ = new bytes32[](depth);
        bytes32[] memory level = _copy(_leaves, _leaves.length);
        uint256 width = level.length;
        uint256 position = _index;
        for (uint8 height; width > 1; ++height) {
            proof_[height] = level[position ^ 1];
            for (uint256 cursor; cursor < width; cursor += 2) {
                level[cursor / 2] = _rawNode(_domain, height, level[cursor], level[cursor + 1]);
            }
            width >>= 1;
            position >>= 1;
        }
    }

    function _computeRootOracle(
        uint256 _index,
        bytes32 _leaf,
        bytes32[] memory _siblings,
        string memory _domain
    )
        private
        pure
        returns (bytes32 node_)
    {
        node_ = _leaf;
        for (uint8 height; height < _siblings.length; ++height) {
            node_ = ((_index >> height) & 1) == 1
                ? _rawNode(_domain, height, _siblings[height], node_)
                : _rawNode(_domain, height, node_, _siblings[height]);
        }
    }

    function _emptyLadder(
        string memory _emptyDomain,
        string memory _nodeDomain,
        uint8 _depth
    )
        private
        pure
        returns (bytes32[] memory empty_)
    {
        empty_ = new bytes32[](uint256(_depth) + 1);
        empty_[0] = keccak256(bytes(_emptyDomain));
        for (uint8 height; height < _depth; ++height) {
            empty_[height + 1] = _rawNode(_nodeDomain, height, empty_[height], empty_[height]);
        }
    }

    function _dynamic64(bytes32[64] memory _values) private pure returns (bytes32[] memory out_) {
        out_ = new bytes32[](64);
        for (uint8 i; i < 64; ++i) {
            out_[i] = _values[i];
        }
    }

    function _dynamic6(bytes32[6] memory _values) private pure returns (bytes32[] memory out_) {
        out_ = new bytes32[](6);
        for (uint8 i; i < 6; ++i) {
            out_[i] = _values[i];
        }
    }

    function _dynamic9(bytes32[9] memory _values) private pure returns (bytes32[] memory out_) {
        out_ = new bytes32[](9);
        for (uint8 i; i < 9; ++i) {
            out_[i] = _values[i];
        }
    }

    function _dynamic11(bytes32[11] memory _values) private pure returns (bytes32[] memory out_) {
        out_ = new bytes32[](11);
        for (uint8 i; i < 11; ++i) {
            out_[i] = _values[i];
        }
    }

    function _fixed6(bytes32[] memory _values) private pure returns (bytes32[6] memory out_) {
        for (uint8 i; i < 6; ++i) {
            out_[i] = _values[i];
        }
    }

    function _fixed9(bytes32[] memory _values) private pure returns (bytes32[9] memory out_) {
        for (uint8 i; i < 9; ++i) {
            out_[i] = _values[i];
        }
    }

    function _fixed11(bytes32[] memory _values) private pure returns (bytes32[11] memory out_) {
        for (uint8 i; i < 11; ++i) {
            out_[i] = _values[i];
        }
    }

    function _slice(
        bytes32[] memory _values,
        uint256 _start,
        uint256 _length
    )
        private
        pure
        returns (bytes32[] memory out_)
    {
        out_ = new bytes32[](_length);
        for (uint256 i; i < _length; ++i) {
            out_[i] = _values[_start + i];
        }
    }

    function _copy(
        bytes32[] memory _values,
        uint256 _length
    )
        private
        pure
        returns (bytes32[] memory out_)
    {
        out_ = new bytes32[](_length);
        uint256 copied = _length < _values.length ? _length : _values.length;
        for (uint256 i; i < copied; ++i) {
            out_[i] = _values[i];
        }
    }

    function _reverse(bytes32[] memory _values) private pure returns (bytes32[] memory out_) {
        out_ = new bytes32[](_values.length);
        for (uint256 i; i < _values.length; ++i) {
            out_[i] = _values[_values.length - 1 - i];
        }
    }

    function _zero64() private pure returns (bytes32[64] memory zero_) { }

    function _repeatByte(uint8 _byte) private pure returns (bytes32 value_) {
        value_ = bytes32(type(uint256).max / 255 * _byte);
    }
}
