// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/LibStrings.sol";
import "./ComposeVerifier.sol";

/// @title ZkAndTeeVerifier
/// @custom:security-contact security@taiko.xyz
contract ZkAndTeeVerifier is ComposeVerifier {
    uint256[50] private __gap;

    /// @inheritdoc ComposeVerifier
    function getSubVerifiersAndThreshold()
        public
        view
        override
        returns (address[] memory verifiers_, uint256 numSubProofs_)
    {
        verifiers_ = new address[](2);
        verifiers_[0] = resolve(LibStrings.B_TIER_TEE_ANY, false);
        verifiers_[1] = resolve(LibStrings.B_TIER_ZKVM_ANY, false);
        numSubProofs_ = 2;
    }
}
