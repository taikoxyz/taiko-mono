// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/src/Vm.sol";

/// @title LibEtnaVectors
/// @notice Reads `testdata/etna_vectors/vectors.json`, the Etna vectors the contracts share with
/// the Etna node and guests; that directory's README says what each section pins and how the
/// file is generated.
/// @dev Integers are decimal strings in the file; `parseJsonUint` reads them exactly. Keys are
/// forge JSON paths, e.g. `.layout.inbox.slots.landings` or `.keys[0].ck_x`.
library LibEtnaVectors {
    /// @dev The forge cheatcode address.
    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev The vectors file, relative to the protocol package root. `foundry.toml` grants read
    /// access to its directory.
    string private constant _PATH = "/../../testdata/etna_vectors/vectors.json";

    /// @dev Returns the vectors file.
    /// @return json_ The JSON document.
    function load() internal view returns (string memory json_) {
        return _VM.readFile(string.concat(_VM.projectRoot(), _PATH));
    }

    /// @dev Reads the unsigned integer (a decimal string) at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function uintAt(string memory _json, string memory _key) internal pure returns (uint256) {
        return _VM.parseJsonUint(_json, _key);
    }

    /// @dev Reads the `bytes32` at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function bytes32At(
        string memory _json,
        string memory _key
    )
        internal
        pure
        returns (bytes32)
    {
        return _VM.parseJsonBytes32(_json, _key);
    }

    /// @dev Reads the address at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function addressAt(
        string memory _json,
        string memory _key
    )
        internal
        pure
        returns (address)
    {
        return _VM.parseJsonAddress(_json, _key);
    }

    /// @dev Reads the byte string at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function bytesAt(
        string memory _json,
        string memory _key
    )
        internal
        pure
        returns (bytes memory)
    {
        return _VM.parseJsonBytes(_json, _key);
    }

    /// @dev Reads the string at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function stringAt(
        string memory _json,
        string memory _key
    )
        internal
        pure
        returns (string memory)
    {
        return _VM.parseJsonString(_json, _key);
    }

    /// @dev Reads the boolean at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The value.
    function boolAt(string memory _json, string memory _key) internal pure returns (bool) {
        return _VM.parseJsonBool(_json, _key);
    }

    /// @dev Reads the `bytes32` array at `_key`, possibly empty.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return The values.
    function bytes32ArrayAt(
        string memory _json,
        string memory _key
    )
        internal
        pure
        returns (bytes32[] memory)
    {
        return _VM.parseJsonBytes32Array(_json, _key);
    }

    /// @dev Returns whether the value at `_key` is JSON null. Forge reads a null without error, as
    /// the string "null" and as a single zero word, so a reader that may meet one asks here first.
    /// Every number in the file is a decimal string, so no other value of a nullable field reads
    /// as both.
    /// @param _json The vectors document.
    /// @param _key The JSON path.
    /// @return Whether the value is null.
    function isNullAt(string memory _json, string memory _key) internal pure returns (bool) {
        bytes memory raw = _VM.parseJson(_json, _key);
        return raw.length == 32 && bytes32(raw) == 0
            && keccak256(bytes(_VM.parseJsonString(_json, _key))) == keccak256("null");
    }

    /// @dev Returns the number of entries of the object at `_family`, such as `.governance_abi`,
    /// whose `contract` label is `_contract`.
    /// @param _json The vectors document.
    /// @param _family The JSON path of the object.
    /// @param _contract The label: `inbox`, `staking` or `unzen_inbox`.
    /// @return count_ The number of entries with that label.
    function countWithContract(
        string memory _json,
        string memory _family,
        string memory _contract
    )
        internal
        pure
        returns (uint256 count_)
    {
        string[] memory names = _VM.parseJsonKeys(_json, _family);
        for (uint256 i; i < names.length; ++i) {
            string memory label =
                _VM.parseJsonString(_json, string.concat(_family, ".", names[i], ".contract"));
            if (keccak256(bytes(label)) == keccak256(bytes(_contract))) ++count_;
        }
    }

    /// @dev Returns the number of entries of the object at `_family`.
    /// @param _json The vectors document.
    /// @param _family The JSON path of the object.
    /// @return The entry count.
    function entryCount(
        string memory _json,
        string memory _family
    )
        internal
        pure
        returns (uint256)
    {
        return _VM.parseJsonKeys(_json, _family).length;
    }

    /// @dev Reads the domain tag named at `_key`: its ASCII name right-padded with zero bytes.
    /// @param _json The vectors document.
    /// @param _key The JSON path of the tag's name.
    /// @return The tag.
    function tagAt(string memory _json, string memory _key) internal pure returns (bytes32) {
        bytes memory name = bytes(_VM.parseJsonString(_json, _key));
        require(name.length <= 32, "tag longer than 32 bytes");
        return bytes32(name);
    }

    /// @dev Returns the number of elements of the array at `_key`.
    /// @param _json The vectors document.
    /// @param _key The JSON path of the array.
    /// @return count_ The element count.
    function lengthAt(
        string memory _json,
        string memory _key
    )
        internal
        view
        returns (uint256 count_)
    {
        while (_VM.keyExistsJson(_json, string.concat(_key, "[", _VM.toString(count_), "]"))) {
            ++count_;
        }
    }

    /// @dev Returns `"<_array>[<_index>]."`, the path prefix of an array item's fields.
    /// @param _array The JSON path of the array.
    /// @param _index The item's index.
    /// @return The item's path prefix.
    function itemAt(
        string memory _array,
        uint256 _index
    )
        internal
        pure
        returns (string memory)
    {
        return string.concat(_array, "[", _VM.toString(_index), "].");
    }
}

/// @title EtnaVectorReader
/// @notice The field readers of the suites that walk `vectors.json` item by item: `_at` names an
/// array item and the others read field `_field` of the item whose path prefix is `_p`.
/// @dev Every read returns fresh memory that is never reclaimed, and memory expansion costs gas
/// quadratically, so a loop over many items releases what an iteration allocated: it takes
/// `_freeMemory()` before the iteration and passes it to `_releaseMemory` after it, once nothing
/// the iteration allocated is used again.
abstract contract EtnaVectorReader {
    /// @dev Returns the free memory pointer.
    function _freeMemory() internal pure returns (uint256 pointer_) {
        assembly ("memory-safe") {
            pointer_ := mload(0x40)
        }
    }

    /// @dev Releases the memory allocated since `_pointer`, which `_freeMemory` returned; nothing
    /// allocated after it may be used again.
    function _releaseMemory(uint256 _pointer) internal pure {
        assembly {
            mstore(0x40, _pointer)
        }
    }

    function _at(string memory _array, uint256 _index) internal pure returns (string memory) {
        return LibEtnaVectors.itemAt(_array, _index);
    }

    function _uint(
        string memory _j,
        string memory _p,
        string memory _field
    )
        internal
        pure
        returns (uint256)
    {
        return LibEtnaVectors.uintAt(_j, string.concat(_p, _field));
    }

    function _bytes32(
        string memory _j,
        string memory _p,
        string memory _field
    )
        internal
        pure
        returns (bytes32)
    {
        return LibEtnaVectors.bytes32At(_j, string.concat(_p, _field));
    }

    function _address(
        string memory _j,
        string memory _p,
        string memory _field
    )
        internal
        pure
        returns (address)
    {
        return LibEtnaVectors.addressAt(_j, string.concat(_p, _field));
    }

    function _bytes(
        string memory _j,
        string memory _p,
        string memory _field
    )
        internal
        pure
        returns (bytes memory)
    {
        return LibEtnaVectors.bytesAt(_j, string.concat(_p, _field));
    }

    function _string(
        string memory _j,
        string memory _p,
        string memory _field
    )
        internal
        pure
        returns (string memory)
    {
        return LibEtnaVectors.stringAt(_j, string.concat(_p, _field));
    }

    function _bool(
        string memory _j,
        string memory _p,
        string memory _field
    )
        internal
        pure
        returns (bool)
    {
        return LibEtnaVectors.boolAt(_j, string.concat(_p, _field));
    }

    function _bytes32Array(
        string memory _j,
        string memory _p,
        string memory _field
    )
        internal
        pure
        returns (bytes32[] memory)
    {
        return LibEtnaVectors.bytes32ArrayAt(_j, string.concat(_p, _field));
    }

    function _isNull(
        string memory _j,
        string memory _p,
        string memory _field
    )
        internal
        pure
        returns (bool)
    {
        return LibEtnaVectors.isNullAt(_j, string.concat(_p, _field));
    }
}
