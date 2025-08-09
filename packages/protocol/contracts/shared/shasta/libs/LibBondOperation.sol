// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibBondOperation
/// @notice Library for managing bond operations
/// @custom:security-contact security@taiko.xyz
library LibBondOperation {
    // -------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------

    struct BondOperation {
        uint48 proposalId;
        uint48 creditAmountGwei;
        address creditReceiver;
        uint48 debitAmountGwei;
        address debitReceiver;
    }

    function aggregateBondOperation(
        bytes32 _bondOperationsHash,
        BondOperation memory _bondOperation
    )
        internal
        pure
        returns (bytes32)
    {
        return _bondOperation.proposalId == 0
            ? _bondOperationsHash
            : keccak256(abi.encode(_bondOperationsHash, _bondOperation));
    }
}
