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
        address payee;
    }

    // ---------------------------------------------------------------
    // Functions
    // ---------------------------------------------------------------

    /// @dev Hashing for BondInstruction structs using keccak256 and abi.encode
    /// @param _bondInstruction The bond instruction to hash
    /// @return The hash of the bond instruction
    function hashBondInstruction(BondInstruction memory _bondInstruction)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_bondInstruction));
    }
}
