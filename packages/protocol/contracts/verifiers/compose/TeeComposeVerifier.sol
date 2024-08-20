// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/LibStrings.sol";
import "./ComposeVerifier.sol";

/// @title TeeComposeVerifier
/// @notice This contract is a verifier for the Mainnet ZkVM that composes RiscZero and SP1
/// Verifiers.
/// @custom:security-contact security@taiko.xyz
contract TeeComposeVerifier is EssentialContract, ComposeVerifier {
    /// @inheritdoc ComposeVerifier
    function getSubVerifiersAndThreshold()
        public
        view
        override
        returns (address[] memory verifiers_, uint256 threshold_)
    {
        verifiers_ = new address[](1);
        verifiers_[0] = resolve(LibStrings.B_VERIFIER_TEE_SGX, false);
        threshold_ = 1;
    }
}
