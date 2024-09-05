// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../../../verifiers/compose/TeeAnyVerifier.sol";
import "../../addrcache/RollupAddressCache.sol";

/// @title MainnetTeeAnyVerifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @custom:security-contact security@taiko.xyz
contract MainnetTeeAnyVerifier is TeeAnyVerifier, RollupAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }
}
