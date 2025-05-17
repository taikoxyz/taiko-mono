// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/shared/signal-boost/IStateQuery.sol";

/// @title IStateConsumer
/// @notice Interface for state consumers.
/// @custom:security-contact security@taiko.xyz
interface IStateConsumer {
    /// @notice Consumes the state of a contract.
    /// @param _request The query request.
    /// @param _response The query response.
    function consume(
        IStateQuery.Query calldata _request,
        IStateQuery.QueryResult calldata _response
    )
        external;
}
