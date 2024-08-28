// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../../verifiers/compose/ZkAndTeeVerifier.sol";
import "../../addrcache/RollupAddressCache.sol";

/// @title MainnetZkAndTeeVerifier
/// @custom:security-contact security@taiko.xyz
contract MainnetZkAndTeeVerifier is ZkAndTeeVerifier, RollupAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }
}
