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
            : EfficientHashLib.hash(
                _bondInstructionsHash,
                bytes32(uint256(_bondInstruction.proposalId)),
                bytes32(uint256(uint8(_bondInstruction.bondType))),
                bytes32(uint256(uint160(_bondInstruction.payer))),
                bytes32(uint256(uint160(_bondInstruction.payee)))
            );
    }
}
