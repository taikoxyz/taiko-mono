// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibHashPublicInput
/// @notice Optimized keccak256 hashing for public input verification
/// @custom:security-contact security@taiko.xyz
library LibHashPublicInput {
    /// @notice Original implementation using abi.encode
    /// @param _chainId The chain ID
    /// @param _verifierContract The verifier contract address
    /// @param _aggregatedProvingHash The aggregated proving hash
    /// @param _newInstance The new instance address
    /// @return Hash of the public input
    function hashOriginal(
        uint64 _chainId,
        address _verifierContract,
        bytes32 _aggregatedProvingHash,
        address _newInstance
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode("VERIFY_PROOF", _chainId, _verifierContract, _aggregatedProvingHash, _newInstance)
        );
    }

    /// @notice Optimized implementation using inline assembly
    /// @dev Uses assembly to avoid ABI encoding overhead for constant string
    /// @param _chainId The chain ID
    /// @param _verifierContract The verifier contract address
    /// @param _aggregatedProvingHash The aggregated proving hash
    /// @param _newInstance The new instance address
    /// @return result_ Hash of the public input
    function hashOptimized(
        uint64 _chainId,
        address _verifierContract,
        bytes32 _aggregatedProvingHash,
        address _newInstance
    )
        internal
        pure
        returns (bytes32 result_)
    {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)

            // abi.encode produces:
            // Word 0: offset to string (0x20)
            // Word 1: chainId
            // Word 2: verifierContract
            // Word 3: aggregatedProvingHash
            // Word 4: newInstance
            // Word 5: string length
            // Word 6: string data

            // Write offset to string
            mstore(ptr, 0x00000000000000000000000000000000000000000000000000000000000000a0)

            // Write chainId
            mstore(add(ptr, 0x20), _chainId)

            // Write verifierContract
            mstore(add(ptr, 0x40), _verifierContract)

            // Write aggregatedProvingHash
            mstore(add(ptr, 0x60), _aggregatedProvingHash)

            // Write newInstance
            mstore(add(ptr, 0x80), _newInstance)

            // Write string length (12 bytes for "VERIFY_PROOF")
            mstore(add(ptr, 0xa0), 0x000000000000000000000000000000000000000000000000000000000000000c)

            // Write string data "VERIFY_PROOF" (12 bytes)
            mstore(add(ptr, 0xc0), 0x5645524946595f50524f4f460000000000000000000000000000000000000000)

            // Total size: 7 words = 0xe0 bytes
            result_ := keccak256(ptr, 0xe0)
        }
    }
}
