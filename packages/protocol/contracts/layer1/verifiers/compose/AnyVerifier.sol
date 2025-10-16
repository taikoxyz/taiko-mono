// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title AnyVerifier
/// @notice SGX or SP1 or Risc0 verifier
/// @custom:security-contact security@taiko.xyz
contract AnyVerifier is ComposeVerifier {
    constructor(address _sgxRethVerifier, address _risc0RethVerifier, address _sp1RethVerifier)
        ComposeVerifier(
            address(0),
            address(0),
            address(0),
            _sgxRethVerifier,
            _risc0RethVerifier,
            _sp1RethVerifier
        )
    { }

    function areSubProofsSufficient(
        uint256, /* _proposalAge */
        address[] memory _verifiers
    )
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 1) return false;
        return _verifiers[0] == sgxRethVerifier || isZKVerifierAddress(_verifiers[0]);
    }
}
