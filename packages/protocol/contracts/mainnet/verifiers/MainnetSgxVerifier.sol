// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/SgxVerifier.sol";
import "../addrcache/RollupAddressCache.sol";

/// @title MainnetSgxVerifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {SgxVerifier}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSgxVerifier is SgxVerifier, RollupAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddressFromCache(_chainId, _name, super._getAddress);
    }

    function taikoChainId() internal pure override returns (uint64) {
        return LibNetwork.TAIKO_MAINNET;
    }
}
