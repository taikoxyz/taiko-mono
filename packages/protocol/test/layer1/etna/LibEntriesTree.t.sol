// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { LibEtnaVectors } from "test/shared/etna/LibEtnaVectors.sol";

/// @dev Holds a tree in storage and exposes the library through external calls.
contract LibEntriesTreeHarness {
    mapping(uint256 node => bytes32) private _tree;

    function update(uint256 _count, uint256 _index, bytes32 _leaf) external returns (bytes32) {
        return LibEntriesTree.update(_tree, _count, _index, _leaf);
    }

    function truncate(uint256 _count) external returns (bytes32) {
        return LibEntriesTree.truncate(_tree, _count);
    }

    function root(uint256 _count) external view returns (bytes32) {
        return LibEntriesTree.root(_tree, _count);
    }

    function node(uint256 _level, uint256 _index) external view returns (bytes32) {
        return _tree[(_level << 32) | _index];
    }

    function leaf(
        uint256 _slot,
        IEtnaStakingRegistry.Entry memory _entry
    )
        external
        pure
        returns (bytes32)
    {
        return LibEntriesTree.leaf(_slot, _entry);
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

    function test_leaf_OfEmptySlotHashesZeroFields() external view {
        IEtnaStakingRegistry.Entry memory empty;
        for (uint256 j; j < 3; ++j) {
            bytes32 leaf = tree.leaf(j, empty);
            assertEq(
                leaf,
                keccak256(abi.encode(bytes32("ETNA_REG_ENTRY_V1"), j, 0, 0, 0, 0, 0)),
                "zero-field leaf"
            );
            assertTrue(leaf != bytes32(0), "an empty slot's leaf is not the zero leaf");
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

    /// @dev The five `ETNA_REG_ENTRY_V1` leaves, and the leaf of empty slot 5 (all-zero fields,
    /// the vectors' `empty_slot` item).
    function test_leaf_MatchesTheSharedVectors() external view {
        string memory json = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(json, ".registry_entries.entries");
        assertEq(n, _ENTRIES);
        assertEq(LibEtnaVectors.lengthAt(json, ".registry_entries.leaves"), n);
        for (uint256 i; i < n; ++i) {
            assertEq(tree.leaf(i, _vectorEntry(json, i)), _vectorLeaf(json, i), "entry leaf");
        }
        // ENC-A-37 vector 37.a / ENC-A-38 vector 38.h `Z1`: an interior empty slot's all-zero
        // entry still hashes to a non-zero leaf.
        IEtnaStakingRegistry.Entry memory empty;
        uint256 slot = LibEtnaVectors.uintAt(json, ".registry_entries.empty_slot.slot");
        assertEq(slot, 1);
        assertEq(
            tree.leaf(slot, empty),
            LibEtnaVectors.bytes32At(json, ".registry_entries.empty_slot.leaf"),
            "empty slot leaf"
        );
    }

    /// @dev `regLeaf` is indexed by the slot, never the bond id: bond 4096 taking slot 7 and bond 2
    /// taking slot 0, each the lowest empty slot after its holder's withdrawal, hash their slot,
    /// and indexing by the bond id gives the vectors' `bond_id_leaf` instead.
    function test_leaf_IndexesTheSlotNotTheBondId() external view {
        string memory json = LibEtnaVectors.load();
        string memory cases = ".registry_entries.bond_slots";
        uint256 n = LibEtnaVectors.lengthAt(json, cases);
        assertEq(n, 2);
        for (uint256 i; i < n; ++i) {
            string memory p = string.concat(cases, "[", vm.toString(i), "].");
            uint256 slot = LibEtnaVectors.uintAt(json, string.concat(p, "slot"));
            uint256 bondId = LibEtnaVectors.uintAt(json, string.concat(p, "bond_id"));
            assertNotEq(slot, bondId);
            IEtnaStakingRegistry.Entry memory entry = _entryAt(json, string.concat(p, "entry."));
            assertEq(
                tree.leaf(slot, entry),
                LibEtnaVectors.bytes32At(json, string.concat(p, "leaf")),
                "slot leaf"
            );
            assertEq(
                tree.leaf(bondId, entry),
                LibEtnaVectors.bytes32At(json, string.concat(p, "bond_id_leaf")),
                "bond id leaf"
            );
        }
    }

    /// @dev The root after every append, from no entry to six (the five entries, then the empty
    /// slot), equals the shared root of that prefix.
    function test_root_MatchesTheSharedVectors() external {
        string memory json = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(json, ".registry_entries.roots");
        // Counts 0 to 5: a nonempty list ends in an occupied slot (STAKE-4.1-36).
        assertEq(n, _ENTRIES + 1);
        assertEq(LibEtnaVectors.uintAt(json, ".registry_entries.roots[0].count"), 0);
        assertEq(tree.root(0), _vectorRoot(json, 0), "no entry");
        for (uint256 count = 1; count < n; ++count) {
            string memory root = string.concat(".registry_entries.roots[", vm.toString(count), "]");
            assertEq(LibEtnaVectors.uintAt(json, string.concat(root, ".count")), count);
            bytes32 leaf = _vectorLeaf(json, count - 1);
            assertEq(tree.update(count, count - 1, leaf), _vectorRoot(json, count), "update");
            assertEq(tree.root(count), _vectorRoot(json, count), "root");
        }
    }

    /// @dev The shared `registry_entries.checkpoints` sequence (STAKE-4.1-36 vectors 36.f, 36.g,
    /// ENC-A-38 vectors 38.h, 38.i, COMM-4.3-2 vector 2.d) replayed through `update` and
    /// `truncate` as the registry applies it: three bonds; slot 1 withdrawn (an interior empty
    /// slot keeps the count, root K(K(L0,Z1),K(L2,0))); slot 2 slashed to zero balance (still
    /// occupied); slot 2 withdrawn (count 1, root L0); slot 0 withdrawn (count 0, root 0). Each
    /// state's root also equals the naive padded root over its own slot list, and none equals the
    /// vectors' wrong roots.
    function test_truncate_MatchesTheSharedCheckpointSequence() external {
        string memory json = LibEtnaVectors.load();
        string memory cps = ".registry_entries.checkpoints";
        uint256 n = LibEtnaVectors.lengthAt(json, cps);
        assertEq(n, 5);
        uint256 previous;
        for (uint256 i; i < n; ++i) {
            string memory p = string.concat(cps, "[", vm.toString(i), "].");
            uint256 count = LibEtnaVectors.uintAt(json, string.concat(p, "count"));
            bytes32 expected = LibEtnaVectors.bytes32At(json, string.concat(p, "entries_root"));
            bytes32[] memory leaves = new bytes32[](count);
            for (uint256 j; j < count; ++j) {
                string memory slot = string.concat(p, "slots[", vm.toString(j), "].");
                leaves[j] = tree.leaf(j, _entryAt(json, slot));
                assertEq(
                    leaves[j],
                    LibEtnaVectors.bytes32At(
                        json, string.concat(p, "leaves[", vm.toString(j), "]")
                    ),
                    "slot leaf"
                );
            }
            assertEq(_naiveRoot(leaves, count), expected, "naive root");
            if (count != 0) {
                string memory last = string.concat(p, "slots[", vm.toString(count - 1), "].");
                assertTrue(
                    vm.parseJsonBool(json, string.concat(last, "occupied")),
                    "a nonempty list ends in an occupied slot"
                );
            }

            bytes32 root;
            if (i == 0) {
                for (uint256 j; j < count; ++j) {
                    root = tree.update(j + 1, j, leaves[j]);
                }
            } else if (count < previous) {
                root = tree.truncate(count);
            } else {
                // One slot changed in place: rewrite every leaf; unchanged ones are no-ops.
                for (uint256 j; j < count; ++j) {
                    root = tree.update(count, j, leaves[j]);
                }
            }
            assertEq(root, expected, "incremental root");
            assertEq(tree.root(count), expected, "root view");
            previous = count;
        }

        string memory wrong = string.concat(cps, "[1].wrong_roots");
        bytes32 right = LibEtnaVectors.bytes32At(json, string.concat(cps, "[1].entries_root"));
        string[] memory keys = vm.parseJsonKeys(json, wrong);
        assertGt(keys.length, 0, "wrong roots");
        for (uint256 k; k < keys.length; ++k) {
            assertNotEq(
                LibEtnaVectors.bytes32At(json, string.concat(wrong, ".", keys[k])), right, keys[k]
            );
        }
    }

    /// @dev Truncating to zero leaves gives the zero root; truncating to `n` rewrites the new last
    /// leaf's path with zero padding, so a stale interior leaf beyond `n` no longer counts.
    function test_truncate_PadsTheNewLastLeafWithZeros() external {
        _append(0, 5);
        bytes32 l0 = tree.leaf(0, _sampleEntry(0));
        bytes32 l1 = tree.leaf(1, _sampleEntry(1));
        bytes32 l2 = tree.leaf(2, _sampleEntry(2));
        assertEq(tree.truncate(3), _hash(_hash(l0, l1), _hash(l2, bytes32(0))), "count 3");
        assertEq(tree.root(3), _hash(_hash(l0, l1), _hash(l2, bytes32(0))));
        assertEq(tree.truncate(1), l0, "count 1");
        assertEq(tree.truncate(0), bytes32(0), "count 0");
        assertEq(tree.root(0), bytes32(0));
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

    /// @dev Random appends, in-place rewrites and truncations, as the registry's registrations,
    /// entry changes and highest-slot withdrawals produce them, always match the naive padded
    /// tree over the current count (ENC-A-38).
    function testFuzz_truncate_MatchesNaiveRootAcrossShrinkAndRegrow(
        uint256 _seed,
        uint256 _steps
    )
        external
    {
        _steps = bound(_steps, 1, 48);
        bytes32[] memory leaves = new bytes32[](40);
        uint256 count;
        for (uint256 step; step < _steps; ++step) {
            uint256 r = uint256(keccak256(abi.encode(_seed, "step", step)));
            uint256 kind = r % 3;
            bytes32 root;
            if ((kind == 0 || count == 0) && count < leaves.length) {
                leaves[count] = keccak256(abi.encode(_seed, "append", step));
                root = tree.update(count + 1, count, leaves[count]);
                ++count;
            } else if (kind == 1 && count != 0) {
                uint256 index = (r >> 8) % count;
                leaves[index] = keccak256(abi.encode(_seed, "rewrite", step));
                root = tree.update(count, index, leaves[index]);
            } else if (count != 0) {
                count = (r >> 8) % count;
                root = tree.truncate(count);
            } else {
                continue;
            }
            assertEq(root, _naiveRoot(leaves, count), "incremental root");
            assertEq(tree.root(count), root, "root view");
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
        return _entryAt(_json, string.concat(".registry_entries.entries[", vm.toString(_i), "]."));
    }

    /// @dev The registry entry whose fields are at the JSON path prefix `_p`.
    function _entryAt(
        string memory _json,
        string memory _p
    )
        private
        pure
        returns (IEtnaStakingRegistry.Entry memory)
    {
        return IEtnaStakingRegistry.Entry({
            ckX: LibEtnaVectors.bytes32At(_json, string.concat(_p, "ck_x")),
            effStake: LibEtnaVectors.uintAt(_json, string.concat(_p, "eff_stake")),
            ckPrefix: uint8(LibEtnaVectors.uintAt(_json, string.concat(_p, "ck_prefix"))),
            activeFromL1: uint48(LibEtnaVectors.uintAt(_json, string.concat(_p, "active_from_l1"))),
            exitEffectiveL1: uint48(
                LibEtnaVectors.uintAt(_json, string.concat(_p, "exit_effective_l1"))
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
    function _naiveRoot(
        bytes32[] memory _leaves,
        uint256 _count
    )
        private
        pure
        returns (bytes32)
    {
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
