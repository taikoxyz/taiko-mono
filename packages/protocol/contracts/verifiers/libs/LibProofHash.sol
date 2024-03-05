// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../L1/ITaikoL1.sol";

/// @title LibProofHash
/// @notice A library for handling hashing the so-called public input hash, used by sgx and zk
/// proofs.
/// @custom:security-contact security@taiko.xyz
library LibProofHash {
    /// @notice Gets the hash for the proof verification.
    /// @param _tran The transition to verify.
    /// @param _newInstance The new instance address. For SGX it is the new signer address, for ZK
    /// this variable is not used.
    /// @param _prover The prover address.
    /// @param _metaHash The meta hash.
    /// @return The public input hash.
    function getProofHash(
        TaikoData.Transition memory _tran,
        address _verifierContract,
        address _newInstance,
        address _prover,
        bytes32 _metaHash,
        uint64 _chainId
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                "VERIFY_PROOF", _chainId, _verifierContract, _tran, _newInstance, _prover, _metaHash
            )
        );
    }
}
