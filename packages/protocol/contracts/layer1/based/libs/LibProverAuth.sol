// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/// @title LibProverAuth
/// @notice This library is used to validate the prover authentication.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
library LibProverAuth {
    using SignatureChecker for address;

    struct ProverAuth {
        address prover;
        address feeToken;
        uint96 fee;
        uint64 validUntil; // optional
        uint64 batchId; // optional
        bytes signature;
    }

    error InvalidBatchId();
    error InvalidSignature();
    error InvalidValidUntil();
    error InvalidProver();
    error EtherAsFeeTokenNotSupportedYet();
    error SignatureNotEmpty();

    function validateProverAuth(
        uint64 _chainId,
        uint64 _batchId,
        bytes32 _batchParamsHash,
        bytes32 _txListHash,
        bytes memory _proverAuth
    )
        public // reduce code size
        view
        returns (ProverAuth memory auth_)
    {
        auth_ = abi.decode(_proverAuth, (ProverAuth));

        // Supporting Ether as fee token will require making ITaikoInbox's proposing function
        // payable. We try to avoid this as much as possible. And since most proposers may simply
        // use USD stablecoins as fee token, we decided not to support Ether as fee token for now.
        require(auth_.feeToken != address(0), EtherAsFeeTokenNotSupportedYet());

        require(auth_.prover != address(0), InvalidProver());
        require(auth_.validUntil == 0 || auth_.validUntil >= block.timestamp, InvalidValidUntil());
        require(auth_.batchId == 0 || auth_.batchId == _batchId, InvalidBatchId());

        // Save and use later, before nullifying in computeProverAuthDigest()
        bytes memory signature = auth_.signature;
        auth_.signature = "";
        bytes32 digest = computeProverAuthDigest(_chainId, _batchParamsHash, _txListHash, auth_);

        require(auth_.prover.isValidSignatureNow(digest, signature), InvalidSignature());
    }

    function computeProverAuthDigest(
        uint64 _chainId,
        bytes32 _batchParamsHash,
        bytes32 _txListHash,
        ProverAuth memory _auth
    )
        internal
        pure
        returns (bytes32)
    {
        require(_auth.signature.length == 0, SignatureNotEmpty());
        return keccak256(
            abi.encode("PROVER_AUTHENTICATION", _chainId, _batchParamsHash, _txListHash, _auth)
        );
    }
}
