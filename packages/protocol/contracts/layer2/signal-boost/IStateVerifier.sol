// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/shared/signal-boost/IStateQuery.sol";

interface IStateVerifier {
    function verifyState(
        IStateQuery.Query[] calldata _queries,
        IStateQuery.QueryResult[] calldata _results,
        address[] calldata _consumers
    )
        external;
}
