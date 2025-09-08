// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibBonds
/// @notice Library for managing bond instructions
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    // ---------------------------------------------------------------
    // Enums
    // ---------------------------------------------------------------

    enum BondType {
        NONE,
        PROVABILITY,
        LIVENESS
    }

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    struct BondInstruction {
        uint48 proposalId;
        BondType bondType;
        address payer;
        address receiver;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    function aggregateBondInstruction(
        bytes32 _bondInstructionsHash,
        BondInstruction memory _bondInstruction
    )
        internal
        pure
        returns (bytes32)
    {
        return _bondInstruction.proposalId == 0 || _bondInstruction.bondType == BondType.NONE
            ? _bondInstructionsHash
            : keccak256(abi.encode(_bondInstructionsHash, _bondInstruction));
    }

    /// @notice Merges two bond instruction arrays into a single array
    /// @dev Optimized for memory allocation and copying to reduce gas costs
    /// Uses assembly bulk-copy for larger arrays, falls back to loop-based copying for smaller arrays
    /// @param _existingInstructions The existing bond instructions array
    /// @param _newInstructions The new bond instructions array to merge
    /// @return merged_ The merged bond instructions array
    function mergeBondInstructions(
        BondInstruction[] memory _existingInstructions,
        BondInstruction[] memory _newInstructions
    )
        internal
        pure
        returns (BondInstruction[] memory merged_)
    {
        if (_newInstructions.length == 0) {
            return _existingInstructions;
        }

        uint256 existingLen = _existingInstructions.length;
        uint256 newLen = _newInstructions.length;
        uint256 totalLen = existingLen + newLen;
        
        merged_ = new BondInstruction[](totalLen);

        // Break-even point: use assembly bulk-copy for arrays with more than 8 elements total
        // Below this threshold, the overhead of assembly operations outweighs the benefits
        if (totalLen > 8) {
            _bulkCopyBondInstructions(merged_, _existingInstructions, _newInstructions);
        } else {
            // Use simple loops for small arrays
            _loopCopyBondInstructions(merged_, _existingInstructions, _newInstructions);
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Assembly-optimized bulk copy for larger arrays
    /// @param _merged The destination array
    /// @param _existing The existing instructions to copy first
    /// @param _new The new instructions to append
    function _bulkCopyBondInstructions(
        BondInstruction[] memory _merged,
        BondInstruction[] memory _existing,
        BondInstruction[] memory _new
    )
        private
        pure
    {
        uint256 existingLen = _existing.length;
        uint256 newLen = _new.length;
        
        assembly {
            let mergedPtr := add(_merged, 0x20)
            let existingPtr := add(_existing, 0x20)
            let newPtr := add(_new, 0x20)
            
            // Each BondInstruction is 128 bytes (4 * 32 bytes)
            // proposalId (48 bits -> 32 bytes), bondType (enum -> 32 bytes), 
            // payer (address -> 32 bytes), receiver (address -> 32 bytes)
            let instructionSize := 0x80
            
            // Copy existing instructions using bulk memory copy
            if gt(existingLen, 0) {
                let existingBytes := mul(existingLen, instructionSize)
                
                // Use efficient word-based copying
                let words := div(add(existingBytes, 0x1f), 0x20)
                for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                    mstore(add(mergedPtr, mul(i, 0x20)), mload(add(existingPtr, mul(i, 0x20))))
                }
            }
            
            // Copy new instructions starting after existing ones
            if gt(newLen, 0) {
                let newBytes := mul(newLen, instructionSize)
                let destOffset := mul(existingLen, instructionSize)
                let destPtr := add(mergedPtr, destOffset)
                
                // Use efficient word-based copying
                let words := div(add(newBytes, 0x1f), 0x20)
                for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                    mstore(add(destPtr, mul(i, 0x20)), mload(add(newPtr, mul(i, 0x20))))
                }
            }
        }
    }

    /// @dev Loop-based copy for smaller arrays to avoid assembly overhead
    /// @param _merged The destination array
    /// @param _existing The existing instructions to copy first
    /// @param _new The new instructions to append
    function _loopCopyBondInstructions(
        BondInstruction[] memory _merged,
        BondInstruction[] memory _existing,
        BondInstruction[] memory _new
    )
        private
        pure
    {
        uint256 existingLen = _existing.length;
        uint256 newLen = _new.length;

        // Copy existing instructions - safe to use unchecked since arrays are pre-allocated
        unchecked {
            for (uint256 i; i < existingLen; ++i) {
                _merged[i] = _existing[i];
            }

            // Copy new instructions
            for (uint256 i; i < newLen; ++i) {
                _merged[existingLen + i] = _new[i];
            }
        }
    }
}
