// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibHashPublicInputArray
/// @notice Optimized keccak256 hashing for bytes32 arrays
/// @custom:security-contact security@taiko.xyz
library LibHashPublicInputArray {
    /// @notice Original implementation using abi.encodePacked
    /// @param _input Array of bytes32 values
    /// @return Hash of the array
    function hashOriginal(bytes32[] memory _input) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_input));
    }

    /// @notice Optimized implementation using inline assembly
    /// @dev For bytes32 arrays, abi.encodePacked just concatenates, so we can hash directly
    /// @param _input Array of bytes32 values
    /// @return result_ Hash of the array
    function hashOptimized(bytes32[] memory _input) internal pure returns (bytes32 result_) {
        assembly {
            // _input points to: [length, data...]
            // length is at offset 0
            // data starts at offset 0x20
            let len := mload(_input)
            let dataPtr := add(_input, 0x20)

            // Hash (len * 32) bytes starting from dataPtr
            result_ := keccak256(dataPtr, mul(len, 0x20))
        }
    }
}
