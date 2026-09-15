// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    IBuilderRegistryProofVerifierV1
} from "../../../../contracts/layer1/slotchain/iface/IBuilderRegistryProofVerifierV1.sol";
import {
    BuilderRegistryProofVerifierV1
} from "../../../../contracts/layer1/slotchain/impl/BuilderRegistryProofVerifierV1.sol";
import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import { BuilderRegistryMerkleTracker } from "./BuilderRegistryTestHelpers.sol";
import { Test } from "forge-std/src/Test.sol";

contract BuilderRegistryProofVerifierTest is Test {
    using BuilderRegistryMerkleTracker for BuilderRegistryMerkleTracker.Tree;

    bytes4 private constant BPV1 = 0x42505631;
    bytes4 private constant EIV1 = 0x45495631;
    bytes4 private constant BPR1 = 0x42505231;
    bytes4 private constant BPO1 = 0x42504f31;
    bytes4 private constant IDENTITY_SELECTOR = 0x7c09d62d;
    bytes4 private constant PROOF_SELECTOR = 0xa9ca9190;

    BuilderRegistryProofVerifierV1 private _verifier;

    function setUp() public {
        _verifier = new BuilderRegistryProofVerifierV1();
    }

    function test_configurationSelectorsWidthsAndIndependentHashAreExact() external view {
        assertEq(
            IBuilderRegistryProofVerifierV1.builderRegistryProofVerifierConfigV1.selector,
            bytes4(0x0d1c9932)
        );
        assertEq(
            IBuilderRegistryProofVerifierV1.verifyBuilderEquivocationIdentityV1.selector,
            IDENTITY_SELECTOR
        );
        assertEq(
            IBuilderRegistryProofVerifierV1.verifyBuilderRegistryProofV1.selector, PROOF_SELECTOR
        );

        (bool ok, bytes memory raw) = address(_verifier).staticcall(hex"0d1c9932");
        assertTrue(ok);
        assertEq(raw.length, 512);
        assertEq(
            keccak256(raw), hex"eb1e75edfa0e3c8e1809071f51985fbdc2848eb8f65d7378d979a62b6d1ac862"
        );
        assertEq(bytes4(_word(raw, 0)), BPV1);
        uint256[14] memory expected = [
            uint256(1),
            64,
            1136,
            2048,
            512,
            6,
            11,
            9,
            18,
            350_000,
            120_000,
            160_000,
            700_000,
            450_000
        ];
        for (uint256 i; i < expected.length; ++i) {
            assertEq(uint256(_word(raw, i + 1)), expected[i]);
        }

        bytes memory packed = bytes.concat(
            abi.encodePacked(
                uint8(1),
                uint16(64),
                uint16(1136),
                uint16(2048),
                uint16(512),
                uint8(6),
                uint8(11),
                uint8(9),
                uint8(18)
            ),
            abi.encodePacked(
                uint32(350_000),
                uint32(120_000),
                uint32(160_000),
                uint32(700_000),
                uint32(450_000),
                IDENTITY_SELECTOR,
                PROOF_SELECTOR,
                BPV1,
                EIV1,
                BPR1,
                BPO1
            ),
            abi.encodePacked(
                uint16(512),
                uint16(320),
                uint16(192),
                uint16(432),
                uint16(531),
                uint16(6770),
                uint16(2727)
            )
        );
        assertEq(packed.length, 71);
        bytes32 expectedHash = keccak256(
            abi.encodePacked("slot-chain-builder-proof-verifier-config-v1", uint16(71), packed)
        );
        assertEq(
            expectedHash, hex"f1a01e067ec17b34e4f190810b2ebedfddd92a125705d2fd60134ce361ffac1a"
        );
        assertEq(_word(raw, 15), expectedHash);
        (ok, raw) = address(_verifier).staticcall(abi.encodePacked(bytes4(0xf6c0f7d2)));
        assertTrue(ok);
        assertEq(raw.length, 32);
        assertEq(_word(raw, 0), expectedHash);
    }

    function test_registryReplaceUsesExact432ByteGrammarAndR00Mask() external view {
        BuilderRegistryMerkleTracker.Tree memory tree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        uint8 index = 63;
        SlotChainTypes.RegistryCellV1 memory oldCell;
        SlotChainTypes.RegistryCellV1 memory newCell = _cell(address(0xB017D3), 1000, 7);
        bytes32 oldRoot = tree.root();
        bytes memory request = bytes.concat(
            abi.encodePacked(BPR1, bytes1(uint8(1)), oldRoot, bytes1(index), bytes1(uint8(0))),
            _registryCell(oldCell),
            bytes1(uint8(1)),
            _registryCell(newCell),
            BuilderRegistryMerkleTracker.encodeProof(tree.proof(index))
        );
        tree.update(index, BuilderRegistryMerkleTracker.registryLeaf(index, true, newCell));
        assertEq(request.length, 432);
        _assertProofResult(request, tree.root(), bytes32(0), bytes32(0));

        bytes memory badIndex = bytes.concat(request);
        badIndex[37] = bytes1(uint8(64));
        _assertProofFails(badIndex);
        _assertProofFails(bytes.concat(request, hex"00"));
    }

    function test_admissionReplaceUsesExact531ByteGrammarAndZeroAMask() external view {
        BuilderRegistryMerkleTracker.Tree memory tree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        uint16 position = 1135;
        SlotChainTypes.RegistryCellV1 memory newCell = _cell(address(0xB017D3), 1000, 7);
        bytes memory request = bytes.concat(
            abi.encodePacked(
                BPR1,
                bytes1(uint8(2)),
                tree.root(),
                bytes2(position),
                bytes1(uint8(0)),
                bytes1(uint8(0))
            ),
            new bytes(68),
            bytes1(uint8(1)),
            bytes1(uint8(2)),
            _admissionCell(newCell),
            BuilderRegistryMerkleTracker.encodeProof(tree.proof(position))
        );
        tree.update(
            position, BuilderRegistryMerkleTracker.admissionLeaf(position, true, 2, newCell)
        );
        assertEq(request.length, 531);
        _assertProofResult(request, bytes32(0), tree.root(), bytes32(0));

        bytes memory badPosition = bytes.concat(request);
        badPosition[37] = bytes1(uint8(1136 >> 8));
        badPosition[38] = bytes1(uint8(uint16(1136)));
        _assertProofFails(badPosition);
        bytes memory dirtyEmpty = bytes.concat(request);
        dirtyEmpty[41] = 0x01;
        _assertProofFails(dirtyEmpty);
    }

    function test_trancheBatchOneAndMaximumEighteenUseExactChainedRootsAnd00TMask() external view {
        BuilderRegistryMerkleTracker.Tree memory oneTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        SlotChainTypes.TrancheLeafV1 memory oldLeaf =
            BuilderRegistryMerkleTracker.emptyTrancheLeaf(511);
        SlotChainTypes.TrancheLeafV1 memory newLeaf = _tranche(511, 511, 2);
        bytes memory oneRequest = bytes.concat(
            BPR1,
            bytes1(uint8(3)),
            oneTree.root(),
            bytes1(uint8(1)),
            _trancheLeaf(oldLeaf),
            _trancheLeaf(newLeaf),
            BuilderRegistryMerkleTracker.encodeProof(oneTree.proof(511))
        );
        oneTree.update(511, BuilderRegistryMerkleTracker.trancheLeaf(newLeaf));
        assertEq(oneRequest.length, 412);
        _assertProofResult(oneRequest, bytes32(0), bytes32(0), oneTree.root());

        BuilderRegistryMerkleTracker.Tree memory batchTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        SlotChainTypes.TrancheLeafV1[18] memory reserved;
        for (uint16 i; i < 18; ++i) {
            reserved[i] = _tranche(i, uint64(i + 100), 2);
            batchTree.update(i, BuilderRegistryMerkleTracker.trancheLeaf(reserved[i]));
        }
        bytes memory batchRequest = bytes.concat(BPR1, bytes1(uint8(3)), batchTree.root(), hex"12");
        for (uint16 i; i < 18; ++i) {
            // Construct an independent value: memory struct assignment aliases and would mutate
            // `reserved[i]`, invalidating the old-leaf half of the transition under test.
            SlotChainTypes.TrancheLeafV1 memory liable = _tranche(i, uint64(i + 100), 3);
            batchRequest = bytes.concat(
                batchRequest,
                _trancheLeaf(reserved[i]),
                _trancheLeaf(liable),
                BuilderRegistryMerkleTracker.encodeProof(batchTree.proof(i))
            );
            batchTree.update(i, BuilderRegistryMerkleTracker.trancheLeaf(liable));
        }
        assertEq(batchRequest.length, 6770);
        _assertProofResult(batchRequest, bytes32(0), bytes32(0), batchTree.root());

        _assertProofFails(bytes.concat(BPR1, bytes1(uint8(3)), oneTree.root(), hex"00"));
        bytes memory overCount = bytes.concat(batchRequest);
        overCount[37] = bytes1(uint8(19));
        _assertProofFails(overCount);
    }

    function test_dynamicProofInterfaceRejectsOuterGapPaddingSuffixAndValue() external {
        BuilderRegistryMerkleTracker.Tree memory tree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        SlotChainTypes.RegistryCellV1 memory newCell = _cell(address(0xB017D3), 1000, 0);
        bytes memory request = bytes.concat(
            BPR1,
            bytes1(uint8(1)),
            tree.root(),
            bytes1(uint8(0)),
            bytes1(uint8(0)),
            _registryCell(emptyCell),
            bytes1(uint8(1)),
            _registryCell(newCell),
            BuilderRegistryMerkleTracker.encodeProof(tree.proof(0))
        );
        tree.update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, newCell));
        _assertProofResult(request, tree.root(), bytes32(0), bytes32(0));
        bytes memory canonical = abi.encodeWithSelector(PROOF_SELECTOR, request);
        assertEq(canonical.length, 68 + 448);

        bytes memory badOffset = bytes.concat(canonical);
        _writeWord(badOffset, 4, 64);
        _assertRawFails(badOffset, 0);
        bytes memory dirtyPadding = bytes.concat(canonical);
        dirtyPadding[dirtyPadding.length - 1] = 0x01;
        _assertRawFails(dirtyPadding, 0);
        _assertRawFails(bytes.concat(canonical, hex"00"), 0);

        vm.deal(address(this), 1);
        _assertRawFails(canonical, 1);
    }

    function _assertProofResult(
        bytes memory _request,
        bytes32 _registryRoot,
        bytes32 _admissionRoot,
        bytes32 _trancheRoot
    )
        private
        view
    {
        bytes memory calldata_ = abi.encodeWithSelector(PROOF_SELECTOR, _request);
        assertEq(calldata_.length, 68 + ((_request.length + 31) & ~uint256(31)));
        (bool ok, bytes memory raw) = address(_verifier).staticcall(calldata_);
        assertTrue(ok);
        assertEq(raw.length, 192);
        assertEq(bytes4(_word(raw, 0)), BPO1);
        assertEq(_word(raw, 1), _configurationHash());
        assertEq(
            _word(raw, 2),
            keccak256(
                bytes.concat(
                    bytes("slot-chain-builder-proof-request-v1"),
                    bytes4(uint32(_request.length)),
                    _request
                )
            )
        );
        assertEq(_word(raw, 3), _registryRoot);
        assertEq(_word(raw, 4), _admissionRoot);
        assertEq(_word(raw, 5), _trancheRoot);
    }

    function _assertProofFails(bytes memory _request) private view {
        (bool ok,) = address(_verifier).staticcall(abi.encodeWithSelector(PROOF_SELECTOR, _request));
        assertFalse(ok);
    }

    function _assertRawFails(bytes memory _calldata, uint256 _value) private {
        (bool ok,) = address(_verifier).call{ value: _value }(_calldata);
        assertFalse(ok);
    }

    function _cell(
        address _builder,
        uint192 _bond,
        uint64 _registrationIndex
    )
        private
        pure
        returns (SlotChainTypes.RegistryCellV1 memory cell_)
    {
        cell_ = SlotChainTypes.RegistryCellV1({
            builder: _builder,
            bond: _bond,
            registrationIndex: _registrationIndex,
            effectiveL2Slot: 12_345,
            trancheRoot: keccak256("tranche"),
            tombstonedAtL2Slot: type(uint64).max
        });
    }

    function _tranche(
        uint16 _index,
        uint64 _window,
        uint8 _state
    )
        private
        pure
        returns (SlotChainTypes.TrancheLeafV1 memory leaf_)
    {
        leaf_ = SlotChainTypes.TrancheLeafV1({
            index: _index,
            window: _window,
            state: _state,
            amount: 1000,
            liableUntil: 1_000_000 + (_window + 1) * 384 + 12_000
        });
    }

    function _registryCell(SlotChainTypes.RegistryCellV1 memory _cellValue)
        private
        pure
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

    function _admissionCell(SlotChainTypes.RegistryCellV1 memory _cellValue)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _cellValue.builder,
            _cellValue.bond,
            _cellValue.registrationIndex,
            _cellValue.effectiveL2Slot,
            _cellValue.tombstonedAtL2Slot
        );
    }

    function _trancheLeaf(SlotChainTypes.TrancheLeafV1 memory _leafValue)
        private
        pure
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

    function _configurationHash() private view returns (bytes32 hash_) {
        (bool ok, bytes memory raw) = address(_verifier).staticcall(hex"f6c0f7d2");
        assertTrue(ok);
        assertEq(raw.length, 32);
        return _word(raw, 0);
    }

    function _word(bytes memory _raw, uint256 _index) private pure returns (bytes32 value_) {
        assembly ("memory-safe") {
            value_ := mload(add(add(_raw, 32), mul(_index, 32)))
        }
    }

    function _writeWord(bytes memory _raw, uint256 _offset, uint256 _value) private pure {
        assembly ("memory-safe") {
            mstore(add(add(_raw, 32), _offset), _value)
        }
    }
}
