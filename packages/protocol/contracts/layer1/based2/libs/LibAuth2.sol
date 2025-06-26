// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibAuth2
/// @notice This library is used to validate the prover authentication.
/// @custom:security-contact security@taiko.xyz
library LibAuth2 {
    using SignatureChecker for address;

    function validateProverAuth(
        uint64 _chainId,
        uint64 _batchId,
        bytes32 _batchParamsHash,
        bytes32 _txListHash,
        bytes calldata _proverAuth
    )
        internal
        view
        returns (address prover_, address feeToken_, uint96 fee_)
    {
        I.ProverAuth memory auth = abi.decode(_proverAuth, (I.ProverAuth));

        // Supporting Ether as fee token will require making ITaikoInbox's proposing function
        // payable. We try to avoid this as much as possible. And since most proposers may simply
        // use USD stablecoins as fee token, we decided not to support Ether as fee token for now.
        require(auth.feeToken != address(0), I.EtherAsFeeTokenNotSupportedYet());

        require(auth.prover != address(0), I.InvalidProver());
        require(auth.validUntil == 0 || auth.validUntil >= block.timestamp, I.InvalidValidUntil());
        require(auth.batchId == 0 || auth.batchId == _batchId, I.InvalidBatchId());

        // Save and use later, before nullifying in computeProverAuthDigest()
        bytes memory signature = auth.signature;
        auth.signature = "";
        bytes32 digest = _computeProverAuthDigest(_chainId, _batchParamsHash, _txListHash, auth);

        require(auth.prover.isValidSignatureNow(digest, signature), I.InvalidSignature());

        return (auth.prover, auth.feeToken, auth.fee);
    }

    function _computeProverAuthDigest(
        uint64 _chainId,
        bytes32 _batchParamsHash,
        bytes32 _txListHash,
        I.ProverAuth memory _auth
    )
        private
        pure
        returns (bytes32)
    {
        require(_auth.signature.length == 0, I.SignatureNotEmpty());
        return keccak256(
            abi.encode("PROVER_AUTHENTICATION", _chainId, _batchParamsHash, _txListHash, _auth)
        );
    }
}
