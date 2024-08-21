// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/SgxVerifier.sol";
import "../cache/RollupAddressCache.sol";

/// @title MainnetSgxVerifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {SgxVerifier}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSgxVerifier is SgxVerifier, RollupAddressCache {
   //

    function taikoChainId() internal pure override returns (uint64) {
        return LibNetwork.TAIKO_MAINNET;
    }
}
