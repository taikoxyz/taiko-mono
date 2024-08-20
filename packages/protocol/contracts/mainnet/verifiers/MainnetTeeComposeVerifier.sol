// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/compose/TeeComposeVerifier.sol";

/// @title MainnetTeeComposeVerifier
/// @custom:security-contact security@taiko.xyz
contract MainnetTeeComposeVerifier is TeeComposeVerifier {
    constructor() TeeComposeVerifier(address(0)) { }

    /// @notice This function returns the address of the MainnetSgxVerifier.
    /// @return The address of a MainnetSgxVerifier.
    function sgxVerifier() public pure override returns (address) {
        revert("not implemented");
    }
}
