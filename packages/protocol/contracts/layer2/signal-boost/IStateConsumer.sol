// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/shared/signal-boost/IStateQuery.sol";

interface IStateConsumer {
    function consume(
        IStateQuery.Query calldata _request,
        IStateQuery.QueryResult calldata _response
    )
        external;
}
