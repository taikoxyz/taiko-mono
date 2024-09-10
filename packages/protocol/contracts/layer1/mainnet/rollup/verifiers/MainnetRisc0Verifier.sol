// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../verifiers/Risc0Verifier.sol";
import "../../addrcache/RollupAddressCache.sol";

/// @title MainnetRisc0Verifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {Risc0Verifier}.
/// @custom:security-contact security@taiko.xyz
contract MainnetRisc0Verifier is Risc0Verifier, RollupAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }

    function taikoChainId() internal pure override returns (uint64) {
        return LibNetwork.TAIKO_MAINNET;
    }
}
