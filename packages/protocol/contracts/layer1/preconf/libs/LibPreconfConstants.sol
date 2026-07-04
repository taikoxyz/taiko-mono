// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibNetwork.sol";

/// @title LibPreconfConstants
/// @custom:security-contact security@taiko.xyz
library LibPreconfConstants {
    /// @dev https://eips.ethereum.org/EIPS/eip-4788 enforce to use this address across different
    /// EVM chains.
    address internal constant BEACON_BLOCK_ROOT_CONTRACT =
        0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    uint256 internal constant ETHEREUM_MAINNET_BEACON_GENESIS = 1_606_824_023;
    uint256 internal constant ETHEREUM_HOLESKY_BEACON_GENESIS = 1_695_902_400;
    uint256 internal constant ETHEREUM_HELDER_BEACON_GENESIS = 1_718_967_660;
    uint256 internal constant ETHEREUM_HOODI_BEACON_GENESIS = 1_742_213_400;

    uint256 internal constant SECONDS_IN_SLOT = 12;
    uint256 internal constant SECONDS_IN_EPOCH = SECONDS_IN_SLOT * 32;
    uint256 internal constant TWO_EPOCHS = 2 * SECONDS_IN_EPOCH;
    uint256 internal constant DISPUTE_PERIOD = 2 * SECONDS_IN_EPOCH;
    uint256 internal constant RANDOMNESS_DELAY_EPOCHS = 2;

    bytes32 internal constant PRECONF_DOMAIN_SEPARATOR = keccak256("TAIKO_ALETHIA_PRECONF");

    function getGenesisTimestamp(uint256 _chainid) internal pure returns (uint256) {
        if (_chainid == LibNetwork.ETHEREUM_MAINNET) {
            return ETHEREUM_MAINNET_BEACON_GENESIS;
        } else if (_chainid == LibNetwork.ETHEREUM_HOLESKY) {
            return ETHEREUM_HOLESKY_BEACON_GENESIS;
        } else if (_chainid == LibNetwork.ETHEREUM_HELDER) {
            return ETHEREUM_HELDER_BEACON_GENESIS;
        } else if (_chainid == LibNetwork.ETHEREUM_HOODI) {
            return ETHEREUM_HOODI_BEACON_GENESIS;
        }
        return uint256(0);
    }
}
