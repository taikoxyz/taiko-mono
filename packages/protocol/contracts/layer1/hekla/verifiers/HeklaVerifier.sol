// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../verifiers/compose/ComposeVerifier.sol";

/// @title HeklaVerifier.sol
/// @notice SGX or SP1 or Risc0 verifier
/// @custom:security-contact security@taiko.xyz
contract HeklaVerifier is ComposeVerifier {
    uint256[50] private __gap;

    constructor(
        address _taikoInbox,
        address _pivotVerifier,
        address _sgxVerifier,
        address _risc0Verifier,
        address _sp1Verifier
    )
        ComposeVerifier(
            _taikoInbox,
            address(0),
            _pivotVerifier,
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
        uint256 pivotVerifierIdx = (_verifiers[0] == pivotVerifier) ? 0 : 1;
        uint256 refVerifierIdx = (pivotVerifierIdx == 0) ? 1 : 0;
        require(_verifiers[pivotVerifierIdx] == pivotVerifier, "CV_INVALID_TRUSTED_VERIFIER");

        return (
            _verifiers[refVerifierIdx] == sgxVerifier || _verifiers[refVerifierIdx] == risc0Verifier
                || _verifiers[refVerifierIdx] == sp1Verifier
        );
    }
}
