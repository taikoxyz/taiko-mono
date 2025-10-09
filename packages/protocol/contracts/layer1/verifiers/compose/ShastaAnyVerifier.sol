// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaComposeVerifier.sol";

/// @title ShastaAnyVerifier.sol
/// @notice SGX or SP1 or Risc0 verifier
/// @custom:security-contact security@taiko.xyz
contract ShastaAnyVerifier is ShastaComposeVerifier {
    constructor(
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        ShastaComposeVerifier(
            address(0),
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
        if (_verifiers.length != 1) return false;

        return _verifiers[0] == sgxRethVerifier || _verifiers[0] == risc0RethVerifier
            || _verifiers[0] == sp1RethVerifier;
    }
}
