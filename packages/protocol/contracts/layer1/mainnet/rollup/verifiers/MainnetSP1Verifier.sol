// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/mainnet/reentrylock/LibFasterReentryLock.sol";
import "src/shared/libs/LibNetwork.sol";

/// @title MainnetSP1Verifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {RiscZeroVerifier}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSP1Verifier is SP1Verifier {
    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }

    function taikoChainId() internal pure override returns (uint64) {
        return LibNetwork.TAIKO_MAINNET;
    }
}
