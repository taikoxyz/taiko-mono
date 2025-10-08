// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../verifiers/compose/ComposeVerifier.sol";

/// @title DevnetVerifier.sol
/// @notice OP or SGX or SP1 or Risc0 verifier
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
contract DevnetVerifier is ComposeVerifier {
    uint256[50] private __gap;

    constructor(
        address _taikoInbox,
        address _sgxGethVerifier,
        address _opVerifier,
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        ComposeVerifier(
            _taikoInbox,
            _sgxGethVerifier,
            address(0),
            _opVerifier,
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

        uint256 refVerifierIdx;
        if (_verifiers[0] == sgxGethVerifier) {
            refVerifierIdx = 1;
        } else if (_verifiers[1] == sgxGethVerifier) {
            refVerifierIdx = 0;
        } else {
            return false;
        }

        return (
            _verifiers[refVerifierIdx] == opVerifier
                || _verifiers[refVerifierIdx] == sgxRethVerifier
                || _verifiers[refVerifierIdx] == risc0RethVerifier
                || _verifiers[refVerifierIdx] == sp1RethVerifier
        );
    }
}
