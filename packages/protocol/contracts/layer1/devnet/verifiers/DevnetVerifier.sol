// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../verifiers/compose/ComposeVerifier.sol";

/// @title DevnetVerifier.sol
/// @notice OP or SGX or SP1 or Risc0 verifier
/// @custom:security-contact security@taiko.xyz
contract DevnetVerifier is ComposeVerifier {
    uint256[50] private __gap;

    constructor(
        address _taikoInbox,
        address _trustedVerifier,
        address _opVerifier,
        address _sgxVerifier,
        address _risc0Verifier,
        address _sp1Verifier
    )
        ComposeVerifier(
            _taikoInbox,
            _opVerifier,
            _trustedVerifier,
            _sgxVerifier,
            address(0),
            _risc0Verifier,
            _sp1Verifier
        )
    { }

    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 2) return false;
        uint256 trustedVerifierIdx = (_verifiers[0] == trustedVerifier) ? 0 : 1;
        uint256 refVerifierIdx = (trustedVerifierIdx == 0) ? 1 : 0;
        require(_verifiers[trustedVerifierIdx] == trustedVerifier, "CV_INVALID_TRUSTED_VERIFIER");

        return (
            _verifiers[refVerifierIdx] == opVerifier || _verifiers[refVerifierIdx] == sgxVerifier
                || _verifiers[refVerifierIdx] == risc0Verifier
                || _verifiers[refVerifierIdx] == sp1Verifier
        );
    }
}
