// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/shared/signal-boost/IStateQuery.sol";

/// @title IStateVerifier
/// @notice Interface for state verifiers.
/// @custom:security-contact security@taiko.xyz
interface IStateVerifier {
    /// @notice Verifies the state of a contract.
    /// @param _queries The queries to verify.
    /// @param _results The results of the queries.
    /// @param _consumers The consumers of the state.
    function verifyState(
        IStateQuery.Query[] calldata _queries,
        IStateQuery.QueryResult[] calldata _results,
        address[] calldata _consumers
    )
        external;
}
