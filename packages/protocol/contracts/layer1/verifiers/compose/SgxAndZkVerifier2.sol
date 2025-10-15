// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SgxAndZkVerifier.sol";

/// @title SgxAndZkVerifier
/// @notice SGX + (SP1 or Risc0) verifier
/// @custom:security-contact security@taiko.xyz
contract SgxAndZkVerifier2 is SgxAndZkVerifier {
    constructor(
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        SgxAndZkVerifier(_sgxRethVerifier, _risc0RethVerifier, _sp1RethVerifier)
    { }

    function areVerifiersSufficient(
        uint256 _youngestProposalAge,
        address[] memory _verifiers
    )
        internal
        view
        virtual
        override
        returns (bool)
    {
        if (_verifiers.length == 2) {
            return (_verifiers[0] == sgxRethVerifier && isZKVerifier(_verifiers[1]))
                || (_verifiers[1] == sgxRethVerifier && isZKVerifier(_verifiers[0]));
        }
        if (_verifiers.length == 1) {
            return (_youngestProposalAge > 1 days && _verifiers[0] == sgxRethVerifier);
        }
        return false;
    }
}
