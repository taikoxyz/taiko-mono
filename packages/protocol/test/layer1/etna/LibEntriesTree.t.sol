// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @dev Holds a tree in storage and exposes the library through external calls.
contract LibEntriesTreeHarness {
    mapping(uint256 node => bytes32) private _tree;

    function update(uint256 _count, uint256 _index, bytes32 _leaf) external returns (bytes32) {
        return LibEntriesTree.update(_tree, _count, _index, _leaf);
    }

    function root(uint256 _count) external view returns (bytes32) {
        return LibEntriesTree.root(_tree, _count);
    }

    function node(uint256 _level, uint256 _index) external view returns (bytes32) {
        return _tree[(_level << 32) | _index];
    }

    function leaf(
        uint256 _index,
        IEtnaStakingRegistry.Entry memory _entry
    )
        external
        pure
        returns (bytes32)
    {
        return LibEntriesTree.leaf(_index, _entry);
    }

    function zero(uint256 _level) external pure returns (bytes32) {
        return LibEntriesTree.zero(_level);
    }
}

contract LibEntriesTreeTest is CommonTest {
    /// @dev The number of sample entries the tests append.
    uint256 private constant _ENTRIES = 5;

    /// @dev The `exitEffectiveL1` of an entry with no exit set (spec 4.1).
    uint48 private constant _NO_EXIT = type(uint48).max;

    LibEntriesTreeHarness internal tree;

    function setUp() public virtual override {
        super.setUp();
        tree = new LibEntriesTreeHarness();
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    function test_constants_DepthMatchesCapacity() external pure {
        assertEq(LibEntriesTree.CAPACITY, 2 ** LibEntriesTree.DEPTH);
        assertEq(LibEntriesTree.DEPTH, 12);
    }

    function test_entryTag_IsRightPaddedAscii() external pure {
        assertEq(
            LibEntriesTree.ENTRY_TAG,
            bytes32(0x45544e415f5245475f454e5452595f5631000000000000000000000000000000)
        );
        assertEq(LibEntriesTree.ENTRY_TAG, bytes32("ETNA_REG_ENTRY_V1"));
    }

    // ---------------------------------------------------------------
    // zero
    // ---------------------------------------------------------------

    function test_zero_EqualsIteratedHashes() external view {
        bytes32 expected;
        assertEq(tree.zero(0), expected);
        for (uint256 level = 1; level <= LibEntriesTree.DEPTH; ++level) {
            expected = keccak256(abi.encodePacked(expected, expected));
            assertEq(tree.zero(level), expected);
        }
    }

    function test_zero_RevertWhen_LevelAboveDepth() external {
        vm.expectRevert(LibEntriesTree.LevelOutOfRange.selector);
        tree.zero(LibEntriesTree.DEPTH + 1);
    }

    // ---------------------------------------------------------------
    // leaf and root
    // ---------------------------------------------------------------

    function test_update_ReturnsTheRootAfterEachAppend() external {
        bytes32[] memory leaves = new bytes32[](_ENTRIES);
        for (uint256 i; i < _ENTRIES; ++i) {
            leaves[i] = tree.leaf(i, _sampleEntry(i));
            bytes32 root = tree.update(i + 1, i, leaves[i]);
            assertEq(root, tree.root(i + 1));
            assertEq(root, _naiveRoot(leaves, i + 1));
        }
    }

    function test_root_PadsWithZeroLeaves() external {
        bytes32 l0 = tree.leaf(0, _sampleEntry(0));
        bytes32 l1 = tree.leaf(1, _sampleEntry(1));
        bytes32 l2 = tree.leaf(2, _sampleEntry(2));

        assertEq(_freshRoot(1), l0);
        assertEq(_freshRoot(2), _hash(l0, l1));
        _append(0, 3);
        assertEq(tree.root(3), _hash(_hash(l0, l1), _hash(l2, bytes32(0))));
    }

    function test_root_ReadsUnwrittenNodesAsZeroHashes() external view {
        assertEq(tree.root(1), tree.zero(0));
        assertEq(tree.root(4), tree.zero(2));
        assertEq(tree.root(LibEntriesTree.CAPACITY), tree.zero(LibEntriesTree.DEPTH));
    }

    function test_leaf_BindsTheIndex() external view {
        IEtnaStakingRegistry.Entry memory entry = _sampleEntry(0);
        assertTrue(tree.leaf(0, entry) != tree.leaf(1, entry));
    }

    function test_leaf_EqualsAbiEncodeHash() external view {
        assertEq(tree.leaf(3, _sampleEntry(3)), _referenceLeaf(3, _sampleEntry(3)));
    }

    function test_leaf_BindsEveryField() external view {
        IEtnaStakingRegistry.Entry memory entry = _sampleEntry(1);
        bytes32 before = tree.leaf(1, entry);

        entry.ckPrefix ^= 1;
        assertTrue(tree.leaf(1, entry) != before, "ckPrefix");
        entry = _sampleEntry(1);
        entry.ckX = bytes32(uint256(entry.ckX) ^ 1);
        assertTrue(tree.leaf(1, entry) != before, "ckX");
        entry = _sampleEntry(1);
        entry.effStake += 1;
        assertTrue(tree.leaf(1, entry) != before, "effStake");
        entry = _sampleEntry(1);
        entry.activeFromL1 += 1;
        assertTrue(tree.leaf(1, entry) != before, "activeFromL1");
        entry = _sampleEntry(1);
        entry.exitEffectiveL1 -= 1;
        assertTrue(tree.leaf(1, entry) != before, "exitEffectiveL1");
    }

    function test_leaf_OfReleasedSlotHashesZeroFields() external view {
        IEtnaStakingRegistry.Entry memory released;
        for (uint256 j; j < 3; ++j) {
            bytes32 leaf = tree.leaf(j, released);
            assertEq(
                leaf,
                keccak256(abi.encode(bytes32("ETNA_REG_ENTRY_V1"), j, 0, 0, 0, 0, 0)),
                "zero-field leaf"
            );
            assertTrue(leaf != bytes32(0), "a released slot's leaf is not the zero leaf");
        }
    }

    function testFuzz_leaf_EqualsAbiEncodeHash(
        uint256 _index,
        IEtnaStakingRegistry.Entry memory _entry
    )
        external
        view
    {
        assertEq(tree.leaf(_index, _entry), _referenceLeaf(_index, _entry));
    }

    // ---------------------------------------------------------------
    // Shared vectors (testdata/etna_vectors, registry_entries)
    // ---------------------------------------------------------------

    /// @dev The five `ETNA_REG_ENTRY_V1` leaves, and the leaf of released slot 5 (all-zero
    /// fields).
    function test_leaf_MatchesTheSharedVectors() external view {
        string memory json = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(json, ".registry_entries.entries");
        assertEq(n, _ENTRIES);
        assertEq(LibEtnaVectors.lengthAt(json, ".registry_entries.leaves"), n);
        for (uint256 i; i < n; ++i) {
            assertEq(tree.leaf(i, _vectorEntry(json, i)), _vectorLeaf(json, i), "entry leaf");
        }
        IEtnaStakingRegistry.Entry memory released;
        uint256 index = LibEtnaVectors.uintAt(json, ".registry_entries.released.index");
        assertEq(index, n);
        assertEq(
            tree.leaf(index, released),
            LibEtnaVectors.bytes32At(json, ".registry_entries.released.leaf"),
            "released leaf"
        );
    }

    /// @dev The root after every append, from no entry to six (the five entries, then the
    /// released slot), equals the shared root of that prefix.
    function test_root_MatchesTheSharedVectors() external {
        string memory json = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(json, ".registry_entries.roots");
        assertEq(n, _ENTRIES + 2);
        assertEq(LibEtnaVectors.uintAt(json, ".registry_entries.roots[0].count"), 0);
        assertEq(tree.root(0), _vectorRoot(json, 0), "no entry");
        for (uint256 count = 1; count < n; ++count) {
            string memory root = string.concat(".registry_entries.roots[", vm.toString(count), "]");
            assertEq(LibEtnaVectors.uintAt(json, string.concat(root, ".count")), count);
            bytes32 leaf = count <= _ENTRIES
                ? _vectorLeaf(json, count - 1)
                : LibEtnaVectors.bytes32At(json, ".registry_entries.released.leaf");
            assertEq(tree.update(count, count - 1, leaf), _vectorRoot(json, count), "update");
            assertEq(tree.root(count), _vectorRoot(json, count), "root");
        }
    }

    // ---------------------------------------------------------------
    // update
    // ---------------------------------------------------------------

    function test_update_RewritesOnlyTheLeafPath() external {
        _append(0, 5);
        bytes32[4] memory offPath =
            [tree.node(0, 3), tree.node(1, 0), tree.node(2, 1), tree.node(0, 4)];
        bytes32[3] memory onPath = [tree.node(0, 2), tree.node(1, 1), tree.node(2, 0)];

        IEtnaStakingRegistry.Entry memory entry = _sampleEntry(2);
        entry.exitEffectiveL1 = 99;
        bytes32 root = tree.update(5, 2, tree.leaf(2, entry));

        assertEq(tree.node(0, 3), offPath[0]);
        assertEq(tree.node(1, 0), offPath[1]);
        assertEq(tree.node(2, 1), offPath[2]);
        assertEq(tree.node(0, 4), offPath[3]);
        assertTrue(tree.node(0, 2) != onPath[0]);
        assertTrue(tree.node(1, 1) != onPath[1]);
        assertTrue(tree.node(2, 0) != onPath[2]);
        assertEq(tree.node(3, 0), root);
        assertEq(tree.root(5), root);

        LibEntriesTreeHarness fresh = new LibEntriesTreeHarness();
        for (uint256 i; i < 5; ++i) {
            IEtnaStakingRegistry.Entry memory e = i == 2 ? entry : _sampleEntry(i);
            fresh.update(i + 1, i, fresh.leaf(i, e));
        }
        assertEq(fresh.root(5), root);
    }

    function test_update_StopsAtTheRootLevelOfTheCount() external {
        _append(0, 3);
        // Three leaves: the root is at level 2; nothing above it is written yet.
        assertTrue(tree.node(2, 0) != bytes32(0));
        assertEq(tree.node(3, 0), bytes32(0));

        // The fifth leaf moves the root to level 3, computed from the stored level-2 node.
        _append(3, 5);
        assertEq(tree.node(3, 0), tree.root(5));
        assertEq(tree.node(3, 0), _hash(tree.node(2, 0), tree.node(2, 1)));
        assertEq(tree.node(2, 1), _hash(tree.node(1, 2), tree.zero(1)));
    }

    function test_update_FillsTheWholeTree() external {
        bytes32[] memory leaves = new bytes32[](LibEntriesTree.CAPACITY);
        bytes32 root;
        vm.pauseGasMetering();
        for (uint256 i; i < LibEntriesTree.CAPACITY; ++i) {
            leaves[i] = keccak256(abi.encode("leaf", i));
            root = tree.update(i + 1, i, leaves[i]);
        }
        vm.resumeGasMetering();
        assertEq(root, _naiveRoot(leaves, LibEntriesTree.CAPACITY));
        assertEq(tree.root(LibEntriesTree.CAPACITY), root);
        assertEq(tree.node(LibEntriesTree.DEPTH, 0), root);
    }

    function test_update_RevertWhen_IndexNotBelowCount() external {
        vm.expectRevert(LibEntriesTree.LeafIndexOutOfRange.selector);
        tree.update(1, 1, bytes32(uint256(1)));
    }

    function test_update_RevertWhen_CountAboveCapacity() external {
        vm.expectRevert(LibEntriesTree.LeafIndexOutOfRange.selector);
        tree.update(LibEntriesTree.CAPACITY + 1, 0, bytes32(uint256(1)));
    }

    function test_root_RevertWhen_CountAboveCapacity() external {
        vm.expectRevert(LibEntriesTree.LeafIndexOutOfRange.selector);
        tree.root(LibEntriesTree.CAPACITY + 1);
    }

    // ---------------------------------------------------------------
    // Fuzz: incremental tree vs. a naive padded tree
    // ---------------------------------------------------------------

    function testFuzz_update_MatchesNaiveRoot(
        uint256 _seed,
        uint256 _count,
        uint256 _rewrites
    )
        external
    {
        _count = bound(_count, 1, 64);
        _rewrites = bound(_rewrites, 0, 8);

        bytes32[] memory leaves = new bytes32[](_count);
        for (uint256 i; i < _count; ++i) {
            leaves[i] = keccak256(abi.encode(_seed, "leaf", i));
            bytes32 root = tree.update(i + 1, i, leaves[i]);
            assertEq(root, _naiveRoot(leaves, i + 1));
            assertEq(tree.root(i + 1), root);
        }

        for (uint256 r; r < _rewrites; ++r) {
            uint256 index = uint256(keccak256(abi.encode(_seed, "index", r))) % _count;
            leaves[index] = keccak256(abi.encode(_seed, "rewrite", r));
            bytes32 root = tree.update(_count, index, leaves[index]);
            assertEq(root, _naiveRoot(leaves, _count));
            assertEq(tree.root(_count), root);
        }
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Sample entry `_i`: prefix `2 + _i % 2`, a hashed X coordinate, `_i + 1` TAIKO,
    /// active from `10 + _i`, exit at `1000 + _i` for odd `_i` (none otherwise).
    function _sampleEntry(uint256 _i) private pure returns (IEtnaStakingRegistry.Entry memory) {
        return IEtnaStakingRegistry.Entry({
            ckX: keccak256(abi.encode("ckX", _i)),
            effStake: (_i + 1) * 1 ether,
            ckPrefix: uint8(2 + _i % 2),
            activeFromL1: uint48(10 + _i),
            exitEffectiveL1: _i % 2 == 1 ? uint48(1000 + _i) : _NO_EXIT
        });
    }

    /// @dev Entry `_i` of the shared `registry_entries`.
    function _vectorEntry(
        string memory _json,
        uint256 _i
    )
        private
        pure
        returns (IEtnaStakingRegistry.Entry memory)
    {
        string memory p = string.concat(".registry_entries.entries[", vm.toString(_i), "].");
        return IEtnaStakingRegistry.Entry({
            ckX: LibEtnaVectors.bytes32At(_json, string.concat(p, "ck_x")),
            effStake: LibEtnaVectors.uintAt(_json, string.concat(p, "eff_stake")),
            ckPrefix: uint8(LibEtnaVectors.uintAt(_json, string.concat(p, "ck_prefix"))),
            activeFromL1: uint48(LibEtnaVectors.uintAt(_json, string.concat(p, "active_from_l1"))),
            exitEffectiveL1: uint48(
                LibEtnaVectors.uintAt(_json, string.concat(p, "exit_effective_l1"))
            )
        });
    }

    function _vectorLeaf(string memory _json, uint256 _i) private pure returns (bytes32) {
        return LibEtnaVectors.bytes32At(
            _json, string.concat(".registry_entries.leaves[", vm.toString(_i), "]")
        );
    }

    function _vectorRoot(string memory _json, uint256 _count) private pure returns (bytes32) {
        return LibEtnaVectors.bytes32At(
            _json, string.concat(".registry_entries.roots[", vm.toString(_count), "].entries_root")
        );
    }

    /// @dev The appendix A `regLeaf` built word by word: the seven 32-byte words of the tag,
    /// the index and the five entry fields, each widened to a full word.
    function _referenceLeaf(
        uint256 _index,
        IEtnaStakingRegistry.Entry memory _entry
    )
        private
        pure
        returns (bytes32)
    {
        bytes memory preimage = bytes.concat(
            bytes32("ETNA_REG_ENTRY_V1"),
            bytes32(_index),
            bytes32(uint256(_entry.ckPrefix)),
            _entry.ckX,
            bytes32(_entry.effStake),
            bytes32(uint256(_entry.activeFromL1)),
            bytes32(uint256(_entry.exitEffectiveL1))
        );
        assert(preimage.length == 7 * 32);
        return keccak256(preimage);
    }

    /// @dev Builds a new tree from sample entries `0 .. _count - 1` and returns its root.
    function _freshRoot(uint256 _count) private returns (bytes32 root_) {
        LibEntriesTreeHarness fresh = new LibEntriesTreeHarness();
        for (uint256 i; i < _count; ++i) {
            root_ = fresh.update(i + 1, i, fresh.leaf(i, _sampleEntry(i)));
        }
        assertEq(fresh.root(_count), root_);
    }

    /// @dev Appends sample entries `_from .. _to - 1`.
    function _append(uint256 _from, uint256 _to) private {
        for (uint256 i = _from; i < _to; ++i) {
            tree.update(i + 1, i, tree.leaf(i, _sampleEntry(i)));
        }
    }

    function _hash(bytes32 _left, bytes32 _right) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_left, _right));
    }

    /// @dev The root of the first `_count` leaves padded with zero leaves to the next power of
    /// two, hashed pairwise level by level.
    function _naiveRoot(bytes32[] memory _leaves, uint256 _count) private pure returns (bytes32) {
        if (_count == 0) return bytes32(0);
        uint256 width = 1;
        while (width < _count) {
            width <<= 1;
        }
        bytes32[] memory level = new bytes32[](width);
        for (uint256 i; i < _count; ++i) {
            level[i] = _leaves[i];
        }
        while (width > 1) {
            width >>= 1;
            for (uint256 i; i < width; ++i) {
                level[i] = _hash(level[2 * i], level[2 * i + 1]);
            }
        }
        return level[0];
    }
}
