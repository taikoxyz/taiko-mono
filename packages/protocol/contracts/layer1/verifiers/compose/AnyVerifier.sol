// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title AnyVerifier
/// @notice SGX or SP1 or Risc0 verifier
/// @custom:security-contact security@taiko.xyz
contract AnyVerifier is ComposeVerifier {
    constructor(
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
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
        SubProof[] memory _subProofs
    )
        internal
        pure
        override
        returns (bool)
    {
        if (_subProofs.length != 1) return false;
        return _subProofs[0].verifierId == SGX_RETH || isZKVerifier(_subProofs[0].verifierId);
    }
}
