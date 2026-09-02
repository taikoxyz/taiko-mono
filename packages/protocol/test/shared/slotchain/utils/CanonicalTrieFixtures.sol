// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library CanonicalTrieFixtures {
    struct RegistrationFixture {
        bytes proof;
        bytes32 stateRoot;
        bytes32 storageRoot;
        bytes32 codeHash;
        bytes32 storageKey;
        bytes32 expectedValue;
        address account;
    }

    function registrationFixture() internal pure returns (RegistrationFixture memory fixture_) {
        fixture_.account = address(0x1234567890AbcdEF1234567890aBcdef12345678);
        fixture_.codeHash = keccak256("registrar-runtime");
        fixture_.storageKey = keccak256(abi.encodePacked(bytes32(uint256(7)), bytes32(uint256(9))));
        fixture_.expectedValue = bytes32(uint256(0x80));

        bytes memory storageNode = storageLeaf(fixture_.storageKey, fixture_.expectedValue, 0, 64);
        fixture_.storageRoot = keccak256(storageNode);

        bytes[] memory accountFields = new bytes[](4);
        accountFields[0] = hex"80";
        accountFields[1] = hex"80";
        accountFields[2] = rlpBytes(abi.encodePacked(fixture_.storageRoot));
        accountFields[3] = rlpBytes(abi.encodePacked(fixture_.codeHash));
        bytes memory accountValue = rlpList(accountFields);
        bytes32 accountKey = keccak256(abi.encodePacked(fixture_.account));
        bytes memory accountNode = leaf(accountKey, accountValue, 0, 64);
        fixture_.stateRoot = keccak256(accountNode);
        fixture_.proof =
            bytes.concat(be16(1), be16(1), framedNode(accountNode), framedNode(storageNode));
    }

    function denseRegistrationFixture()
        internal
        pure
        returns (RegistrationFixture memory fixture_)
    {
        return denseRegistrationFixture(65);
    }

    function denseRegistrationFixture(uint8 _nodeCount)
        internal
        pure
        returns (RegistrationFixture memory fixture_)
    {
        return _denseRegistrationFixture(_nodeCount, false, false);
    }

    function denseRegistrationFixtureWithInlineStorageSiblings(uint8 _nodeCount)
        internal
        pure
        returns (RegistrationFixture memory fixture_)
    {
        return _denseRegistrationFixture(_nodeCount, true, false);
    }

    function denseRegistrationFixtureWithInlineSiblingsBothPaths(uint8 _nodeCount)
        internal
        pure
        returns (RegistrationFixture memory fixture_)
    {
        return _denseRegistrationFixture(_nodeCount, true, true);
    }

    function lateAdversarialRegistrationFixture(uint8 _maximumWorkedRemainingNibbles)
        internal
        pure
        returns (RegistrationFixture memory fixture_)
    {
        require(_maximumWorkedRemainingNibbles <= 32, "fixture work threshold");
        fixture_.account = address(0x1234567890AbcdEF1234567890aBcdef12345678);
        fixture_.codeHash = keccak256("late-adversarial-registrar-runtime");
        fixture_.storageKey = keccak256("late-adversarial-registration-slot");
        fixture_.expectedValue = bytes32(uint256(0x80));

        (bytes memory storagePath, bytes32 storageRoot) = _lateDensePath(
            fixture_.storageKey,
            rlpUint(fixture_.expectedValue),
            true,
            _maximumWorkedRemainingNibbles
        );
        fixture_.storageRoot = storageRoot;

        bytes[] memory accountFields = new bytes[](4);
        accountFields[0] = hex"80";
        accountFields[1] = hex"80";
        accountFields[2] = rlpBytes(abi.encodePacked(storageRoot));
        accountFields[3] = rlpBytes(abi.encodePacked(fixture_.codeHash));
        bytes memory accountValue = rlpList(accountFields);
        bytes32 accountKey = keccak256(abi.encodePacked(fixture_.account));
        (bytes memory accountPath, bytes32 stateRoot) =
            _lateDensePath(accountKey, accountValue, false, 0);
        fixture_.stateRoot = stateRoot;
        fixture_.proof = bytes.concat(be16(34), be16(34), accountPath, storagePath);
    }

    function _denseRegistrationFixture(
        uint8 _nodeCount,
        bool _inlineStorageSiblings,
        bool _inlineAccountSiblings
    )
        private
        pure
        returns (RegistrationFixture memory fixture_)
    {
        require(_nodeCount >= 1 && _nodeCount <= 65, "fixture node count");
        fixture_.account = address(0x1234567890AbcdEF1234567890aBcdef12345678);
        fixture_.codeHash = keccak256("dense-registrar-runtime");
        fixture_.storageKey = keccak256("dense-registration-slot");
        fixture_.expectedValue = bytes32(uint256(0x80));

        (bytes memory storagePath, bytes32 storageRoot) = densePath(
            fixture_.storageKey, rlpUint(fixture_.expectedValue), _nodeCount, _inlineStorageSiblings
        );
        fixture_.storageRoot = storageRoot;

        bytes[] memory accountFields = new bytes[](4);
        accountFields[0] = hex"80";
        accountFields[1] = hex"80";
        accountFields[2] = rlpBytes(abi.encodePacked(storageRoot));
        accountFields[3] = rlpBytes(abi.encodePacked(fixture_.codeHash));
        bytes memory accountValue = rlpList(accountFields);
        bytes32 accountKey = keccak256(abi.encodePacked(fixture_.account));
        (bytes memory accountPath, bytes32 stateRoot) =
            densePath(accountKey, accountValue, _nodeCount, _inlineAccountSiblings);
        fixture_.stateRoot = stateRoot;
        fixture_.proof = bytes.concat(be16(_nodeCount), be16(_nodeCount), accountPath, storagePath);
    }

    function densePath(
        bytes32 _key,
        bytes memory _valueBytes
    )
        internal
        pure
        returns (bytes memory framedPath_, bytes32 root_)
    {
        return densePath(_key, _valueBytes, 65);
    }

    function densePath(
        bytes32 _key,
        bytes memory _valueBytes,
        uint8 _nodeCount
    )
        internal
        pure
        returns (bytes memory framedPath_, bytes32 root_)
    {
        return densePath(_key, _valueBytes, _nodeCount, false);
    }

    function densePath(
        bytes32 _key,
        bytes memory _valueBytes,
        uint8 _nodeCount,
        bool _inlineSiblings
    )
        internal
        pure
        returns (bytes memory framedPath_, bytes32 root_)
    {
        require(_nodeCount >= 1 && _nodeCount <= 65, "fixture node count");
        uint256 branchCount = _nodeCount - 1;
        bytes[] memory nodes = new bytes[](_nodeCount);
        nodes[branchCount] = leaf(_key, _valueBytes, branchCount, 64 - branchCount);
        bytes memory opaque = rlpBytes(abi.encodePacked(keccak256("opaque-unselected-child")));

        for (uint256 reverseIndex = branchCount; reverseIndex != 0; --reverseIndex) {
            uint256 keyIndex = reverseIndex - 1;
            nodes[keyIndex] =
                _denseBranch(_key, keyIndex, nodes[keyIndex + 1], opaque, _inlineSiblings);
        }

        root_ = keccak256(nodes[0]);
        uint256 total;
        for (uint256 i; i < nodes.length; ++i) {
            total += 2 + nodes[i].length;
        }
        framedPath_ = new bytes(total);
        uint256 cursor;
        for (uint256 i; i < nodes.length; ++i) {
            uint256 length = nodes[i].length;
            framedPath_[cursor] = bytes1(uint8(length >> 8));
            framedPath_[cursor + 1] = bytes1(uint8(length));
            cursor += 2;
            for (uint256 j; j < length; ++j) {
                framedPath_[cursor + j] = nodes[i][j];
            }
            cursor += length;
        }
    }

    function _denseBranch(
        bytes32 _key,
        uint256 _keyIndex,
        bytes memory _selectedChild,
        bytes memory _opaque,
        bool _inlineSiblings
    )
        private
        pure
        returns (bytes memory node_)
    {
        bytes memory siblingReference = _opaque;
        if (_inlineSiblings) {
            bytes memory siblingLeaf = leaf(_key, hex"01", _keyIndex + 1, 64 - _keyIndex - 1);
            siblingReference = siblingLeaf.length < 32
                ? siblingLeaf
                : rlpBytes(abi.encodePacked(keccak256(siblingLeaf)));
        }

        bytes[] memory items = new bytes[](17);
        for (uint256 childIndex; childIndex < 16; ++childIndex) {
            items[childIndex] = siblingReference;
        }
        items[nibble(_key, _keyIndex)] = _selectedChild.length < 32
            ? _selectedChild
            : rlpBytes(abi.encodePacked(keccak256(_selectedChild)));
        items[16] = hex"80";
        return rlpList(items);
    }

    function _lateDensePath(
        bytes32 _key,
        bytes memory _valueBytes,
        bool _inlineStorageSiblings,
        uint8 _maximumWorkedRemainingNibbles
    )
        private
        pure
        returns (bytes memory framedPath_, bytes32 root_)
    {
        uint256 extensionNibbles = 31;
        uint256 branchCount = 32;
        bytes[] memory nodes = new bytes[](34);
        nodes[33] = leaf(_key, _valueBytes, 63, 1);
        bytes memory opaque = rlpBytes(abi.encodePacked(keccak256("late-opaque-child")));

        for (uint256 reverseIndex = branchCount; reverseIndex != 0; --reverseIndex) {
            uint256 branchOrdinal = reverseIndex - 1;
            uint256 nodeIndex = branchOrdinal + 1;
            uint256 keyIndex = extensionNibbles + branchOrdinal;
            bytes memory siblingReference = _lateSiblingReference(
                _key, keyIndex, _inlineStorageSiblings, _maximumWorkedRemainingNibbles, opaque
            );
            nodes[nodeIndex] = _branchWithSiblingReference(
                _key, keyIndex, nodes[nodeIndex + 1], siblingReference
            );
        }

        nodes[0] = _extensionNode(_key, 0, extensionNibbles, nodes[1]);
        root_ = keccak256(nodes[0]);
        framedPath_ = _frameNodes(nodes);
    }

    function _lateSiblingReference(
        bytes32 _key,
        uint256 _keyIndex,
        bool _inlineStorageSiblings,
        uint8 _maximumWorkedRemainingNibbles,
        bytes memory _opaque
    )
        private
        pure
        returns (bytes memory reference_)
    {
        if (!_inlineStorageSiblings) return _opaque;
        uint256 remainingNibbles = 63 - _keyIndex;
        reference_ = remainingNibbles <= _maximumWorkedRemainingNibbles
            ? _maximumWorkStorageSubtree(_key, _keyIndex + 1, remainingNibbles)
            : leaf(_key, hex"01", _keyIndex + 1, remainingNibbles);
        assert(reference_.length < 32);
    }

    function _maximumWorkStorageSubtree(
        bytes32 _key,
        uint256 _start,
        uint256 _count
    )
        private
        pure
        returns (bytes memory best_)
    {
        require(_count != 0 && _start + _count <= 64, "fixture subtree range");
        best_ = leaf(_key, hex"01", _start, _count);
        uint256 bestScore = 3;

        for (uint256 extensionNibbles; extensionNibbles < _count; ++extensionNibbles) {
            uint256 leafSuffixNibbles = _count - extensionNibbles - 1;
            bytes memory childLeaf =
                leaf(_key, hex"01", _start + extensionNibbles + 1, leafSuffixNibbles);
            for (uint256 populatedChildren = 2; populatedChildren <= 16; ++populatedChildren) {
                bytes memory branch = _branchWithPopulatedLeaves(childLeaf, populatedChildren);
                if (branch.length >= 32) break;
                bytes memory candidate = extensionNibbles == 0
                    ? branch
                    : _extensionNode(_key, _start, extensionNibbles, branch);
                if (candidate.length >= 32) continue;

                uint256 score = 18 + populatedChildren * 2 + (extensionNibbles == 0 ? 0 : 2);
                if (score >= bestScore) {
                    bestScore = score;
                    best_ = candidate;
                }
            }
        }
    }

    function _branchWithSiblingReference(
        bytes32 _key,
        uint256 _keyIndex,
        bytes memory _selectedChild,
        bytes memory _siblingReference
    )
        private
        pure
        returns (bytes memory node_)
    {
        bytes[] memory items = new bytes[](17);
        for (uint256 childIndex; childIndex < 16; ++childIndex) {
            items[childIndex] = _siblingReference;
        }
        items[nibble(_key, _keyIndex)] = _selectedChild.length < 32
            ? _selectedChild
            : rlpBytes(abi.encodePacked(keccak256(_selectedChild)));
        items[16] = hex"80";
        return rlpList(items);
    }

    function _branchWithPopulatedLeaves(
        bytes memory _leaf,
        uint256 _populatedChildren
    )
        private
        pure
        returns (bytes memory node_)
    {
        bytes[] memory items = new bytes[](17);
        for (uint256 childIndex; childIndex < 16; ++childIndex) {
            if (childIndex < _populatedChildren) {
                items[childIndex] = _leaf;
            } else {
                items[childIndex] = hex"80";
            }
        }
        items[16] = hex"80";
        return rlpList(items);
    }

    function _extensionNode(
        bytes32 _key,
        uint256 _start,
        uint256 _count,
        bytes memory _child
    )
        private
        pure
        returns (bytes memory node_)
    {
        require(_count != 0, "fixture empty extension");
        bytes[] memory items = new bytes[](2);
        items[0] = rlpBytes(hexPrefix(_key, _start, _count, false));
        items[1] = _child.length < 32 ? _child : rlpBytes(abi.encodePacked(keccak256(_child)));
        return rlpList(items);
    }

    function _frameNodes(bytes[] memory _nodes) private pure returns (bytes memory framedPath_) {
        uint256 total;
        for (uint256 i; i < _nodes.length; ++i) {
            total += 2 + _nodes[i].length;
        }
        framedPath_ = new bytes(total);
        uint256 cursor;
        for (uint256 i; i < _nodes.length; ++i) {
            uint256 length = _nodes[i].length;
            framedPath_[cursor] = bytes1(uint8(length >> 8));
            framedPath_[cursor + 1] = bytes1(uint8(length));
            cursor += 2;
            for (uint256 j; j < length; ++j) {
                framedPath_[cursor + j] = _nodes[i][j];
            }
            cursor += length;
        }
    }

    function extensionStorageProof(
        bytes32 _key,
        bytes32 _value,
        bool _inline
    )
        internal
        pure
        returns (bytes memory framedPath_, bytes32 root_, uint256 leafLength_)
    {
        bytes memory leafNode = storageLeaf(_key, _value, 60, 4);
        bytes memory child = _inline ? leafNode : rlpBytes(abi.encodePacked(keccak256(leafNode)));
        bytes[] memory extensionItems = new bytes[](2);
        extensionItems[0] = rlpBytes(hexPrefix(_key, 0, 60, false));
        extensionItems[1] = child;
        bytes memory rootNode = rlpList(extensionItems);
        return (
            bytes.concat(framedNode(rootNode), framedNode(leafNode)),
            keccak256(rootNode),
            leafNode.length
        );
    }

    function storageLeaf(
        bytes32 _key,
        bytes32 _value,
        uint256 _start,
        uint256 _count
    )
        internal
        pure
        returns (bytes memory node_)
    {
        bytes memory scalar = rlpUint(_value);
        return leaf(_key, scalar, _start, _count);
    }

    function leaf(
        bytes32 _key,
        bytes memory _valueBytes,
        uint256 _start,
        uint256 _count
    )
        internal
        pure
        returns (bytes memory node_)
    {
        bytes[] memory items = new bytes[](2);
        items[0] = rlpBytes(hexPrefix(_key, _start, _count, true));
        items[1] = rlpBytes(_valueBytes);
        return rlpList(items);
    }

    function hexPrefix(
        bytes32 _key,
        uint256 _start,
        uint256 _count,
        bool _leaf
    )
        internal
        pure
        returns (bytes memory encoded_)
    {
        require(_start + _count <= 64, "fixture nibble range");
        bool odd = (_count & 1) != 0;
        encoded_ = new bytes((_count + (odd ? 1 : 2)) / 2);
        uint8 flag = (_leaf ? 2 : 0) + (odd ? 1 : 0);
        uint256 source = _start;
        uint256 destinationNibble;
        if (odd) {
            encoded_[0] = bytes1((flag << 4) | nibble(_key, source));
            ++source;
            destinationNibble = 2;
        } else {
            encoded_[0] = bytes1(flag << 4);
            destinationNibble = 2;
        }
        while (source < _start + _count) {
            uint256 byteIndex = destinationNibble / 2;
            encoded_[byteIndex] = bytes1((nibble(_key, source) << 4) | nibble(_key, source + 1));
            source += 2;
            destinationNibble += 2;
        }
    }

    function nibble(bytes32 _key, uint256 _index) internal pure returns (uint8 nibble_) {
        return uint8(uint256(_key) >> ((63 - _index) * 4)) & 0x0f;
    }

    function rlpUint(bytes32 _word) internal pure returns (bytes memory encoded_) {
        uint256 first;
        while (first < 32 && _word[first] == 0) ++first;
        require(first != 32, "fixture zero scalar");
        bytes memory minimal = new bytes(32 - first);
        for (uint256 i; i < minimal.length; ++i) {
            minimal[i] = _word[first + i];
        }
        return rlpBytes(minimal);
    }

    function rlpBytes(bytes memory _payload) internal pure returns (bytes memory encoded_) {
        if (_payload.length == 1 && uint8(_payload[0]) < 0x80) return _payload;
        return bytes.concat(lengthPrefix(false, _payload.length), _payload);
    }

    function rlpList(bytes[] memory _items) internal pure returns (bytes memory encoded_) {
        bytes memory payload;
        for (uint256 i; i < _items.length; ++i) {
            payload = bytes.concat(payload, _items[i]);
        }
        return bytes.concat(lengthPrefix(true, payload.length), payload);
    }

    function lengthPrefix(
        bool _list,
        uint256 _length
    )
        internal
        pure
        returns (bytes memory prefix_)
    {
        uint8 shortBase = _list ? 0xc0 : 0x80;
        uint8 longBase = _list ? 0xf7 : 0xb7;
        if (_length <= 55) return abi.encodePacked(bytes1(shortBase + uint8(_length)));
        if (_length <= type(uint8).max) {
            return abi.encodePacked(bytes1(longBase + 1), bytes1(uint8(_length)));
        }
        require(_length <= type(uint16).max, "fixture length");
        return abi.encodePacked(bytes1(longBase + 2), bytes2(uint16(_length)));
    }

    function framedNode(bytes memory _node) internal pure returns (bytes memory framed_) {
        require(_node.length <= type(uint16).max, "fixture node");
        return bytes.concat(be16(uint16(_node.length)), _node);
    }

    function be16(uint16 _value) internal pure returns (bytes memory encoded_) {
        return abi.encodePacked(bytes2(_value));
    }
}
