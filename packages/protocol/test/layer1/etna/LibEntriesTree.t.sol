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
    /// @dev The number of `registry_entries` in the shared vectors.
    uint256 private constant _VECTOR_ENTRIES = 5;

    LibEntriesTreeHarness internal tree;
    /// @dev `testdata/etna_vectors/vectors.json`.
    string internal vectors;

    function setUp() public virtual override {
        super.setUp();
        tree = new LibEntriesTreeHarness();
        vectors = LibEtnaVectors.load();
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
            bytes32(0x45544e415f5245475f454e5452595f5632000000000000000000000000000000)
        );
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
    // leaf and root: the shared `registry_entries` vectors (testdata/etna_vectors), which
    // taiko-client-rs `entries_root` reads too
    // ---------------------------------------------------------------

    function test_leaf_MatchesTheSharedVectors() external view {
        for (uint256 i; i < _VECTOR_ENTRIES; ++i) {
            assertEq(tree.leaf(i, _vectorEntry(i)), _vectorLeaf(i), "leaf");
        }
    }

    function test_root_MatchesTheSharedVectors() external {
        assertEq(tree.root(0), bytes32(0));
        assertEq(_vectorRoot(0), bytes32(0));
        for (uint256 count = 1; count <= _VECTOR_ENTRIES; ++count) {
            assertEq(_freshRoot(count), _vectorRoot(count), "root");
        }
    }

    function test_update_ReturnsTheRootAfterEachAppend() external {
        for (uint256 i; i < _VECTOR_ENTRIES; ++i) {
            bytes32 root = tree.update(i + 1, i, tree.leaf(i, _vectorEntry(i)));
            assertEq(root, tree.root(i + 1));
            assertEq(root, _vectorRoot(i + 1));
        }
    }

    function test_root_PadsWithZeroLeaves() external {
        bytes32 l0 = tree.leaf(0, _vectorEntry(0));
        bytes32 l1 = tree.leaf(1, _vectorEntry(1));
        bytes32 l2 = tree.leaf(2, _vectorEntry(2));

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
        IEtnaStakingRegistry.Entry memory entry = _vectorEntry(0);
        assertTrue(tree.leaf(0, entry) != tree.leaf(1, entry));
    }

    function test_leaf_EqualsAbiEncodeHash() external view {
        assertEq(tree.leaf(3, _vectorEntry(3)), _referenceLeaf(3, _vectorEntry(3)));
    }

    function test_leaf_BindsTheHeartbeatSeq() external view {
        IEtnaStakingRegistry.Entry memory entry = _vectorEntry(0);
        bytes32 before = tree.leaf(0, entry);
        entry.lastHeartbeatSeq += 1;
        assertTrue(tree.leaf(0, entry) != before);
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
    // update
    // ---------------------------------------------------------------

    function test_update_RewritesOnlyTheLeafPath() external {
        _append(0, 5);
        bytes32[4] memory offPath =
            [tree.node(0, 3), tree.node(1, 0), tree.node(2, 1), tree.node(0, 4)];
        bytes32[3] memory onPath = [tree.node(0, 2), tree.node(1, 1), tree.node(2, 0)];

        IEtnaStakingRegistry.Entry memory entry = _vectorEntry(2);
        entry.lastHeartbeatAt = 99;
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
            IEtnaStakingRegistry.Entry memory e = i == 2 ? entry : _vectorEntry(i);
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

    /// @dev The shared vector entry `_i` (`registry_entries.entries`): pubkey `0xa1 + _i`
    /// repeated, `_i + 1` TAIKO, active from `10 + _i`, exit at `1000 + _i` for odd `_i` (none
    /// otherwise), heartbeat at `20 + _i` with sequence `30 + _i`.
    function _vectorEntry(uint256 _i) private view returns (IEtnaStakingRegistry.Entry memory) {
        return LibEtnaVectors.registryEntry(vectors, _i);
    }

    /// @dev The shared vector leaf of entry `_i`.
    function _vectorLeaf(uint256 _i) private view returns (bytes32) {
        return LibEtnaVectors.bytes32At(
            vectors, string.concat(".registry_entries.leaves[", vm.toString(_i), "]")
        );
    }

    /// @dev The shared vector entries root over the first `_count` entries.
    function _vectorRoot(uint256 _count) private view returns (bytes32) {
        string memory p = string.concat(".registry_entries.roots[", vm.toString(_count), "].");
        assertEq(LibEtnaVectors.uintAt(vectors, string.concat(p, "count")), _count, "root order");
        return LibEtnaVectors.bytes32At(vectors, string.concat(p, "entries_root"));
    }

    /// @dev The leaf as taiko-client-rs `entry_leaf` encodes it, each uint64 widened to a word.
    function _referenceLeaf(
        uint256 _index,
        IEtnaStakingRegistry.Entry memory _entry
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32("ETNA_REG_ENTRY_V2"),
                _index,
                _entry.pubkey,
                _entry.effStake,
                uint256(_entry.activeFromL1),
                uint256(_entry.exitEffectiveL1),
                uint256(_entry.lastHeartbeatAt),
                uint256(_entry.lastHeartbeatSeq),
                _entry.rewardRecipient
            )
        );
    }

    /// @dev Builds a new tree from vector entries `0 .. _count - 1` and returns its root.
    function _freshRoot(uint256 _count) private returns (bytes32 root_) {
        LibEntriesTreeHarness fresh = new LibEntriesTreeHarness();
        for (uint256 i; i < _count; ++i) {
            root_ = fresh.update(i + 1, i, fresh.leaf(i, _vectorEntry(i)));
        }
        assertEq(fresh.root(_count), root_);
    }

    /// @dev Appends vector entries `_from .. _to - 1`.
    function _append(uint256 _from, uint256 _to) private {
        for (uint256 i = _from; i < _to; ++i) {
            tree.update(i + 1, i, tree.leaf(i, _vectorEntry(i)));
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
