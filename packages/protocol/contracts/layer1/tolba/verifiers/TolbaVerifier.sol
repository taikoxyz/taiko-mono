// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../verifiers/compose/ComposeVerifier.sol";

/// @title TolbaVerifier.sol
/// @notice SGX or SP1 or Risc0 verifier
/// @custom:security-contact security@taiko.xyz
contract TolbaVerifier is ComposeVerifier {
    uint256[50] private __gap;

    constructor(
        address _taikoInbox,
        address _sgxGethVerifier,
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        ComposeVerifier(
            _taikoInbox,
            _sgxGethVerifier,
            address(0),
            address(0),
            _sgxRethVerifier,
            _risc0RethVerifier,
            _sp1RethVerifier
        )
    { }

    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 2) return false;
        uint256 sgxGethVerifierIdx = (_verifiers[0] == sgxGethVerifier) ? 0 : 1;
        uint256 refVerifierIdx = (sgxGethVerifierIdx == 0) ? 1 : 0;
        require(_verifiers[sgxGethVerifierIdx] == sgxGethVerifier, "CV_INVALID_TRUSTED_VERIFIER");

        return (
            _verifiers[refVerifierIdx] == sgxRethVerifier
                || _verifiers[refVerifierIdx] == risc0RethVerifier
                || _verifiers[refVerifierIdx] == sp1RethVerifier
        );
    }
}
