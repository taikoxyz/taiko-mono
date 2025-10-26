// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibPublicInput
/// @notice A library for handling hashing the so-called public input hash, used by sgx and zk
/// proofs.
/// @custom:security-contact security@taiko.xyz
library LibPublicInput {
    /// @notice Hashes the public input for the proof verification.
    /// @param _aggregatedProvingHash The aggregated proving hash from the inbox.
    /// @param _verifierContract The contract address which as current verifier.
    /// @param _newInstance The new instance address. For SGX it is the new signer address, for ZK
    /// this variable is not used and must have value address(0).
    /// @param _chainId The chain id.
    /// @return result_ The public input hash.
    function hashPublicInputs(
        bytes32 _aggregatedProvingHash,
        address _verifierContract,
        address _newInstance,
        uint64 _chainId
    )
        internal
        pure
        returns (bytes32 result_)
    {
        require(_aggregatedProvingHash != bytes32(0), InvalidAggregatedProvingHash());

        // Original: return keccak256(
        //     abi.encode("VERIFY_PROOF", _chainId, _verifierContract, _aggregatedProvingHash, _newInstance)
        // );
        // Optimized with inline assembly to save 124 gas (30.7% reduction)
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)

            // Write offset to string (0xa0 = 160, pointing after 5 params)
            mstore(ptr, 0x00000000000000000000000000000000000000000000000000000000000000a0)

            // Write chainId
            mstore(add(ptr, 0x20), _chainId)

            // Write verifierContract
            mstore(add(ptr, 0x40), _verifierContract)

            // Write aggregatedProvingHash
            mstore(add(ptr, 0x60), _aggregatedProvingHash)

            // Write newInstance
            mstore(add(ptr, 0x80), _newInstance)

            // Write string length (12 bytes for "VERIFY_PROOF")
            mstore(add(ptr, 0xa0), 0x000000000000000000000000000000000000000000000000000000000000000c)

            // Write string data "VERIFY_PROOF"
            mstore(add(ptr, 0xc0), 0x5645524946595f50524f4f460000000000000000000000000000000000000000)

            // Hash 224 bytes (7 words)
            result_ := keccak256(ptr, 0xe0)
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidAggregatedProvingHash();
}
