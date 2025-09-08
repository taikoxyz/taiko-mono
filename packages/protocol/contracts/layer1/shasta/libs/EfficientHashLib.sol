// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EfficientHashLib
/// @notice Gas-optimized hashing library for struct and multi-parameter operations
/// @dev Reduces gas costs by eliminating ABI encoding overhead through direct memory operations
/// @author Taiko Labs
library EfficientHashLib {
    /// @notice Hashes two bytes32 values efficiently
    /// @dev Uses inline assembly for optimal gas usage
    /// @param a First bytes32 value
    /// @param b Second bytes32 value
    /// @return result The keccak256 hash of the concatenated values
    function hash(bytes32 a, bytes32 b) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @notice Hashes three bytes32 values efficiently
    /// @dev Uses inline assembly for optimal gas usage
    /// @param a First bytes32 value
    /// @param b Second bytes32 value
    /// @param c Third bytes32 value
    /// @return result The keccak256 hash of the concatenated values
    function hash(bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            mstore(0x40, c)
            result := keccak256(0x00, 0x60)
        }
    }

    /// @notice Hashes four bytes32 values efficiently
    /// @dev Uses inline assembly for optimal gas usage
    /// @param a First bytes32 value
    /// @param b Second bytes32 value
    /// @param c Third bytes32 value
    /// @param d Fourth bytes32 value
    /// @return result The keccak256 hash of the concatenated values
    function hash(bytes32 a, bytes32 b, bytes32 c, bytes32 d) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            mstore(0x40, c)
            mstore(0x60, d)
            result := keccak256(0x00, 0x80)
        }
    }

    /// @notice Hashes five bytes32 values efficiently
    /// @dev Uses inline assembly for optimal gas usage
    /// @param a First bytes32 value
    /// @param b Second bytes32 value
    /// @param c Third bytes32 value
    /// @param d Fourth bytes32 value
    /// @param e Fifth bytes32 value
    /// @return result The keccak256 hash of the concatenated values
    function hash(bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            mstore(0x40, c)
            mstore(0x60, d)
            mstore(0x80, e)
            result := keccak256(0x00, 0xa0)
        }
    }

    /// @notice Hashes six bytes32 values efficiently
    /// @dev Uses inline assembly for optimal gas usage
    /// @param a First bytes32 value
    /// @param b Second bytes32 value
    /// @param c Third bytes32 value
    /// @param d Fourth bytes32 value
    /// @param e Fifth bytes32 value
    /// @param f Sixth bytes32 value
    /// @return result The keccak256 hash of the concatenated values
    function hash(bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e, bytes32 f) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            mstore(0x40, c)
            mstore(0x60, d)
            mstore(0x80, e)
            mstore(0xa0, f)
            result := keccak256(0x00, 0xc0)
        }
    }

    /// @notice Hashes two uint256 values efficiently
    /// @dev Converts uint256 to bytes32 and hashes
    /// @param a First uint256 value
    /// @param b Second uint256 value
    /// @return result The keccak256 hash of the values
    function hash(uint256 a, uint256 b) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @notice Hashes three uint256 values efficiently
    /// @dev Converts uint256 to bytes32 and hashes
    /// @param a First uint256 value
    /// @param b Second uint256 value
    /// @param c Third uint256 value
    /// @return result The keccak256 hash of the values
    function hash(uint256 a, uint256 b, uint256 c) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            mstore(0x40, c)
            result := keccak256(0x00, 0x60)
        }
    }

    /// @notice Hashes array of bytes32 values efficiently
    /// @dev Optimized for dynamic arrays with minimal memory copying
    /// @param values Array of bytes32 values to hash
    /// @return result The keccak256 hash of the array
    function hashArray(bytes32[] memory values) internal pure returns (bytes32 result) {
        uint256 length = values.length;
        if (length == 0) {
            return keccak256("");
        }

        assembly {
            // Skip the length field, hash only the data
            result := keccak256(add(values, 0x20), mul(length, 0x20))
        }
    }

    /// @notice Hashes a bytes32 value with a uint256 efficiently
    /// @dev Mixed type hashing optimization
    /// @param a bytes32 value
    /// @param b uint256 value
    /// @return result The keccak256 hash of the values
    function hashMixed(bytes32 a, uint256 b) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @notice Hashes an address with a bytes32 efficiently
    /// @dev Mixed type hashing for address-hash pairs
    /// @param addr Address value
    /// @param data bytes32 value
    /// @return result The keccak256 hash of the values
    function hashAddressData(address addr, bytes32 data) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, addr)
            mstore(0x20, data)
            result := keccak256(0x00, 0x40)
        }
    }
}