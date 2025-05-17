// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IStateQuery
/// @notice Data structures for state queries.
/// @custom:security-contact security@taiko.xyz
abstract contract IStateQuery {
    struct Query {
        /// @notice The contract to query.
        address target;
        /// @notice The function selector and parameters of the view function.
        bytes payload;
    }

    struct QueryResult {
        /// @notice Whether the query was successful.
        bool success;
        /// @notice The output of the query.
        bytes output;
    }
}
