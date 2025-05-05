// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title LibProverAuth
/// @notice This library is used to validate the prover authentication.
/// @dev This libarary's validateProverAuth function is made public to reduce TaikoInbox's code size
/// .
/// @custom:security-contact security@taiko.xyz
library LibProverAuth {
    using ECDSA for bytes32;

    struct ProverAuth {
        uint96 fee;
        uint64 validUntil; // Optional expiration
        uint64 chainId; // Replay protection across chains
        bytes32 batchParamsHash; // hash of batch parameters
        bytes32 txListHash; // hash of the tx list
        bytes signature;
    }

    error InvalidValidUntil();
    error MismatchingBatchParamsHash();
    error MismatchingChainId();
    error MismatchingTxListHash();

    function validateProverAuth(
        uint64 _chainId,
        bytes32 _batchParamsHash,
        bytes32 _txListHash, // basically the "TX" (location) identifier of some sort. Same as
            // return value of: _calculateTxsHash(txListHash, params.blobParams)
        bytes calldata _proverAuth
    )
        public
        view
        returns (address prover_, uint96 fee_)
    {
        ProverAuth memory auth = abi.decode(_proverAuth, (ProverAuth));

        // If `validUntil` is used, make sure it's still valid
        if (auth.validUntil != 0 && auth.validUntil < block.timestamp) {
            revert InvalidValidUntil();
        }

        if (auth.chainId != _chainId) {
            revert MismatchingChainId();
        }

        if (auth.batchParamsHash != _batchParamsHash) {
            revert MismatchingBatchParamsHash();
        }

        if (auth.txListHash != _txListHash) {
            revert MismatchingTxListHash();
        }

        // Save the signature
        bytes memory signature = auth.signature;
        // The payload what the prover signed had obviously no signature before so clear the
        // signature before hashing
        auth.signature = ""; // clear the signature before hashing

        bytes32 digest = keccak256(abi.encode("PROVER_AUTHENTICATION", auth));

        prover_ = digest.recover(signature);
        fee_ = auth.fee;
    }
}
