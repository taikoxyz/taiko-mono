// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "../../common/LibStrings.sol";
import "./ComposeVerifier.sol";

/// @title ZkComposeVerifier
/// @notice This contract is a verifier for the Mainnet ZkVM that composes RiscZero and SP1
/// Verifiers.
/// @custom:security-contact security@taiko.xyz
contract ZkComposeVerifier is EssentialContract, ComposeVerifier {
    /// @inheritdoc ComposeVerifier
    function getSubVerifiersAndThreshold()
        public
        view
        override
        returns (address[] memory verifiers_, uint256 threshold_)
    {
        verifiers_ = new address[](2);
        verifiers_[0] = resolve(LibStrings.B_VERIFIER_RISC0, false);
        verifiers_[1] = resolve(LibStrings.B_VERIFIER_SP1, false);
        threshold_ = 1;
    }
}
