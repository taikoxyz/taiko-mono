// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/LibStrings.sol";
import "./ComposeVerifier.sol";

/// @title ZkAnyVerifier
/// @custom:security-contact security@taiko.xyz
contract ZkAnyVerifier is ComposeVerifier {
    uint256[50] private __gap;

    /// @inheritdoc ComposeVerifier
    function isCallerAuthorized(address _caller) public view override returns (bool) {
        return _caller == resolve(LibStrings.B_TAIKO, false)
            || _caller == resolve(LibStrings.B_TIER_ZKVM_AND_TEE, true);
    }

    /// @inheritdoc ComposeVerifier
    function getSubVerifiersAndThreshold()
        public
        view
        override
        returns (address[] memory verifiers_, uint256 numSubProofs_)
    {
        verifiers_ = new address[](2);
        verifiers_[0] = resolve(LibStrings.B_TIER_ZKVM_RISC0, true);
        verifiers_[1] = resolve(LibStrings.B_TIER_ZKVM_SP1, true);
        numSubProofs_ = 1;
    }
}
