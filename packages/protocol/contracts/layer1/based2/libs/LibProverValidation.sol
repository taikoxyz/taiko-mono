// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBatchValidation.sol";

/// @title LibProverValidation
/// @notice This library is used to validate the prover authentication.
/// @custom:security-contact security@taiko.xyz
library LibProverValidation {
    using SignatureChecker for address;

    function validateProver(
        I.Config memory _conf,
        LibReadWrite.RW memory _rw,
        I.Summary memory _summary,
        bytes memory _proverAuth,
        I.Batch memory _batch
    )
        internal
        returns (address prover_)
    {
        unchecked {
            if (_batch.proverAuth.length == 0) {
                _rw.debitBond(_conf, _batch.proposer, _conf.livenessBond + _conf.provabilityBond);
                return _batch.proposer;
            }

            // Circular dependency so zero it out. (Batch has proverAuth but
            // proverAuth has also batchHash)
            _batch.proverAuth = "";

            // Outsource the prover authentication to the LibAuth library to
            // reduce this contract's code size.
            address feeToken;
            uint96 fee;
            (prover_, feeToken, fee) = _validateProverAuth(
                _conf.chainId, _summary.numBatches, keccak256(abi.encode(_batch)), _proverAuth
            );

            if (feeToken == _conf.bondToken) {
                // proposer pay the prover fee with bond tokens
                _rw.debitBond(_conf, _batch.proposer, fee + _conf.provabilityBond);

                // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                // if not then add the diff to the bond balance
                int256 bondDelta = int96(fee) - int96(_conf.livenessBond);

                bondDelta < 0
                    ? _rw.debitBond(_conf, prover_, uint256(-bondDelta))
                    : _rw.creditBond(prover_, uint256(bondDelta));
            } else if (_batch.proposer == prover_) {
                _rw.debitBond(_conf, _batch.proposer, _conf.livenessBond + _conf.provabilityBond);
            } else {
                _rw.debitBond(_conf, _batch.proposer, _conf.provabilityBond);
                _rw.debitBond(_conf, prover_, _conf.livenessBond);

                if (fee != 0) {
                    _rw.transferFee(feeToken, _batch.proposer, prover_, fee);
                }
            }
        }
    }

    function _validateProverAuth(
        uint64 _chainId,
        uint64 _batchId,
        bytes32 _batchParamsHash,
        bytes memory _proverAuth
    )
        internal
        view
        returns (address prover_, address feeToken_, uint96 fee_)
    {
        I.ProverAuth memory auth = abi.decode(_proverAuth, (I.ProverAuth));

        // Supporting Ether as fee token will require making ITaikoInbox's proposing function
        // payable. We try to avoid this as much as possible. And since most proposers may simply
        // use USD stablecoins as fee token, we decided not to support Ether as fee token for now.
        require(auth.feeToken != address(0), EtherAsFeeTokenNotSupportedYet());
        require(auth.prover != address(0), InvalidProver());
        require(auth.validUntil == 0 || auth.validUntil >= block.timestamp, InvalidValidUntil());
        require(auth.batchId == 0 || auth.batchId == _batchId, InvalidBatchId());

        // Save and use later, before nullifying in computeProverAuthDigest()
        bytes memory signature = auth.signature;
        auth.signature = "";
        bytes32 digest = _computeProverAuthDigest(_chainId, _batchParamsHash, auth);

        require(auth.prover.isValidSignatureNow(digest, signature), InvalidSignature());

        return (auth.prover, auth.feeToken, auth.fee);
    }

    function _computeProverAuthDigest(
        uint64 _chainId,
        bytes32 _batchParamsHash,
        I.ProverAuth memory _auth
    )
        private
        pure
        returns (bytes32)
    {
        require(_auth.signature.length == 0, SignatureNotEmpty());
        return keccak256(abi.encode("PROVER_AUTHENTICATION", _chainId, _batchParamsHash, _auth));
    }

    // --- ERRORs --------------------------------------------------------------------------------
    error EtherAsFeeTokenNotSupportedYet();
    error InvalidBatchId();
    error InvalidProver();
    error InvalidSignature();
    error InvalidValidUntil();
    error SignatureNotEmpty();
}
