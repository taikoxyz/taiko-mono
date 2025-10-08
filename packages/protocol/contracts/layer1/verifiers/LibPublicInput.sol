// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../layer1/based/ITaikoInbox.sol";

/// @title LibPublicInput
/// @notice A library for handling hashing the so-called public input hash, used by sgx and zk
/// proofs.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
library LibPublicInput {
    /// @notice Hashes the public input for the proof verification.
    /// @param _transition The transition to verify.
    /// @param _verifierContract The contract address which as current verifier.
    /// @param _newInstance The new instance address. For SGX it is the new signer address, for ZK
    /// this variable is not used and must have value address(0).
    /// @param _metaHash The meta hash.
    /// @param _chainId The chain id.
    /// @return The public input hash.
    function hashPublicInputs(
        ITaikoInbox.Transition memory _transition,
        address _verifierContract,
        address _newInstance,
        bytes32 _metaHash,
        uint64 _chainId,
        address _prover
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                "VERIFY_PROOF",
                _chainId,
                _verifierContract,
                _transition,
                _newInstance,
                _metaHash,
                _prover
            )
        );
    }
}
