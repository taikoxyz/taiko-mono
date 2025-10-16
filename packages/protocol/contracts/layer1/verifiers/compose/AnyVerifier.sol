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

    function areVerifiersSufficient(
        uint256, /* _youngestProposalAge */
        uint8[] memory _verifierIds
    )
        internal
        pure
        override
        returns (bool)
    {
        if (_verifiers.length != 1) return false;

        return _verifierIds[0] == SGX_RETH || isZKVerifier(_verifierIds[0]);
    }
}
