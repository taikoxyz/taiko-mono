// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/SP1Verifier.sol";
import "../LibRollupAddressCache.sol";

/// @title MainnetSP1Verifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {RiscZeroVerifier}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSP1Verifier is SP1Verifier {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibRollupAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }

    function taikoChainId() internal pure override returns (uint64) {
        return LibNetwork.TAIKO_MAINNET;
    }
}
