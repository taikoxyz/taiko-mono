// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";

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

    /// @dev Hashing for BondInstruction structs using EfficientHashLib
    /// @param _bondInstruction The bond instruction to hash
    /// @return The hash of the bond instruction
    function hashBondInstruction(BondInstruction memory _bondInstruction)
        internal
        pure
        returns (bytes32)
    {
        bytes32[] memory buffer = EfficientHashLib.malloc(4);

        EfficientHashLib.set(buffer, 0, bytes32(uint256(_bondInstruction.proposalId)));
        EfficientHashLib.set(buffer, 1, bytes32(uint256(_bondInstruction.bondType)));
        EfficientHashLib.set(buffer, 2, bytes32(uint256(uint160(_bondInstruction.payer))));
        EfficientHashLib.set(buffer, 3, bytes32(uint256(uint160(_bondInstruction.payee))));

        bytes32 result = EfficientHashLib.hash(buffer);
        EfficientHashLib.free(buffer);
        return result;
    }
}
