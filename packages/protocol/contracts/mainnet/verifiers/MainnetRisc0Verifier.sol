// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/Risc0Verifier.sol";
import "../LibRollupAddressCache.sol";

/// @title MainnetRisc0Verifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {Risc0Verifier}.
/// @custom:security-contact security@taiko.xyz
contract MainnetRisc0Verifier is Risc0Verifier {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibRollupAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }

    function taikoChainId() internal pure override returns (uint64) {
        return LibNetwork.TAIKO_MAINNET;
    }
}
