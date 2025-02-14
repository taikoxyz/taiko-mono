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
        address _opVerifier,
        address _sgxVerifier,
        address _risc0Verifier,
        address _sp1Verifier
    )
        ComposeVerifier(
            _taikoInbox,
            _opVerifier,
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
        if (_verifiers.length != 1) return false;

        return _verifiers[0] == opVerifier || _verifiers[0] == sgxVerifier
            || _verifiers[0] == risc0Verifier || _verifiers[0] == sp1Verifier;
    }
}
