// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/LibStrings.sol";
import "./ComposeVerifier.sol";

/// @title TeeAnyVerifier
/// @notice This contract is a verifier for the Mainnet TEE proofs that composes SGX and TDX
/// Verifiers.
/// @custom:security-contact security@taiko.xyz
contract TeeAnyVerifier is ComposeVerifier {
    uint256[50] private __gap;

    /// @inheritdoc ComposeVerifier
    function getSubVerifiersAndThreshold()
        public
        view
        override
        returns (address[] memory verifiers_, uint256 numSubProofs_)
    {
        verifiers_ = new address[](2);
        verifiers_[0] = resolve(LibStrings.B_TIER_SGX, false);
        verifiers_[1] = resolve(LibStrings.B_TIER_TDX, false);
        numSubProofs_ = 1;
    }
}
