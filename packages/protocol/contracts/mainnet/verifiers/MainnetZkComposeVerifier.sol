// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/compose/ZkComposeVerifier.sol";

/// @title MainnetZkComposeVerifier
/// @custom:security-contact security@taiko.xyz
contract MainnetZkComposeVerifier is ZkComposeVerifier {
    constructor() ZkComposeVerifier(address(0), address(0)) { }

    /// @notice This function returns the address of the MainnetRisc0Verifier.
    /// @return The address of a MainnetRisc0Verifier.
    function risc0Verifier() public pure override returns (address) {
        revert("not implemented");
    }

    /// @notice This function returns the address of the MainnetSP1Verifier.
    /// @return The address of a MainnetSP1Verifier
    function sp1Verifier() public pure override returns (address) {
        revert("not implemented");
    }
}
