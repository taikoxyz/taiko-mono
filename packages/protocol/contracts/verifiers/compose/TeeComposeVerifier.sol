// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ComposeVerifier.sol";

/// @title TeeComposeVerifier
/// @notice This contract is a verifier for the Mainnet ZkVM that composes RiscZero and SP1
/// Verifiers.
/// @custom:security-contact security@taiko.xyz
contract TeeComposeVerifier is ComposeVerifier {
    address internal immutable _SGX_VERIFIER;

    constructor(address _sgxVerifier) {
        _SGX_VERIFIER = _sgxVerifier;
    }

    /// @notice Returns the address of a SgxVerifier.
    /// @return The address of a SgxVerifier.
    function sgxVerifier() public view virtual returns (address) {
        return _SGX_VERIFIER;
    }

    /// @inheritdoc ComposeVerifier
    function getSubVerifiersAndThreshold()
        public
        view
        override
        returns (address[] memory verifiers_, uint256 threshold_)
    {
        verifiers_ = new address[](1);
        verifiers_[0] = sgxVerifier();
        threshold_ = 1;
    }
}
