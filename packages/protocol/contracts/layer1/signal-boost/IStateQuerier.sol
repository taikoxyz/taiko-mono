// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/shared/signal-boost/IStateQuery.sol";

/// @title IStateQuerier
/// @notice Contract for querying the state of multiple contracts.
/// @custom:security-contact security@taiko.xyz
interface IStateQuerier {
    event QueryResult(IStateQuery.Query query, IStateQuery.QueryResult result);

    /// @notice Queries the state of multiple contracts.
    /// @param _queries An arry of queries, each containing a target contract and a payload.
    /// @return results_ An array of query results, each containing a success flag and output data.
    /// @return signal_ A bytes32 signal representing the hashed result of the queries.
    function queryState(IStateQuery.Query[] calldata _queries)
        external
        returns (IStateQuery.QueryResult[] memory results_, bytes32 signal_);
}
