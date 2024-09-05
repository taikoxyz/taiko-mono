// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../../team/proving/ProverSet.sol";
import "../addrcache/RollupAddressCache.sol";

/// @title MainnetProverSet
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost. In theory, the contract can also be deplyed on Taiko L2 but this is
/// not well testee nor necessary.
/// @notice See the documentation in {ProverSet}.
/// @custom:security-contact security@taiko.xyz
contract MainnetProverSet is ProverSet, RollupAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }
}
