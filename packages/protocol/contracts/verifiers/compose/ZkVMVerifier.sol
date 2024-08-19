// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ComposeVerifier.sol";

/// @title ZkVMVerifier
/// @notice This contract is a verifier for the Mainnet ZkVM that composes RiscZero and SP1
/// Verifiers.
/// @custom:security-contact security@taiko.xyz
contract ZkVMVerifier is ComposeVerifier {
    address internal immutable _RISK_ZERO_VERIFIER;
    address internal immutable _SP1_VERIFIER;

    constructor(address _risc0Verifier, address _sp1Verifier) {
        _RISK_ZERO_VERIFIER = _risc0Verifier;
        _SP1_VERIFIER = _sp1Verifier;
    }

    /// @notice Returns the address of the Risc0 verifier.
    /// @return The address of the Risc0 verifier.
    function risc0Verifier() public view virtual returns (address) {
        return _RISK_ZERO_VERIFIER;
    }

    /// @notice Returns the address of the SP1 verifier.
    /// @return The address of the SP1 verifier.
    function sp1Verifier() public view virtual returns (address) {
        return _SP1_VERIFIER;
    }

    /// @inheritdoc ComposeVerifier
    function getSubVerifiers() public view override returns (address[] memory verifiers_) {
        verifiers_ = new address[](2);
        verifiers_[0] = risc0Verifier();
        verifiers_[1] = sp1Verifier();
    }

    /// @inheritdoc ComposeVerifier
    function getThreshold(uint256 /*_numSubVerifiers*/ ) public view override returns (uint256) {
        return 1;
    }
}
