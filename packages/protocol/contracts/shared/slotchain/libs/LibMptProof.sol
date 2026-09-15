// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibCanonicalRLP } from "./LibCanonicalRLP.sol";

/// @title Bounded canonical Ethereum Merkle-Patricia proof verification
/// @custom:security-contact security@taiko.xyz
library LibMptProof {
    uint256 internal constant MAX_NODES_PER_PATH = 65;
    uint256 internal constant MAX_NODE_BYTES = 600;
    uint256 internal constant KEY_NIBBLES = 64;

    /// @dev A zero-copy view of one sequence of `be16(length)||canonicalRlpNode` records.
    struct Path {
        uint256 nodesOffset;
        uint256 endOffset;
        uint8 nodeCount;
    }

    struct ChildReference {
        bool isHash;
        uint256 inlineOffset;
        uint256 inlineLength;
    }

    struct WalkStep {
        uint256 keyIndex;
        bool isLeaf;
        ChildReference nextReference;
        LibCanonicalRLP.Item value;
    }

    /// @dev Scans and bounds one framed root-to-leaf path without copying node bytes. The count is
    ///      supplied separately because Registration uses a big-endian u16 count while Schedule
    ///      uses a u8 count; both use the same node framing and verifier.
    /// @param _proof The calldata proof or witness containing the path.
    /// @param _offset The first node-length prefix.
    /// @param _end The exclusive enclosing proof boundary.
    /// @param _nodeCount The already-decoded path node count.
    /// @return path_ The bounded zero-copy path view.
    /// @return nextOffset_ The first byte after the path.
    function parsePath(
        bytes calldata _proof,
        uint256 _offset,
        uint256 _end,
        uint256 _nodeCount
    )
        internal
        pure
        returns (Path memory path_, uint256 nextOffset_)
    {
        if (_end > _proof.length || _nodeCount == 0 || _nodeCount > MAX_NODES_PER_PATH) {
            revert InvalidMptPathGeometry();
        }

        uint256 cursor = _offset;
        for (uint256 i; i < _nodeCount; ++i) {
            uint256 nodeLength = _readU16(_proof, cursor, _end);
            cursor += 2;
            if (
                nodeLength == 0 || nodeLength > MAX_NODE_BYTES || cursor > _end
                    || nodeLength > _end - cursor
            ) {
                revert InvalidMptNodeGeometry();
            }
            cursor += nodeLength;
        }

        path_ = Path(_offset, cursor, uint8(_nodeCount));
        return (path_, cursor);
    }

    /// @dev Verifies an account proof and returns the authenticated storage root. The account value
    ///      must be exactly `[nonce,balance,storageRoot,codeHash]`; integer and byte widths are
    ///      canonical and the code hash must equal the caller-derived immutable expectation.
    /// @param _proof The calldata proof containing the path.
    /// @param _path The bounded account path view.
    /// @param _stateRoot The exact authenticated Ethereum state root.
    /// @param _account The exact account address whose Keccak trie key is consumed.
    /// @param _expectedCodeHash The required account code hash.
    /// @return storageRoot_ The authenticated account storage root.
    function verifyAccount(
        bytes calldata _proof,
        Path memory _path,
        bytes32 _stateRoot,
        address _account,
        bytes32 _expectedCodeHash
    )
        internal
        pure
        returns (bytes32 storageRoot_)
    {
        if (_stateRoot == bytes32(0) || _account == address(0) || _expectedCodeHash == bytes32(0)) {
            revert InvalidMptExpectation();
        }

        bytes32 key;
        assembly ("memory-safe") {
            mstore(0, shl(96, _account))
            key := keccak256(0, 20)
        }
        LibCanonicalRLP.Item memory value = _walk(_proof, _path, _stateRoot, key);
        if (value.isList || value.payloadLength == 0) revert InvalidMptAccount();

        return _decodeAccountValue(_proof, value, _expectedCodeHash);
    }

    /// @dev Decodes one authenticated account value without retaining traversal locals.
    function _decodeAccountValue(
        bytes calldata _proof,
        LibCanonicalRLP.Item memory _value,
        bytes32 _expectedCodeHash
    )
        private
        pure
        returns (bytes32 storageRoot_)
    {
        uint256 valueEnd = _value.payloadOffset + _value.payloadLength;
        LibCanonicalRLP.Item memory account =
            LibCanonicalRLP.decodeSingleBounded(_proof, _value.payloadOffset, valueEnd, 2);
        if (!account.isList) revert InvalidMptAccount();

        uint256 cursor = account.payloadOffset;
        uint256 accountEnd = account.payloadOffset + account.payloadLength;
        LibCanonicalRLP.Item memory item = LibCanonicalRLP.decodeItem(_proof, cursor, accountEnd);
        cursor = LibCanonicalRLP.next(item);
        LibCanonicalRLP.readUint(_proof, item);

        item = LibCanonicalRLP.decodeItem(_proof, cursor, accountEnd);
        cursor = LibCanonicalRLP.next(item);
        LibCanonicalRLP.readUint(_proof, item);

        item = LibCanonicalRLP.decodeItem(_proof, cursor, accountEnd);
        cursor = LibCanonicalRLP.next(item);
        storageRoot_ = LibCanonicalRLP.readBytes32(_proof, item);

        item = LibCanonicalRLP.decodeItem(_proof, cursor, accountEnd);
        cursor = LibCanonicalRLP.next(item);
        if (
            cursor != accountEnd || storageRoot_ == bytes32(0)
                || LibCanonicalRLP.readBytes32(_proof, item) != _expectedCodeHash
        ) {
            revert InvalidMptAccount();
        }
    }

    /// @dev Verifies one nonzero Ethereum storage-trie value. The MPT leaf's value byte string must
    ///      contain exactly one canonical minimal-RLP unsigned integer; it is left-padded to the
    ///      returned word. This deliberately rejects absence, zero and alternative encodings.
    /// @param _proof The calldata proof containing the path.
    /// @param _path The bounded storage path view.
    /// @param _storageRoot The exact storage root authenticated by `verifyAccount`.
    /// @param _storageTrieKey The already-Keccak-hashed storage trie key.
    /// @return value_ The exact nonzero 32-byte storage word.
    function verifyStorageValue(
        bytes calldata _proof,
        Path memory _path,
        bytes32 _storageRoot,
        bytes32 _storageTrieKey
    )
        internal
        pure
        returns (bytes32 value_)
    {
        if (_storageRoot == bytes32(0)) revert InvalidMptExpectation();

        LibCanonicalRLP.Item memory encodedValue =
            _walk(_proof, _path, _storageRoot, _storageTrieKey);
        if (encodedValue.isList || encodedValue.payloadLength == 0) {
            revert InvalidMptStorageValue();
        }

        uint256 encodedEnd = encodedValue.payloadOffset + encodedValue.payloadLength;
        LibCanonicalRLP.Item memory scalar = LibCanonicalRLP.decodeSingleBounded(
            _proof, encodedValue.payloadOffset, encodedEnd, 1
        );
        uint256 decoded = LibCanonicalRLP.readUint(_proof, scalar);
        if (decoded == 0) revert InvalidMptStorageValue();
        return bytes32(decoded);
    }

    /// @dev Traverses one complete root-to-leaf path and returns the leaf value item.
    function _walk(
        bytes calldata _proof,
        Path memory _path,
        bytes32 _root,
        bytes32 _key
    )
        private
        pure
        returns (LibCanonicalRLP.Item memory value_)
    {
        if (
            _path.nodeCount == 0 || _path.nodeCount > MAX_NODES_PER_PATH
                || _path.nodesOffset >= _path.endOffset || _path.endOffset > _proof.length
        ) {
            revert InvalidMptPathGeometry();
        }

        uint256 cursor = _path.nodesOffset;
        uint256 keyIndex;
        ChildReference memory expected;

        for (uint256 i; i < _path.nodeCount; ++i) {
            uint256 nodeLength = _readU16(_proof, cursor, _path.endOffset);
            cursor += 2;
            if (
                nodeLength == 0 || nodeLength > MAX_NODE_BYTES || cursor > _path.endOffset
                    || nodeLength > _path.endOffset - cursor
            ) {
                revert InvalidMptNodeGeometry();
            }
            uint256 nodeOffset = cursor;
            uint256 nodeEnd = nodeOffset + nodeLength;
            cursor = nodeEnd;

            if (i == 0) {
                if (keccak256(_proof[nodeOffset:nodeEnd]) != _root) revert MptReferenceMismatch();
            } else {
                _requireReference(_proof, nodeOffset, nodeLength, expected);
            }

            WalkStep memory step = _processNode(_proof, nodeOffset, nodeEnd, _key, keyIndex);
            keyIndex = step.keyIndex;
            if (step.isLeaf) {
                if (i + 1 != _path.nodeCount || cursor != _path.endOffset) {
                    revert SurplusMptNode();
                }
                return step.value;
            }
            expected = step.nextReference;
        }

        revert IncompleteMptPath();
    }

    /// @dev Validates one decoded node and returns the next traversal step.
    function _processNode(
        bytes calldata _proof,
        uint256 _nodeOffset,
        uint256 _nodeEnd,
        bytes32 _key,
        uint256 _keyIndex
    )
        private
        pure
        returns (WalkStep memory step_)
    {
        LibCanonicalRLP.Item memory node = LibCanonicalRLP.decodeItem(_proof, _nodeOffset, _nodeEnd);
        if (!node.isList || LibCanonicalRLP.next(node) != _nodeEnd) {
            revert InvalidMptNodeArity();
        }

        uint256 cursor = node.payloadOffset;
        uint256 payloadEnd = node.payloadOffset + node.payloadLength;
        LibCanonicalRLP.Item memory first = LibCanonicalRLP.decodeItem(_proof, cursor, payloadEnd);
        cursor = LibCanonicalRLP.next(first);
        LibCanonicalRLP.Item memory second = LibCanonicalRLP.decodeItem(_proof, cursor, payloadEnd);
        cursor = LibCanonicalRLP.next(second);
        if (cursor == payloadEnd) {
            return _processShortNode(_proof, first, second, _key, _keyIndex);
        }
        return _processBranchNode(_proof, first, second, cursor, payloadEnd, _key, _keyIndex);
    }

    /// @dev Validates one two-item extension or leaf node.
    function _processShortNode(
        bytes calldata _proof,
        LibCanonicalRLP.Item memory _compact,
        LibCanonicalRLP.Item memory _second,
        bytes32 _key,
        uint256 _keyIndex
    )
        private
        pure
        returns (WalkStep memory step_)
    {
        (step_.isLeaf, step_.keyIndex) = _consumeCompactPath(_proof, _compact, _key, _keyIndex);
        if (step_.isLeaf) {
            if (step_.keyIndex != KEY_NIBBLES || _second.isList) revert MptKeyMismatch();
            step_.value = _second;
        } else {
            step_.nextReference = _decodeChildReference(_second, false);
        }
    }

    /// @dev Streams one exact 17-item branch without allocating a 17-item memory array.
    function _processBranchNode(
        bytes calldata _proof,
        LibCanonicalRLP.Item memory _first,
        LibCanonicalRLP.Item memory _second,
        uint256 _cursor,
        uint256 _payloadEnd,
        bytes32 _key,
        uint256 _keyIndex
    )
        private
        pure
        returns (WalkStep memory step_)
    {
        if (_keyIndex >= KEY_NIBBLES) revert InvalidMptBranch();
        uint256 selected = _keyNibble(_key, _keyIndex);
        step_.keyIndex = _keyIndex + 1;

        for (uint256 childIndex; childIndex < 16; ++childIndex) {
            LibCanonicalRLP.Item memory child;
            if (childIndex == 0) {
                child = _first;
            } else if (childIndex == 1) {
                child = _second;
            } else {
                child = LibCanonicalRLP.decodeItem(_proof, _cursor, _payloadEnd);
                _cursor = LibCanonicalRLP.next(child);
            }
            if (childIndex == selected) {
                step_.nextReference = _decodeChildReference(child, false);
            } else {
                _decodeChildReference(child, true);
            }
        }

        LibCanonicalRLP.Item memory branchValue =
            LibCanonicalRLP.decodeItem(_proof, _cursor, _payloadEnd);
        _cursor = LibCanonicalRLP.next(branchValue);
        if (_cursor != _payloadEnd || branchValue.isList || branchValue.payloadLength != 0) {
            revert InvalidMptBranch();
        }
    }

    /// @dev Consumes one canonical hex-prefix path against the high-nibble-first key.
    function _consumeCompactPath(
        bytes calldata _proof,
        LibCanonicalRLP.Item memory _compact,
        bytes32 _key,
        uint256 _keyIndex
    )
        private
        pure
        returns (bool isLeaf_, uint256 nextKeyIndex_)
    {
        if (_compact.isList || _compact.payloadLength == 0) revert InvalidMptHexPrefix();
        uint8 first = uint8(_proof[_compact.payloadOffset]);
        uint8 flag = first >> 4;
        if (flag > 3) revert InvalidMptHexPrefix();
        bool odd = (flag & 1) != 0;
        isLeaf_ = flag >= 2;
        if (!odd && (first & 0x0f) != 0) revert InvalidMptHexPrefix();

        uint256 compactNibbles = _compact.payloadLength * 2 - (odd ? 1 : 2);
        if (!isLeaf_ && compactNibbles == 0) revert InvalidMptHexPrefix();
        if (compactNibbles > KEY_NIBBLES - _keyIndex) revert MptKeyMismatch();
        for (uint256 j; j < compactNibbles; ++j) {
            if (_compactNibble(_proof, _compact, j, odd) != _keyNibble(_key, _keyIndex + j)) {
                revert MptKeyMismatch();
            }
        }
        return (isLeaf_, _keyIndex + compactNibbles);
    }

    /// @dev Decodes an empty/hash/inline child reference, optionally permitting absence.
    function _decodeChildReference(
        LibCanonicalRLP.Item memory _item,
        bool _allowEmpty
    )
        private
        pure
        returns (ChildReference memory reference_)
    {
        if (!_item.isList) {
            if (_item.payloadLength == 0 && _allowEmpty) return reference_;
            if (_item.payloadLength != 32) revert InvalidMptChildReference();
            reference_.isHash = true;
            // The sentinel offset identifies the exact calldata payload to load in the caller.
            reference_.inlineOffset = _item.payloadOffset;
            return reference_;
        }
        if (_item.rawLength >= 32) revert InvalidMptChildReference();
        // The parent node hash authenticates every unselected child byte.  Only the selected
        // child participates in membership; when selected, the next framed node must equal this
        // complete inline item and `_processNode` validates its full MPT semantics.  Recursively
        // walking unrelated inline subtries would make verification cost depend on irrelevant
        // state and permit a gas-amplification liveness failure.
        reference_.inlineOffset = _item.rawOffset;
        reference_.inlineLength = _item.rawLength;
    }

    /// @dev Requires a framed node to equal the child reference selected by its parent.
    function _requireReference(
        bytes calldata _proof,
        uint256 _nodeOffset,
        uint256 _nodeLength,
        ChildReference memory _expected
    )
        private
        pure
    {
        if (_expected.isHash) {
            // Ethereum canonicalizes children shorter than 32 encoded bytes inline. A hash
            // reference to such a child is value-equivalent but not a canonical trie edge.
            if (_nodeLength < 32) revert MptReferenceMismatch();
            bytes32 expectedHash;
            uint256 hashOffset = _expected.inlineOffset;
            assembly ("memory-safe") {
                expectedHash := calldataload(add(_proof.offset, hashOffset))
            }
            if (keccak256(_proof[_nodeOffset:_nodeOffset + _nodeLength]) != expectedHash) {
                revert MptReferenceMismatch();
            }
            return;
        }

        uint256 length = _expected.inlineLength;
        if (length == 0 || _nodeLength != length) revert MptReferenceMismatch();
        bytes32 actual;
        bytes32 expected;
        uint256 expectedOffset = _expected.inlineOffset;
        assembly ("memory-safe") {
            actual := calldataload(add(_proof.offset, _nodeOffset))
            expected := calldataload(add(_proof.offset, expectedOffset))
        }
        uint256 shift = (32 - length) * 8;
        if (uint256(actual) >> shift != uint256(expected) >> shift) {
            revert MptReferenceMismatch();
        }
    }

    /// @dev Returns one high-nibble-first nibble from a bytes32 trie key.
    function _keyNibble(bytes32 _key, uint256 _index) private pure returns (uint8 nibble_) {
        return uint8(uint256(_key) >> ((KEY_NIBBLES - 1 - _index) * 4)) & 0x0f;
    }

    /// @dev Returns one decoded nibble from a compact hex-prefix path.
    function _compactNibble(
        bytes calldata _proof,
        LibCanonicalRLP.Item memory _compact,
        uint256 _index,
        bool _odd
    )
        private
        pure
        returns (uint8 nibble_)
    {
        uint256 encodedIndex = _index + (_odd ? 1 : 2);
        uint8 packed = uint8(_proof[_compact.payloadOffset + encodedIndex / 2]);
        return (encodedIndex & 1) == 0 ? packed >> 4 : packed & 0x0f;
    }

    /// @dev Reads one big-endian u16 without crossing the enclosing proof boundary.
    function _readU16(
        bytes calldata _proof,
        uint256 _offset,
        uint256 _end
    )
        private
        pure
        returns (uint256 value_)
    {
        if (_end > _proof.length || _offset > _end || _end - _offset < 2) {
            revert InvalidMptNodeGeometry();
        }
        return (uint256(uint8(_proof[_offset])) << 8) | uint8(_proof[_offset + 1]);
    }

    error InvalidMptPathGeometry();
    error InvalidMptNodeGeometry();
    error InvalidMptExpectation();
    error InvalidMptNodeArity();
    error InvalidMptBranch();
    error InvalidMptHexPrefix();
    error InvalidMptChildReference();
    error InvalidMptAccount();
    error InvalidMptStorageValue();
    error MptReferenceMismatch();
    error MptKeyMismatch();
    error SurplusMptNode();
    error IncompleteMptPath();
}
