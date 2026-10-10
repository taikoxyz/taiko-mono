// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";

/// @title LibEntriesTree
/// @notice Incremental Merkle tree over the staking registry's entries, and the entry leaf.
/// @dev The tree has a fixed depth of 12 (4096 leaf positions). Leaf `i` is the hash of entry
/// `i`; inner nodes are `keccak256(left ‖ right)`. A node that was never written reads as the
/// zero hash of its level: `zero(0) = 0` and `zero(l) = keccak256(zero(l - 1) ‖ zero(l - 1))`.
///
/// The root over the first `count` leaves is the node at level `ceil(log2(count))`, index 0,
/// which equals the root of those leaves padded with zero leaves to the next power of two. This
/// is the Etna node's `entries_root` (`crates/abci/src/committee` of taiko-client-rs).
///
/// Node `(level, index)` lives at key `(level << 32) | index` of the caller's mapping.
///
/// Leaves are appended in index order and may be rewritten afterwards. Because the leaf count
/// never decreases, `update` stops at the root level of the current count: a node above it covers
/// no leaf outside its leftmost child, is never read before the count grows past it, and is
/// written on the path of the leaf whose append makes it the root.
/// @custom:security-contact security@taiko.xyz
library LibEntriesTree {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The tree depth.
    uint256 internal constant DEPTH = 12;

    /// @dev The number of leaf positions, `2 ** DEPTH`.
    uint256 internal constant CAPACITY = 4096;

    /// @dev The domain tag of entry leaves: "ETNA_REG_ENTRY", right-padded with zero bytes.
    bytes32 internal constant ENTRY_TAG = bytes32("ETNA_REG_ENTRY");

    /// @dev `zero(l)` for `l = 1..12`; `zero(0)` is `bytes32(0)`.
    bytes32 private constant _Z1 =
        0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5;
    bytes32 private constant _Z2 =
        0xb4c11951957c6f8f642c4af61cd6b24640fec6dc7fc607ee8206a99e92410d30;
    bytes32 private constant _Z3 =
        0x21ddb9a356815c3fac1026b6dec5df3124afbadb485c9ba5a3e3398a04b7ba85;
    bytes32 private constant _Z4 =
        0xe58769b32a1beaf1ea27375a44095a0d1fb664ce2dd358e7fcbfb78c26a19344;
    bytes32 private constant _Z5 =
        0x0eb01ebfc9ed27500cd4dfc979272d1f0913cc9f66540d7e8005811109e1cf2d;
    bytes32 private constant _Z6 =
        0x887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968;
    bytes32 private constant _Z7 =
        0xffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f83;
    bytes32 private constant _Z8 =
        0x9867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756af;
    bytes32 private constant _Z9 =
        0xcefad4e508c098b9a7e1d8feb19955fb02ba9675585078710969d3440f5054e0;
    bytes32 private constant _Z10 =
        0xf9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5;
    bytes32 private constant _Z11 =
        0xf8b13a49e282f609c317a833fb8d976d11517c571d1221a265d25af778ecf892;
    bytes32 private constant _Z12 =
        0x3490c6ceeb450aecdc82e28293031d10c7d73bf85e57bf041a97360aa2c5d99c;

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Hashes entry `_index` into its leaf:
    /// `keccak256(abi.encode(ENTRY_TAG, uint256(_index), pubkey, effStake, uint64 activeFromL1,
    /// uint64 exitEffectiveL1, uint64 lastHeartbeatAt, uint64 lastHeartbeatSeq))`.
    /// @param _index The entry's index (its bond id).
    /// @param _entry The entry.
    /// @return The leaf hash.
    function leaf(
        uint256 _index,
        IEtnaStakingRegistry.Entry memory _entry
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                ENTRY_TAG,
                _index,
                _entry.pubkey,
                _entry.effStake,
                _entry.activeFromL1,
                _entry.exitEffectiveL1,
                _entry.lastHeartbeatAt,
                _entry.lastHeartbeatSeq
            )
        );
    }

    /// @dev Writes leaf `_index` and its ancestors up to the root level of `_count` leaves, and
    /// returns the new root. Appending leaf `n` passes `_count = n + 1`; rewriting an existing
    /// leaf passes the current count. Siblings that start at or beyond `_count` hold no leaf and
    /// are read as zero hashes without touching storage.
    /// @param _tree The tree nodes.
    /// @param _count The number of leaves after this write; at least `_index + 1` and at most
    /// `CAPACITY`.
    /// @param _index The leaf index.
    /// @param _leaf The new leaf.
    /// @return root_ The root over the first `_count` leaves (see `root`).
    function update(
        mapping(uint256 node => bytes32) storage _tree,
        uint256 _count,
        uint256 _index,
        bytes32 _leaf
    )
        internal
        returns (bytes32 root_)
    {
        require(_index < _count && _count <= CAPACITY, LeafIndexOutOfRange());

        bytes32 hash = _leaf;
        uint256 index = _index;
        // Every node from the leaf up to level ceil(log2(_count)), the first level with
        // `(_count - 1) >> level == 0`, is rewritten. `_count` is at least 1, and `level` and
        // `index` stay below 13 and 4096, so no operation here can overflow or underflow.
        unchecked {
            uint256 last = _count - 1;
            for (uint256 level;; ++level) {
                _tree[(level << 32) | index] = hash;
                if (last >> level == 0) break;

                uint256 siblingIndex = index ^ 1;
                bytes32 sibling = (siblingIndex << level) < _count
                    ? _node(_tree, level, siblingIndex)
                    : zero(level);
                hash = index & 1 == 0 ? _hashPair(hash, sibling) : _hashPair(sibling, hash);
                index >>= 1;
            }
        }
        root_ = hash;
    }

    /// @dev Returns the root over the first `_count` leaves: `bytes32(0)` for no leaf, leaf 0
    /// for one leaf, otherwise the node at level `ceil(log2(_count))`, index 0. The tree keeps
    /// only its current state, so `_count` must be the number of leaves written so far.
    /// @param _tree The tree nodes.
    /// @param _count The number of leaves written so far, at most `CAPACITY`.
    /// @return root_ The root.
    function root(
        mapping(uint256 node => bytes32) storage _tree,
        uint256 _count
    )
        internal
        view
        returns (bytes32 root_)
    {
        require(_count <= CAPACITY, LeafIndexOutOfRange());
        if (_count == 0) return 0;

        // The root level is ceil(log2(_count)), the first level with `(_count - 1) >> level == 0`;
        // `_count` is at least 1 and `level` stays at most 12.
        uint256 level;
        unchecked {
            uint256 last = _count - 1;
            while (last >> level != 0) {
                ++level;
            }
        }
        root_ = _node(_tree, level, 0);
    }

    /// @dev Returns the zero hash of `_level`: `bytes32(0)` at level 0 and
    /// `keccak256(zero(_level - 1) ‖ zero(_level - 1))` above.
    /// @param _level The tree level, at most `DEPTH`.
    /// @return The precomputed zero hash.
    function zero(uint256 _level) internal pure returns (bytes32) {
        if (_level == 0) return 0;
        if (_level == 1) return _Z1;
        if (_level == 2) return _Z2;
        if (_level == 3) return _Z3;
        if (_level == 4) return _Z4;
        if (_level == 5) return _Z5;
        if (_level == 6) return _Z6;
        if (_level == 7) return _Z7;
        if (_level == 8) return _Z8;
        if (_level == 9) return _Z9;
        if (_level == 10) return _Z10;
        if (_level == 11) return _Z11;
        if (_level == 12) return _Z12;
        revert LevelOutOfRange();
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Reads node `(_level, _index)`, substituting the level's zero hash if it was never
    /// written.
    /// @param _tree The tree nodes.
    /// @param _level The node's level.
    /// @param _index The node's index within its level.
    /// @return node_ The node.
    function _node(
        mapping(uint256 node => bytes32) storage _tree,
        uint256 _level,
        uint256 _index
    )
        private
        view
        returns (bytes32 node_)
    {
        node_ = _tree[(_level << 32) | _index];
        if (node_ == 0) node_ = zero(_level);
    }

    /// @dev Hashes two nodes: `keccak256(_left ‖ _right)`.
    /// @param _left The left child.
    /// @param _right The right child.
    /// @return hash_ The parent node.
    function _hashPair(bytes32 _left, bytes32 _right) private pure returns (bytes32 hash_) {
        assembly ("memory-safe") {
            mstore(0x00, _left)
            mstore(0x20, _right)
            hash_ := keccak256(0x00, 0x40)
        }
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error LeafIndexOutOfRange();
    error LevelOutOfRange();
}
