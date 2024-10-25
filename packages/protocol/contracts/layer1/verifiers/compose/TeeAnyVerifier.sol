// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/LibStrings.sol";
import "./ComposeVerifier.sol";

/// @title TeeAnyVerifier
/// @custom:security-contact security@taiko.xyz
contract TeeAnyVerifier is ComposeVerifier {
    uint256[50] private __gap;

    /// @inheritdoc ComposeVerifier
    /// @notice Checks if the caller is authorized
    /// @param _caller The address of the caller
    /// @return True if the caller is authorized, false otherwise
    function isCallerAuthorized(address _caller) public view override returns (bool) {
        return _caller == resolve(LibStrings.B_TAIKO, false)
            || _caller == resolve(LibStrings.B_TIER_ZKVM_AND_TEE, true);
    }

    /// @inheritdoc ComposeVerifier
    /// @notice Gets the sub-verifiers and the threshold
    /// @return verifiers_ An array of addresses of the sub-verifiers
    /// @return numSubProofs_ The number of sub-proofs required
    function getSubVerifiersAndThreshold()
        public
        view
        override
        returns (address[] memory verifiers_, uint256 numSubProofs_)
    {
        verifiers_ = new address[](2);
        verifiers_[0] = resolve(LibStrings.B_TIER_SGX, true);
        verifiers_[1] = resolve(LibStrings.B_TIER_TDX, true);
        numSubProofs_ = 1;
    }
}
