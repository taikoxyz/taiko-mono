// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibNetwork.sol";

/// @title LibPreconfConstants
/// @custom:security-contact security@taiko.xyz
library LibPreconfConstants {
    uint256 internal constant ETHEREUM_MAINNET_BEACON_GENESIS = 1_606_824_023;
    uint256 internal constant ETHEREUM_HOLESKY_BEACON_GENESIS = 1_695_902_100;
    uint256 internal constant ETHEREUM_HELDER_BEACON_GENESIS = 1_718_967_660;

    uint256 internal constant SECONDS_IN_SLOT = 12;
    uint256 internal constant SECONDS_IN_EPOCH = SECONDS_IN_SLOT * 32;
    uint256 internal constant TWO_EPOCHS = 2 * SECONDS_IN_EPOCH;
    uint256 internal constant DISPUTE_PERIOD = 2 * SECONDS_IN_EPOCH;

    function getGenesisTimestamp(uint256 _chainid) internal pure returns (uint256) {
        if (_chainid == LibNetwork.ETHEREUM_MAINNET) {
            return ETHEREUM_MAINNET_BEACON_GENESIS;
        } else if (_chainid == LibNetwork.ETHEREUM_HOLESKY) {
            return ETHEREUM_HOLESKY_BEACON_GENESIS;
        } else if (_chainid == LibNetwork.ETHEREUM_HELDER) {
            return ETHEREUM_HELDER_BEACON_GENESIS;
        }
        return uint256(0);
    }

    function getBeaconBlockRootContract() internal pure returns (address) {
        return 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    }
}
