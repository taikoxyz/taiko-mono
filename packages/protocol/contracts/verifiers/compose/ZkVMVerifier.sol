// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ComposeVerifier.sol";

/// @title ZkVMVerifier
/// @notice This contract is a verifier for the Mainnet ZkVM that composes RiscZero and SP1
/// Verifiers.
/// @custom:security-contact security@taiko.xyz
contract ZkVMVerifier is ComposeVerifier {
    address internal immutable _risc0Verifier;
    address internal immutable _sp1Verifier;

    constructor(address risc0Verifier, address sp1Verifier) {
        _risc0Verifier = risc0Verifier;
        _sp1Verifier = sp1Verifier;
    }

    /// @notice Returns the address of the Risc0 verifier.
    /// @return The address of the Risc0 verifier.
    function getRisc0Verifier() public view virtual returns (address) {
        return _risc0Verifier;
    }

    /// @notice Returns the address of the SP1 verifier.
    /// @return The address of the SP1 verifier.
    function getSp1Verifier() public view virtual returns (address) {
        return _sp1Verifier;
    }

    /// @inheritdoc ComposeVerifier
    function getSubVerifiers() public view override returns (address[] memory verifiers_) {
        verifiers_ = new address[](2);
        verifiers_[0] = getRisc0Verifier();
        verifiers_[1] = getSp1Verifier();
    }

    /// @inheritdoc ComposeVerifier
    function getMode() public pure override returns (Mode) {
        return Mode.ONE;
    }
}
