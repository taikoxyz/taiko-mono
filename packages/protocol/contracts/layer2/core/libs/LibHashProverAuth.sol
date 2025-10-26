// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibHashProverAuth
/// @notice Optimized keccak256 hashing for prover authorization messages
/// @custom:security-contact security@taiko.xyz
library LibHashProverAuth {
    /// @notice Original implementation using abi.encode
    /// @param _proposalId The proposal ID
    /// @param _proposer The proposer address
    /// @param _provingFee The proving fee
    /// @return Hash of the prover auth message
    function hashOriginal(
        uint48 _proposalId,
        address _proposer,
        uint256 _provingFee
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_proposalId, _proposer, _provingFee));
    }

    /// @notice Optimized implementation using inline assembly
    /// @dev Uses assembly to avoid ABI encoding overhead
    /// @param _proposalId The proposal ID
    /// @param _proposer The proposer address
    /// @param _provingFee The proving fee
    /// @return result_ Hash of the prover auth message
    function hashOptimized(
        uint48 _proposalId,
        address _proposer,
        uint256 _provingFee
    )
        internal
        pure
        returns (bytes32 result_)
    {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)

            // abi.encode pads each value to 32 bytes
            // Store proposalId (uint48 -> uint256)
            mstore(ptr, _proposalId)

            // Store proposer (address -> uint256)
            mstore(add(ptr, 0x20), _proposer)

            // Store provingFee (uint256)
            mstore(add(ptr, 0x40), _provingFee)

            // Hash 96 bytes (3 * 32)
            result_ := keccak256(ptr, 0x60)
        }
    }
}
