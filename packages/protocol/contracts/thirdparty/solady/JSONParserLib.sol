// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Library for parsing JSONs.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/JSONParserLib.sol)
library JSONParserLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The input is invalid.
    error ParsingFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // There are 6 types of variables in JSON (excluding undefined).

    /// @dev For denoting that an item has not been initialized.
    /// A item returned from `parse` will never be of an undefined type.
    /// Parsing a invalid JSON string will simply revert.
    uint8 internal constant TYPE_UNDEFINED = 0;

    /// @dev Type representing an array (e.g. `[1,2,3]`).
    uint8 internal constant TYPE_ARRAY = 1;

    /// @dev Type representing an object (e.g. `{"a":"A","b":"B"}`).
    uint8 internal constant TYPE_OBJECT = 2;

    /// @dev Type representing a number (e.g. `-1.23e+21`).
    uint8 internal constant TYPE_NUMBER = 3;

    /// @dev Type representing a string (e.g. `"hello"`).
    uint8 internal constant TYPE_STRING = 4;

    /// @dev Type representing a boolean (i.e. `true` or `false`).
    uint8 internal constant TYPE_BOOLEAN = 5;

    /// @dev Type representing null (i.e. `null`).
    uint8 internal constant TYPE_NULL = 6;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev A pointer to a parsed JSON node.
    struct Item {
        // Do NOT modify the `_data` directly.
        uint256 _data;
    }

    // Private constants for packing `_data`.

    uint256 private constant _BITPOS_STRING = 32 * 7 - 8;
    uint256 private constant _BITPOS_KEY_LENGTH = 32 * 6 - 8;
    uint256 private constant _BITPOS_KEY = 32 * 5 - 8;
    uint256 private constant _BITPOS_VALUE_LENGTH = 32 * 4 - 8;
    uint256 private constant _BITPOS_VALUE = 32 * 3 - 8;
    uint256 private constant _BITPOS_CHILD = 32 * 2 - 8;
    uint256 private constant _BITPOS_SIBLING_OR_PARENT = 32 * 1 - 8;
    uint256 private constant _BITMASK_POINTER = 0xffffffff;
    uint256 private constant _BITMASK_TYPE = 7;
    uint256 private constant _KEY_INITED = 1 << 3;
    uint256 private constant _VALUE_INITED = 1 << 4;
    uint256 private constant _CHILDREN_INITED = 1 << 5;
    uint256 private constant _PARENT_IS_ARRAY = 1 << 6;
    uint256 private constant _PARENT_IS_OBJECT = 1 << 7;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   JSON PARSING OPERATION                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Parses the JSON string `s`, and returns the root.
    /// Reverts if `s` is not a valid JSON as specified in RFC 8259.
    /// Object items WILL simply contain all their children, inclusive of repeated keys,
    /// in the same order which they appear in the JSON string.
    ///
    /// Note: For efficiency, this function WILL NOT make a copy of `s`.
    /// The parsed tree WILL contain offsets to `s`.
    /// Do NOT pass in a string that WILL be modified later on.
    function parse(string memory s) internal pure returns (Item memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result) // We will use our own allocation instead.
        }
        bytes32 r = _query(_toInput(s), 255);
        /// @solidity memory-safe-assembly
        assembly {
            result := r
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    JSON ITEM OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Note:
    // - An item is a node in the JSON tree.
    // - The value of a string item WILL be double-quoted, JSON encoded.
    // - We make a distinction between `index` and `key`.
    //   - Items in arrays are located by `index` (uint256).
    //   - Items in objects are located by `key` (string).
    // - Keys are always strings, double-quoted, JSON encoded.
    //
    // These design choices are made to balance between efficiency and ease-of-use.

    /// @dev Returns the string value of the item.
    /// This is its exact string representation in the original JSON string.
    /// The returned string WILL have leading and trailing whitespace trimmed.
    /// All inner whitespace WILL be preserved, exactly as it is in the original JSON string.
    /// If the item's type is string, the returned string WILL be double-quoted, JSON encoded.
    ///
    /// Note: This function lazily instantiates and caches the returned string.
    /// Do NOT modify the returned string.
    function value(Item memory item) internal pure returns (string memory result) {
        bytes32 r = _query(_toInput(item), 0);
        /// @solidity memory-safe-assembly
        assembly {
            result := r
        }
    }

    /// @dev Returns the index of the item in the array.
    /// It the item's parent is not an array, returns 0.
    function index(Item memory item) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            if and(mload(item), _PARENT_IS_ARRAY) {
                result := and(_BITMASK_POINTER, shr(_BITPOS_KEY, mload(item)))
            }
        }
    }

    /// @dev Returns the key of the item in the object.
    /// It the item's parent is not an object, returns an empty string.
    /// The returned string WILL be double-quoted, JSON encoded.
    ///
    /// Note: This function lazily instantiates and caches the returned string.
    /// Do NOT modify the returned string.
    function key(Item memory item) internal pure returns (string memory result) {
        if (item._data & _PARENT_IS_OBJECT != 0) {
            bytes32 r = _query(_toInput(item), 1);
            /// @solidity memory-safe-assembly
            assembly {
                result := r
            }
        }
    }

    /// @dev Returns the key of the item in the object.
    /// It the item is neither an array nor object, returns an empty array.
    ///
    /// Note: This function lazily instantiates and caches the returned array.
    /// Do NOT modify the returned array.
    function children(Item memory item) internal pure returns (Item[] memory result) {
        bytes32 r = _query(_toInput(item), 3);
        /// @solidity memory-safe-assembly
        assembly {
            result := r
        }
    }

    /// @dev Returns the number of children.
    /// It the item is neither an array nor object, returns zero.
    function size(Item memory item) internal pure returns (uint256 result) {
        bytes32 r = _query(_toInput(item), 3);
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(r)
        }
    }

    /// @dev Returns the item at index `i` for (array).
    /// If `item` is not an array, the result's type WILL be undefined.
    /// If there is no item with the index, the result's type WILL be undefined.
    function at(Item memory item, uint256 i) internal pure returns (Item memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result) // Free the default allocation. We'll allocate manually.
        }
        bytes32 r = _query(_toInput(item), 3);
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(r, 0x20), shl(5, i)))
            if iszero(and(lt(i, mload(r)), eq(and(mload(item), _BITMASK_TYPE), TYPE_ARRAY))) {
                result := 0x60 // Reset to the zero pointer.
            }
        }
    }

    /// @dev Returns the item at key `k` for (object).
    /// If `item` is not an object, the result's type WILL be undefined.
    /// The key MUST be double-quoted, JSON encoded. This is for efficiency reasons.
    /// - Correct : `item.at('"k"')`.
    /// - Wrong   : `item.at("k")`.
    /// For duplicated keys, the last item with the key WILL be returned.
    /// If there is no item with the key, the result's type WILL be undefined.
    function at(Item memory item, string memory k) internal pure returns (Item memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result) // Free the default allocation. We'll allocate manually.
            result := 0x60 // Initialize to the zero pointer.
        }
        if (isObject(item)) {
            bytes32 kHash = keccak256(bytes(k));
            Item[] memory r = children(item);
            // We'll just do a linear search. The alternatives are very bloated.
            for (uint256 i = r.length << 5; i != 0;) {
                /// @solidity memory-safe-assembly
                assembly {
                    item := mload(add(r, i))
                    i := sub(i, 0x20)
                }
                if (keccak256(bytes(key(item))) != kHash) continue;
                result = item;
                break;
            }
        }
    }

    /// @dev Returns the item's type.
    function getType(Item memory item) internal pure returns (uint8 result) {
        result = uint8(item._data & _BITMASK_TYPE);
    }

    /// Note: All types are mutually exclusive.

    /// @dev Returns whether the item is of type undefined.
    function isUndefined(Item memory item) internal pure returns (bool result) {
        result = item._data & _BITMASK_TYPE == TYPE_UNDEFINED;
    }

    /// @dev Returns whether the item is of type array.
    function isArray(Item memory item) internal pure returns (bool result) {
        result = item._data & _BITMASK_TYPE == TYPE_ARRAY;
    }

    /// @dev Returns whether the item is of type object.
    function isObject(Item memory item) internal pure returns (bool result) {
        result = item._data & _BITMASK_TYPE == TYPE_OBJECT;
    }

    /// @dev Returns whether the item is of type number.
    function isNumber(Item memory item) internal pure returns (bool result) {
        result = item._data & _BITMASK_TYPE == TYPE_NUMBER;
    }

    /// @dev Returns whether the item is of type string.
    function isString(Item memory item) internal pure returns (bool result) {
        result = item._data & _BITMASK_TYPE == TYPE_STRING;
    }

    /// @dev Returns whether the item is of type boolean.
    function isBoolean(Item memory item) internal pure returns (bool result) {
        result = item._data & _BITMASK_TYPE == TYPE_BOOLEAN;
    }

    /// @dev Returns whether the item is of type null.
    function isNull(Item memory item) internal pure returns (bool result) {
        result = item._data & _BITMASK_TYPE == TYPE_NULL;
    }

    /// @dev Returns the item's parent.
    /// If the item does not have a parent, the result's type will be undefined.
    function parent(Item memory item) internal pure returns (Item memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result) // Free the default allocation. We've already allocated.
            result := and(shr(_BITPOS_SIBLING_OR_PARENT, mload(item)), _BITMASK_POINTER)
            if iszero(result) { result := 0x60 } // Reset to the zero pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UTILITY FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Parses an unsigned integer from a string (in decimal, i.e. base 10).
    /// Reverts if `s` is not a valid uint256 string matching the RegEx `^[0-9]+$`,
    /// or if the parsed number is too big for a uint256.
    function parseUint(string memory s) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(s)
            let preMulOverflowThres := div(not(0), 10)
            for { let i := 0 } 1 { } {
                i := add(i, 1)
                let digit := sub(and(mload(add(s, i)), 0xff), 48)
                let mulOverflowed := gt(result, preMulOverflowThres)
                let product := mul(10, result)
                result := add(product, digit)
                n := mul(n, iszero(or(or(mulOverflowed, lt(result, product)), gt(digit, 9))))
                if iszero(lt(i, n)) { break }
            }
            if iszero(n) {
                mstore(0x00, 0x10182796) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Parses a signed integer from a string (in decimal, i.e. base 10).
    /// Reverts if `s` is not a valid int256 string matching the RegEx `^[+-]?[0-9]+$`,
    /// or if the parsed number cannot fit within `[-2**255 .. 2**255 - 1]`.
    function parseInt(string memory s) internal pure returns (int256 result) {
        uint256 n = bytes(s).length;
        uint256 sign;
        uint256 isNegative;
        /// @solidity memory-safe-assembly
        assembly {
            if n {
                let c := and(mload(add(s, 1)), 0xff)
                isNegative := eq(c, 45)
                if or(eq(c, 43), isNegative) {
                    sign := c
                    s := add(s, 1)
                    mstore(s, sub(n, 1))
                }
                if iszero(or(sign, lt(sub(c, 48), 10))) { s := 0x60 }
            }
        }
        uint256 x = parseUint(s);
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(lt(x, add(shl(255, 1), isNegative))) {
                mstore(0x00, 0x10182796) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
            if sign {
                mstore(s, sign)
                s := sub(s, 1)
                mstore(s, n)
            }
            result := xor(x, mul(xor(x, add(not(x), 1)), isNegative))
        }
    }

    /// @dev Parses an unsigned integer from a string (in hexadecimal, i.e. base 16).
    /// Reverts if `s` is not a valid uint256 hex string matching the RegEx
    /// `^(0[xX])?[0-9a-fA-F]+$`, or if the parsed number cannot fit within `[0 .. 2**256 - 1]`.
    function parseUintFromHex(string memory s) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(s)
            // Skip two if starts with '0x' or '0X'.
            let i := shl(1, and(eq(0x3078, or(shr(240, mload(add(s, 0x20))), 0x20)), gt(n, 1)))
            for { } 1 { } {
                i := add(i, 1)
                let c :=
                    byte(
                        and(0x1f, shr(and(mload(add(s, i)), 0xff), 0x3e4088843e41bac000000000000)),
                        0x3010a071000000b0104040208000c05090d060e0f
                    )
                n := mul(n, iszero(or(iszero(c), shr(252, result))))
                result := add(shl(4, result), sub(c, 1))
                if iszero(lt(i, n)) { break }
            }
            if iszero(n) {
                mstore(0x00, 0x10182796) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Decodes a JSON encoded string.
    /// The string MUST be double-quoted, JSON encoded.
    /// Reverts if the string is invalid.
    /// As you can see, it's pretty complex for a deceptively simple looking task.
    function decodeString(string memory s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            function fail() {
                mstore(0x00, 0x10182796) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }

            function decodeUnicodeEscapeSequence(pIn_, end_) -> _unicode, _pOut {
                _pOut := add(pIn_, 4)
                let b_ := iszero(gt(_pOut, end_))
                let t_ := mload(pIn_) // Load the whole word.
                for { let i_ := 0 } iszero(eq(i_, 4)) { i_ := add(i_, 1) } {
                    let c_ := sub(byte(i_, t_), 48)
                    if iszero(and(shr(c_, 0x7e0000007e03ff), b_)) { fail() } // Not hexadecimal.
                    c_ := sub(c_, add(mul(gt(c_, 16), 7), shl(5, gt(c_, 48))))
                    _unicode := add(shl(4, _unicode), c_)
                }
            }

            function decodeUnicodeCodePoint(pIn_, end_) -> _unicode, _pOut {
                _unicode, _pOut := decodeUnicodeEscapeSequence(pIn_, end_)
                if iszero(or(lt(_unicode, 0xd800), gt(_unicode, 0xdbff))) {
                    let t_ := mload(_pOut) // Load the whole word.
                    end_ := mul(end_, eq(shr(240, t_), 0x5c75)) // Fail if not starting with '\\u'.
                    t_, _pOut := decodeUnicodeEscapeSequence(add(_pOut, 2), end_)
                    _unicode := add(0x10000, add(shl(10, and(0x3ff, _unicode)), and(0x3ff, t_)))
                }
            }

            function appendCodePointAsUTF8(pIn_, c_) -> _pOut {
                if iszero(gt(c_, 0x7f)) {
                    mstore8(pIn_, c_)
                    _pOut := add(pIn_, 1)
                    leave
                }
                mstore8(0x1f, c_)
                mstore8(0x1e, shr(6, c_))
                if iszero(gt(c_, 0x7ff)) {
                    mstore(pIn_, shl(240, or(0xc080, and(0x1f3f, mload(0x00)))))
                    _pOut := add(pIn_, 2)
                    leave
                }
                mstore8(0x1d, shr(12, c_))
                if iszero(gt(c_, 0xffff)) {
                    mstore(pIn_, shl(232, or(0xe08080, and(0x0f3f3f, mload(0x00)))))
                    _pOut := add(pIn_, 3)
                    leave
                }
                mstore8(0x1c, shr(18, c_))
                mstore(pIn_, shl(224, or(0xf0808080, and(0x073f3f3f, mload(0x00)))))
                _pOut := add(pIn_, shl(2, lt(c_, 0x110000)))
            }

            function chr(p_) -> _c {
                _c := byte(0, mload(p_))
            }

            let n := mload(s)
            let end := add(add(s, n), 0x1f)
            if iszero(and(gt(n, 1), eq(0x2222, or(and(0xff00, mload(add(s, 2))), chr(end))))) {
                fail() // Fail if not double-quoted.
            }
            let out := add(mload(0x40), 0x20)
            for { let curr := add(s, 0x21) } iszero(eq(curr, end)) { } {
                let c := chr(curr)
                curr := add(curr, 1)
                // Not '\\'.
                if iszero(eq(c, 92)) {
                    // Not '"'.
                    if iszero(eq(c, 34)) {
                        mstore8(out, c)
                        out := add(out, 1)
                        continue
                    }
                    curr := end
                }
                if iszero(eq(curr, end)) {
                    let escape := chr(curr)
                    curr := add(curr, 1)
                    // '"', '/', '\\'.
                    if and(shr(escape, 0x100000000000800400000000), 1) {
                        mstore8(out, escape)
                        out := add(out, 1)
                        continue
                    }
                    // 'u'.
                    if eq(escape, 117) {
                        escape, curr := decodeUnicodeCodePoint(curr, end)
                        out := appendCodePointAsUTF8(out, escape)
                        continue
                    }
                    // `{'b':'\b', 'f':'\f', 'n':'\n', 'r':'\r', 't':'\t'}`.
                    escape := byte(sub(escape, 85), 0x080000000c000000000000000a0000000d0009)
                    if escape {
                        mstore8(out, escape)
                        out := add(out, 1)
                        continue
                    }
                }
                fail()
                break
            }
            mstore(out, 0) // Zeroize the last slot.
            result := mload(0x40)
            mstore(result, sub(out, add(result, 0x20))) // Store the length.
            mstore(0x40, add(out, 0x20)) // Allocate the memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Performs a query on the input with the given mode.
    function _query(bytes32 input, uint256 mode) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            function fail() {
                mstore(0x00, 0x10182796) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }

            function chr(p_) -> _c {
                _c := byte(0, mload(p_))
            }

            function skipWhitespace(pIn_, end_) -> _pOut {
                for { _pOut := pIn_ } 1 { _pOut := add(_pOut, 1) } {
                    if iszero(and(shr(chr(_pOut), 0x100002600), 1)) { leave } // Not in ' \n\r\t'.
                }
            }

            function setP(packed_, bitpos_, p_) -> _packed {
                // Perform an out-of-gas revert if `p_` exceeds `_BITMASK_POINTER`.
                returndatacopy(returndatasize(), returndatasize(), gt(p_, _BITMASK_POINTER))
                _packed := or(and(not(shl(bitpos_, _BITMASK_POINTER)), packed_), shl(bitpos_, p_))
            }

            function getP(packed_, bitpos_) -> _p {
                _p := and(_BITMASK_POINTER, shr(bitpos_, packed_))
            }

            function mallocItem(s_, packed_, pStart_, pCurr_, type_) -> _item {
                _item := mload(0x40)
                // forgefmt: disable-next-item
                packed_ := setP(setP(packed_, _BITPOS_VALUE, sub(pStart_, add(s_, 0x20))),
                    _BITPOS_VALUE_LENGTH, sub(pCurr_, pStart_))
                mstore(_item, or(packed_, type_))
                mstore(0x40, add(_item, 0x20)) // Allocate memory.
            }

            function parseValue(s_, sibling_, pIn_, end_) -> _item, _pOut {
                let packed_ := setP(mload(0x00), _BITPOS_SIBLING_OR_PARENT, sibling_)
                _pOut := skipWhitespace(pIn_, end_)
                if iszero(lt(_pOut, end_)) { leave }
                for { let c_ := chr(_pOut) } 1 { } {
                    // If starts with '"'.
                    if eq(c_, 34) {
                        let pStart_ := _pOut
                        _pOut := parseStringSub(s_, packed_, _pOut, end_)
                        _item := mallocItem(s_, packed_, pStart_, _pOut, TYPE_STRING)
                        break
                    }
                    // If starts with '['.
                    if eq(c_, 91) {
                        _item, _pOut := parseArray(s_, packed_, _pOut, end_)
                        break
                    }
                    // If starts with '{'.
                    if eq(c_, 123) {
                        _item, _pOut := parseObject(s_, packed_, _pOut, end_)
                        break
                    }
                    // If starts with any in '0123456789-'.
                    if and(shr(c_, shl(45, 0x1ff9)), 1) {
                        _item, _pOut := parseNumber(s_, packed_, _pOut, end_)
                        break
                    }
                    if iszero(gt(add(_pOut, 4), end_)) {
                        let pStart_ := _pOut
                        let w_ := shr(224, mload(_pOut))
                        // 'true' in hex format.
                        if eq(w_, 0x74727565) {
                            _pOut := add(_pOut, 4)
                            _item := mallocItem(s_, packed_, pStart_, _pOut, TYPE_BOOLEAN)
                            break
                        }
                        // 'null' in hex format.
                        if eq(w_, 0x6e756c6c) {
                            _pOut := add(_pOut, 4)
                            _item := mallocItem(s_, packed_, pStart_, _pOut, TYPE_NULL)
                            break
                        }
                    }
                    if iszero(gt(add(_pOut, 5), end_)) {
                        let pStart_ := _pOut
                        let w_ := shr(216, mload(_pOut))
                        // 'false' in hex format.
                        if eq(w_, 0x66616c7365) {
                            _pOut := add(_pOut, 5)
                            _item := mallocItem(s_, packed_, pStart_, _pOut, TYPE_BOOLEAN)
                            break
                        }
                    }
                    fail()
                    break
                }
                _pOut := skipWhitespace(_pOut, end_)
            }

            function parseArray(s_, packed_, pIn_, end_) -> _item, _pOut {
                let j_ := 0
                for { _pOut := add(pIn_, 1) } 1 { _pOut := add(_pOut, 1) } {
                    if iszero(lt(_pOut, end_)) { fail() }
                    if iszero(_item) {
                        _pOut := skipWhitespace(_pOut, end_)
                        if eq(chr(_pOut), 93) { break } // ']'.
                    }
                    _item, _pOut := parseValue(s_, _item, _pOut, end_)
                    if _item {
                        // forgefmt: disable-next-item
                        mstore(_item, setP(or(_PARENT_IS_ARRAY, mload(_item)),
                            _BITPOS_KEY, j_))
                        j_ := add(j_, 1)
                        let c_ := chr(_pOut)
                        if eq(c_, 93) { break } // ']'.
                        if eq(c_, 44) { continue } // ','.
                    }
                    _pOut := end_
                }
                _pOut := add(_pOut, 1)
                packed_ := setP(packed_, _BITPOS_CHILD, _item)
                _item := mallocItem(s_, packed_, pIn_, _pOut, TYPE_ARRAY)
            }

            function parseObject(s_, packed_, pIn_, end_) -> _item, _pOut {
                for { _pOut := add(pIn_, 1) } 1 { _pOut := add(_pOut, 1) } {
                    if iszero(lt(_pOut, end_)) { fail() }
                    if iszero(_item) {
                        _pOut := skipWhitespace(_pOut, end_)
                        if eq(chr(_pOut), 125) { break } // '}'.
                    }
                    _pOut := skipWhitespace(_pOut, end_)
                    let pKeyStart_ := _pOut
                    let pKeyEnd_ := parseStringSub(s_, _item, _pOut, end_)
                    _pOut := skipWhitespace(pKeyEnd_, end_)
                    // If ':'.
                    if eq(chr(_pOut), 58) {
                        _item, _pOut := parseValue(s_, _item, add(_pOut, 1), end_)
                        if _item {
                            // forgefmt: disable-next-item
                            mstore(_item, setP(setP(or(_PARENT_IS_OBJECT, mload(_item)),
                                _BITPOS_KEY_LENGTH, sub(pKeyEnd_, pKeyStart_)),
                                    _BITPOS_KEY, sub(pKeyStart_, add(s_, 0x20))))
                            let c_ := chr(_pOut)
                            if eq(c_, 125) { break } // '}'.
                            if eq(c_, 44) { continue } // ','.
                        }
                    }
                    _pOut := end_
                }
                _pOut := add(_pOut, 1)
                packed_ := setP(packed_, _BITPOS_CHILD, _item)
                _item := mallocItem(s_, packed_, pIn_, _pOut, TYPE_OBJECT)
            }

            function checkStringU(p_, o_) {
                // If not in '0123456789abcdefABCDEF', revert.
                if iszero(and(shr(sub(chr(add(p_, o_)), 48), 0x7e0000007e03ff), 1)) { fail() }
                if iszero(eq(o_, 5)) { checkStringU(p_, add(o_, 1)) }
            }

            function parseStringSub(s_, packed_, pIn_, end_) -> _pOut {
                if iszero(lt(pIn_, end_)) { fail() }
                for { _pOut := add(pIn_, 1) } 1 { } {
                    let c_ := chr(_pOut)
                    if eq(c_, 34) { break } // '"'.
                    // Not '\'.
                    if iszero(eq(c_, 92)) {
                        _pOut := add(_pOut, 1)
                        continue
                    }
                    c_ := chr(add(_pOut, 1))
                    // '"', '\', '//', 'b', 'f', 'n', 'r', 't'.
                    if and(shr(sub(c_, 34), 0x510110400000000002001), 1) {
                        _pOut := add(_pOut, 2)
                        continue
                    }
                    // 'u'.
                    if eq(c_, 117) {
                        checkStringU(_pOut, 2)
                        _pOut := add(_pOut, 6)
                        continue
                    }
                    _pOut := end_
                    break
                }
                if iszero(lt(_pOut, end_)) { fail() }
                _pOut := add(_pOut, 1)
            }

            function skip0To9s(pIn_, end_, atLeastOne_) -> _pOut {
                for { _pOut := pIn_ } 1 { _pOut := add(_pOut, 1) } {
                    if iszero(lt(sub(chr(_pOut), 48), 10)) { break } // Not '0'..'9'.
                }
                if and(atLeastOne_, eq(pIn_, _pOut)) { fail() }
            }

            function parseNumber(s_, packed_, pIn_, end_) -> _item, _pOut {
                _pOut := pIn_
                if eq(chr(_pOut), 45) { _pOut := add(_pOut, 1) } // '-'.
                if iszero(lt(sub(chr(_pOut), 48), 10)) { fail() } // Not '0'..'9'.
                let c_ := chr(_pOut)
                _pOut := add(_pOut, 1)
                if iszero(eq(c_, 48)) { _pOut := skip0To9s(_pOut, end_, 0) } // Not '0'.
                if eq(chr(_pOut), 46) { _pOut := skip0To9s(add(_pOut, 1), end_, 1) } // '.'.
                let t_ := mload(_pOut)
                // 'E', 'e'.
                if eq(or(0x20, byte(0, t_)), 101) {
                    // forgefmt: disable-next-item
                    _pOut := skip0To9s(add(byte(sub(byte(1, t_), 14), 0x010001), // '+', '-'.
                        add(_pOut, 1)), end_, 1)
                }
                _item := mallocItem(s_, packed_, pIn_, _pOut, TYPE_NUMBER)
            }

            function copyStr(s_, offset_, len_) -> _sCopy {
                _sCopy := mload(0x40)
                s_ := add(s_, offset_)
                let w_ := not(0x1f)
                for { let i_ := and(add(len_, 0x1f), w_) } 1 { } {
                    mstore(add(_sCopy, i_), mload(add(s_, i_)))
                    i_ := add(i_, w_) // `sub(i_, 0x20)`.
                    if iszero(i_) { break }
                }
                mstore(_sCopy, len_) // Copy the length.
                mstore(add(add(_sCopy, 0x20), len_), 0) // Zeroize the last slot.
                mstore(0x40, add(add(_sCopy, 0x40), len_)) // Allocate memory.
            }

            function value(item_) -> _value {
                let packed_ := mload(item_)
                _value := getP(packed_, _BITPOS_VALUE) // The offset in the string.
                if iszero(and(_VALUE_INITED, packed_)) {
                    let s_ := getP(packed_, _BITPOS_STRING)
                    _value := copyStr(s_, _value, getP(packed_, _BITPOS_VALUE_LENGTH))
                    packed_ := setP(packed_, _BITPOS_VALUE, _value)
                    mstore(s_, or(_VALUE_INITED, packed_))
                }
            }

            function children(item_) -> _arr {
                _arr := 0x60 // Initialize to the zero pointer.
                let packed_ := mload(item_)
                for { } iszero(gt(and(_BITMASK_TYPE, packed_), TYPE_OBJECT)) { } {
                    if or(iszero(packed_), iszero(item_)) { break }
                    if and(packed_, _CHILDREN_INITED) {
                        _arr := getP(packed_, _BITPOS_CHILD)
                        break
                    }
                    _arr := mload(0x40)
                    let o_ := add(_arr, 0x20)
                    for { let h_ := getP(packed_, _BITPOS_CHILD) } h_ { } {
                        mstore(o_, h_)
                        let q_ := mload(h_)
                        let y_ := getP(q_, _BITPOS_SIBLING_OR_PARENT)
                        mstore(h_, setP(q_, _BITPOS_SIBLING_OR_PARENT, item_))
                        h_ := y_
                        o_ := add(o_, 0x20)
                    }
                    let w_ := not(0x1f)
                    let n_ := add(w_, sub(o_, _arr))
                    mstore(_arr, shr(5, n_))
                    mstore(0x40, o_) // Allocate memory.
                    packed_ := setP(packed_, _BITPOS_CHILD, _arr)
                    mstore(item_, or(_CHILDREN_INITED, packed_))
                    // Reverse the array.
                    if iszero(lt(n_, 0x40)) {
                        let lo_ := add(_arr, 0x20)
                        let hi_ := add(_arr, n_)
                        for { } 1 { } {
                            let temp_ := mload(lo_)
                            mstore(lo_, mload(hi_))
                            mstore(hi_, temp_)
                            hi_ := add(hi_, w_)
                            lo_ := add(lo_, 0x20)
                            if iszero(lt(lo_, hi_)) { break }
                        }
                    }
                    break
                }
            }

            function getStr(item_, bitpos_, bitposLength_, bitmaskInited_) -> _result {
                _result := 0x60 // Initialize to the zero pointer.
                let packed_ := mload(item_)
                if or(iszero(item_), iszero(packed_)) { leave }
                _result := getP(packed_, bitpos_)
                if iszero(and(bitmaskInited_, packed_)) {
                    let s_ := getP(packed_, _BITPOS_STRING)
                    _result := copyStr(s_, _result, getP(packed_, bitposLength_))
                    mstore(item_, or(bitmaskInited_, setP(packed_, bitpos_, _result)))
                }
            }

            switch mode
            // Get value.
            case 0 { result := getStr(input, _BITPOS_VALUE, _BITPOS_VALUE_LENGTH, _VALUE_INITED) }
            // Get key.
            case 1 { result := getStr(input, _BITPOS_KEY, _BITPOS_KEY_LENGTH, _KEY_INITED) }
            // Get children.
            case 3 { result := children(input) }
            // Parse.
            default {
                let p := add(input, 0x20)
                let e := add(p, mload(input))
                if iszero(eq(p, e)) {
                    let c := chr(e)
                    mstore8(e, 34) // Place a '"' at the end to speed up parsing.
                    // The `34 << 248` makes `mallocItem` preserve '"' at the end.
                    mstore(0x00, setP(shl(248, 34), _BITPOS_STRING, input))
                    result, p := parseValue(input, 0, p, e)
                    mstore8(e, c) // Restore the original char at the end.
                }
                if or(lt(p, e), iszero(result)) { fail() }
            }
        }
    }

    /// @dev Casts the input to a bytes32.
    function _toInput(string memory input) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := input
        }
    }

    /// @dev Casts the input to a bytes32.
    function _toInput(Item memory input) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := input
        }
    }
}
