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
        merged_ = new BondInstruction[](existingLen + newLen);

        // Copy existing instructions
        for (uint256 i; i < existingLen; ++i) {
            merged_[i] = _existingInstructions[i];
        }

        // Copy new instructions
        for (uint256 i; i < newLen; ++i) {
            merged_[existingLen + i] = _newInstructions[i];
        }
    }
}
