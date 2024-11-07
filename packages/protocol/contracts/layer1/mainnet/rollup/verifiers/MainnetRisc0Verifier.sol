// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/mainnet/reentrylock/LibFasterReentryLock.sol";

/// @title MainnetRisc0Verifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {Risc0Verifier}.
/// @custom:security-contact security@taiko.xyz
contract MainnetRisc0Verifier is Risc0Verifier {
    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
