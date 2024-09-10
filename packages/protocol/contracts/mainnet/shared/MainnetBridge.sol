// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../bridge/Bridge.sol";
import "../addrcache/SharedAddressCache.sol";

/// @title MainnetBridge
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost. In theory, the contract can also be deplyed on Taiko L2 but this is
/// not well testee nor necessary.
/// @notice See the documentation in {Bridge}.
/// @custom:security-contact security@taiko.xyz
contract MainnetBridge is Bridge, SharedAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }
}
