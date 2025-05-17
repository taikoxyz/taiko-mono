// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/shared/signal-boost/IStateQuery.sol";

interface IStateQuerier {
    event QueryResult(IStateQuery.Query query, IStateQuery.QueryResult result);

    function queryState(IStateQuery.Query[] calldata _queries)
        external
        returns (IStateQuery.QueryResult[] memory results_, bytes32 signal_);
}
