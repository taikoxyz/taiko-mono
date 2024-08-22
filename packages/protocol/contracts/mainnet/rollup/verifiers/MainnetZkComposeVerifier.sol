// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../../verifiers/compose/ZkComposeVerifier.sol";
import "../../addrcache/RollupAddressCache.sol";

/// @title MainnetZkComposeVerifier
/// @custom:security-contact security@taiko.xyz
contract MainnetZkComposeVerifier is ZkComposeVerifier, RollupAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }
}
