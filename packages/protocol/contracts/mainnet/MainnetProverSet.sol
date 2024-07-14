// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../team/proving/ProverSet.sol";
import "./LibAddressCache.sol";

/// @title MainnetProverSet
/// @notice See the documentation in {ProverSet}.
/// @custom:security-contact security@taiko.xyz
contract MainnetProverSet is ProverSet {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        address addr = LibAddressCache.getAddress(_chainId, _name);
        return addr != address(0) ? addr : super._getAddress(_chainId, _name);
    }
}
