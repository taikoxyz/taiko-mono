// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibBondInstruction
/// @notice Library for managing bond instructions
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction {
    // -------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------

    struct BondInstruction {
        uint48 proposalId;
        bool isLivenessBond; // false for provability bond
        address creditTo;
        address debitFrom;
    }

    function aggregateBondInstruction(
        bytes32 _bondInstructionsHash,
        BondInstruction memory _bondInstruction
    )
        internal
        pure
        returns (bytes32)
    {
        return _bondInstruction.proposalId == 0
            ? _bondInstructionsHash
            : keccak256(abi.encode(_bondInstructionsHash, _bondInstruction));
    }
}
