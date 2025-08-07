// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibBondOperation
/// @notice Library for managing bond operations
/// @custom:security-contact security@taiko.xyz
library LibBondOperation {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct BondOperation {
        uint48 proposalId;
        address receiver;
        uint256 credit;
    }

    // -------------------------------------------------------------------------
    // Functions
    // -------------------------------------------------------------------------

    function aggregateBondOperation(
        bytes32 _bondOperationAggregationHash,
        BondOperation memory _bondOperation
    )
        internal
        pure
        returns (bytes32)
    {
        return _bondOperation.receiver == address(0) || _bondOperation.credit == 0
            ? _bondOperationAggregationHash
            : keccak256(abi.encode(_bondOperationAggregationHash, _bondOperation));
    }
}
