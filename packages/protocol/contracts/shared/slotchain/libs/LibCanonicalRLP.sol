// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Bounded canonical RLP decoding
/// @custom:security-contact security@taiko.xyz
library LibCanonicalRLP {
    uint256 internal constant MAX_CANONICAL_ITEM_BYTES = 2048;

    /// @dev A zero-copy view of one RLP item. All offsets are relative to the input byte array and
    ///      all lengths are measured in bytes.
    struct Item {
        bool isList;
        uint256 rawOffset;
        uint256 rawLength;
        uint256 payloadOffset;
        uint256 payloadLength;
    }

    /// @dev Decodes one canonically encoded RLP item inside `[offset,end)`. This validates the
    ///      item's own prefix and bounds, but callers that accept lists should use `decodeSingle`
    ///      when the canonicality of every nested item is required.
    /// @param _input The calldata byte array containing the item.
    /// @param _offset The item prefix offset.
    /// @param _end The exclusive container boundary.
    /// @return item_ The decoded zero-copy item view.
    function decodeItem(
        bytes calldata _input,
        uint256 _offset,
        uint256 _end
    )
        internal
        pure
        returns (Item memory item_)
    {
        if (_end > _input.length || _offset >= _end) revert RlpOutOfBounds();

        uint8 prefix = uint8(_input[_offset]);
        if (prefix <= 0x7f) {
            return Item(false, _offset, 1, _offset, 1);
        }

        if (prefix <= 0xb7) {
            uint256 shortStringLength = prefix - 0x80;
            uint256 shortStringOffset = _offset + 1;
            _requireAvailable(shortStringOffset, shortStringLength, _end);
            if (shortStringLength == 1 && uint8(_input[shortStringOffset]) <= 0x7f) {
                revert NonCanonicalRlp();
            }
            return Item(false, _offset, 1 + shortStringLength, shortStringOffset, shortStringLength);
        }

        if (prefix <= 0xbf) {
            uint256 stringLengthOfLength = prefix - 0xb7;
            (uint256 longStringOffset, uint256 longStringLength) =
                _decodeLongLength(_input, _offset, _end, stringLengthOfLength);
            if (longStringLength < 56) revert NonCanonicalRlp();
            return Item(
                false,
                _offset,
                1 + stringLengthOfLength + longStringLength,
                longStringOffset,
                longStringLength
            );
        }

        if (prefix <= 0xf7) {
            uint256 shortListLength = prefix - 0xc0;
            uint256 shortListOffset = _offset + 1;
            _requireAvailable(shortListOffset, shortListLength, _end);
            return Item(true, _offset, 1 + shortListLength, shortListOffset, shortListLength);
        }

        uint256 listLengthOfLength = prefix - 0xf7;
        (uint256 longListOffset, uint256 longListLength) =
            _decodeLongLength(_input, _offset, _end, listLengthOfLength);
        if (longListLength < 56) revert NonCanonicalRlp();
        return Item(
            true, _offset, 1 + listLengthOfLength + longListLength, longListOffset, longListLength
        );
    }

    /// @dev Decodes exactly one RLP item in `[offset,end)` and iteratively validates every nested
    ///      item. The fixed byte bound prevents adversarial memory growth and covers the largest
    ///      frozen Slot Chain RLP carrier (2,048 bytes).
    /// @param _input The calldata byte array containing the item.
    /// @param _offset The item prefix offset.
    /// @param _end The exclusive item boundary.
    /// @return item_ The decoded zero-copy root item view.
    function decodeSingle(
        bytes calldata _input,
        uint256 _offset,
        uint256 _end
    )
        internal
        pure
        returns (Item memory item_)
    {
        return decodeSingleBounded(_input, _offset, _end, MAX_CANONICAL_ITEM_BYTES);
    }

    /// @dev Decodes exactly one recursively canonical RLP item with an explicit nesting bound.
    ///      Protocol consumers with a stricter structural bound should use this entry point to
    ///      avoid allocating the 2,048-entry stack needed by otherwise uninterpreted carriers.
    /// @param _input The calldata byte array containing the item.
    /// @param _offset The item prefix offset.
    /// @param _end The exclusive item boundary.
    /// @param _maximumNestingDepth The nonzero maximum number of simultaneously open lists.
    /// @return item_ The decoded zero-copy root item view.
    function decodeSingleBounded(
        bytes calldata _input,
        uint256 _offset,
        uint256 _end,
        uint256 _maximumNestingDepth
    )
        internal
        pure
        returns (Item memory item_)
    {
        if (_end < _offset || _end - _offset > MAX_CANONICAL_ITEM_BYTES) {
            revert RlpItemTooLarge();
        }
        if (_maximumNestingDepth == 0 || _maximumNestingDepth > MAX_CANONICAL_ITEM_BYTES) {
            revert InvalidRlpNestingBound();
        }

        item_ = decodeItem(_input, _offset, _end);
        if (next(item_) != _end) revert TrailingRlpBytes();
        if (!item_.isList) return item_;

        uint256[] memory containerEnds = new uint256[](_maximumNestingDepth);
        uint256 depth = 1;
        containerEnds[0] = item_.payloadOffset + item_.payloadLength;
        uint256 cursor = item_.payloadOffset;

        while (depth != 0) {
            uint256 containerEnd = containerEnds[depth - 1];
            if (cursor == containerEnd) {
                unchecked {
                    --depth;
                }
                continue;
            }
            if (cursor > containerEnd) revert RlpOutOfBounds();

            Item memory child = decodeItem(_input, cursor, containerEnd);
            cursor = next(child);
            if (child.isList) {
                if (depth == _maximumNestingDepth) revert RlpNestingTooDeep();
                containerEnds[depth] = child.payloadOffset + child.payloadLength;
                unchecked {
                    ++depth;
                }
                cursor = child.payloadOffset;
            }
        }
    }

    /// @dev Returns the exclusive raw end of an item.
    /// @param _item The decoded item.
    /// @return offset_ The first byte after the encoded item.
    function next(Item memory _item) internal pure returns (uint256 offset_) {
        unchecked {
            return _item.rawOffset + _item.rawLength;
        }
    }

    /// @dev Reads an exact 32-byte RLP byte string.
    /// @param _input The calldata byte array containing the item.
    /// @param _item The decoded item.
    /// @return value_ The exact payload bytes.
    function readBytes32(
        bytes calldata _input,
        Item memory _item
    )
        internal
        pure
        returns (bytes32 value_)
    {
        if (_item.isList || _item.payloadLength != 32) revert InvalidRlpBytes32();
        assembly ("memory-safe") {
            value_ := calldataload(add(_input.offset, mload(add(_item, 0x60))))
        }
    }

    /// @dev Reads a canonical minimally encoded unsigned integer of at most 32 bytes. The empty
    ///      RLP byte string is zero; a one-byte zero payload is rejected as nonminimal.
    /// @param _input The calldata byte array containing the item.
    /// @param _item The decoded item.
    /// @return value_ The decoded unsigned integer.
    function readUint(
        bytes calldata _input,
        Item memory _item
    )
        internal
        pure
        returns (uint256 value_)
    {
        if (_item.isList || _item.payloadLength > 32) revert InvalidRlpInteger();
        uint256 length = _item.payloadLength;
        if (length == 0) return 0;
        if (_input[_item.payloadOffset] == 0) revert InvalidRlpInteger();

        uint256 payloadOffset = _item.payloadOffset;
        assembly ("memory-safe") {
            value_ := shr(mul(sub(32, length), 8), calldataload(add(_input.offset, payloadOffset)))
        }
    }

    /// @dev Reads a canonical minimally encoded uint64.
    /// @param _input The calldata byte array containing the item.
    /// @param _item The decoded item.
    /// @return value_ The decoded uint64.
    function readUint64(
        bytes calldata _input,
        Item memory _item
    )
        internal
        pure
        returns (uint64 value_)
    {
        uint256 value = readUint(_input, _item);
        if (value > type(uint64).max) revert InvalidRlpUint64();
        return uint64(value);
    }

    /// @dev Decodes a long-form payload length and verifies that it fits within its container.
    function _decodeLongLength(
        bytes calldata _input,
        uint256 _offset,
        uint256 _end,
        uint256 _lengthOfLength
    )
        private
        pure
        returns (uint256 payloadOffset_, uint256 payloadLength_)
    {
        uint256 lengthOffset = _offset + 1;
        _requireAvailable(lengthOffset, _lengthOfLength, _end);
        if (_input[lengthOffset] == 0) revert NonCanonicalRlp();

        for (uint256 i; i < _lengthOfLength; ++i) {
            payloadLength_ = (payloadLength_ << 8) | uint8(_input[lengthOffset + i]);
        }
        payloadOffset_ = lengthOffset + _lengthOfLength;
        _requireAvailable(payloadOffset_, payloadLength_, _end);
    }

    /// @dev Requires `[offset,offset+length)` to fit within `end` without overflowing.
    function _requireAvailable(
        uint256 _offset,
        uint256 _length,
        uint256 _end
    )
        private
        pure
    {
        if (_offset > _end || _length > _end - _offset) revert RlpOutOfBounds();
    }

    error RlpOutOfBounds();
    error NonCanonicalRlp();
    error TrailingRlpBytes();
    error RlpItemTooLarge();
    error RlpNestingTooDeep();
    error InvalidRlpNestingBound();
    error InvalidRlpBytes32();
    error InvalidRlpInteger();
    error InvalidRlpUint64();
}
