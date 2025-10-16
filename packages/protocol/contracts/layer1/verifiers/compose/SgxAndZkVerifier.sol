// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title SgxAndZkVerifier
/// @notice SGX + (SP1 or Risc0) verifier
/// @custom:security-contact security@taiko.xyz
contract SgxAndZkVerifier is ComposeVerifier {
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
        uint256, /* _youngestProposalAge */
        SubProof[] memory _subProofs
    )
        internal
        pure
        override
        returns (bool)
    {
        if (_subProofs.length != 2) return false;

        // SGX_RETH must be first (lowest ID=4), followed by RISC0_RETH (5) or SP1_RETH (6)
        return _subProofs[0].verifierId == SGX_RETH && isZKVerifier(_subProofs[1].verifierId);
    }
}
