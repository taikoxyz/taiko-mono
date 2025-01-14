// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@risc0/contracts/IRiscZeroVerifier.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
import "../based/ITaikoInbox.sol";
import "./LibPublicInput.sol";
import "./IVerifier.sol";

/// @title Risc0Verifier
/// @custom:security-contact security@taiko.xyz
abstract contract VerifierBase is EssentialContract, IVerifier {
    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    /// @param _rollupResolver The {IResolver} used by this rollup
    function init(address _owner, address _rollupResolver) external initializer {
        __Essential_init(_owner, _rollupResolver);
    }

    function _authorizePause(
        address,
        bool
    )
        internal
        virtual
        override
        onlyFromOwnerOrNamed(LibStrings.B_TAIKO)
    { }
}
