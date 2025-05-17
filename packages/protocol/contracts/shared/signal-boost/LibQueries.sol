// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IStateQuery.sol";

/// @title LibQueries
/// @custom:security-contact security@taiko.xyz
library LibStates {
    // AggregatorV3Interface.latestRoundData.selector
    bytes4 private constant LATEST_ROUND_DATA_SELECTOR = 0x50d25bcd;

    function getEthPriceQuery() internal pure returns (IStateQuery.Query memory) {
        return IStateQuery.Query({
            target: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // ETH/USD feed
            payload: abi.encodeWithSelector(LATEST_ROUND_DATA_SELECTOR)
        });
    }

    function getBtcPriceQuery() internal pure returns (IStateQuery.Query memory) {
        return IStateQuery.Query({
            target: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, // BTC/USD feed
            payload: abi.encodeWithSelector(LATEST_ROUND_DATA_SELECTOR)
        });
    }
}
