// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IStateQuery.sol";

/// @title LibStateQuery
/// @notice Library for hashing state queries and results.
/// @custom:security-contact security@taiko.xyz
library LibStateQuery {
    error InvalidParamSizes();

    /// @notice Hashes the state queries and results into a signal.
    /// @param _chainId The chain ID of the state queries.
    /// @param _queryTimestamp The timestamp of the state queries.
    /// @param _queries The state queries.
    /// @param _results The state results.
    /// @return The signal.
    function hashQueriesToSignal(
        uint256 _chainId,
        uint256 _queryTimestamp,
        IStateQuery.Query[] calldata _queries,
        IStateQuery.QueryResult[] memory _results
    )
        internal
        pure
        returns (bytes32)
    {
        require(_queries.length == _results.length, InvalidParamSizes());
        return keccak256(abi.encode(_chainId, _queryTimestamp, _queries, _results));
    }
}
