// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibState.sol";

/// @title LibProvers
/// @notice Library for prover authentication and comprehensive bond management in Taiko protocol
/// @dev Handles prover validation and complex bond/fee scenarios including:
///      - Prover authentication signature validation with digest verification
///      - Multiple prover scenarios (self-proving, external prover, bond token fees)
///      - Dynamic bond debiting/crediting based on fee arrangements
///      - Fee token transfers between proposers and provers
///      - Authentication parameter validation (addresses, timing, batch constraints)
/// @custom:security-contact security@taiko.xyz
library LibProvers {
    using SignatureChecker for address;

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Validates the prover and handles comprehensive bond management
    /// @dev Processes different prover authentication scenarios:
    ///      - Self-proving: Proposer proves their own batch
    ///      - External prover with bond token fees
    ///      - External prover with other token fees
    ///      Handles bond debiting/crediting and fee transfers accordingly
    /// @param _conf Protocol configuration parameters
    /// @param _rw Read/write access functions for bond and fee operations
    /// @param _summary Current protocol summary state
    /// @param _proverAuth Prover authentication data (signature + metadata)
    /// @param _batch The batch being proved
    function validateProver(
        I.Config memory _conf,
        LibState.ReadWrite memory _rw,
        I.Summary memory _summary,
        bytes memory _proverAuth,
        I.Batch memory _batch
    )
        internal
    {
        unchecked {
            if (_batch.proverAuth.length == 0) {
                require(_batch.prover == _batch.proposer, InvalidProver());
                _rw.debitBond(_conf, _batch.prover, _conf.livenessBond + _conf.provabilityBond);
            } else {
                // Circular dependency so zero it out. (Batch has proverAuth but
                // proverAuth has also batchHash)
                _batch.proverAuth = "";

                // Outsource the prover authentication to the LibAuth library to
                // reduce this contract's code size.
                (address prover, address feeToken, uint96 fee) = _validateProverAuth(
                    _conf.chainId, _summary.numBatches, keccak256(abi.encode(_batch)), _proverAuth
                );
                require(prover != _batch.prover, InvalidProver());

                if (feeToken == _conf.bondToken) {
                    // proposer pay the prover fee with bond tokens
                    _rw.debitBond(_conf, _batch.proposer, fee + _conf.provabilityBond);

                    // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                    // if not then add the diff to the bond balance
                    int256 bondDelta = int96(fee) - int96(_conf.livenessBond);

                    bondDelta < 0
                        ? _rw.debitBond(_conf, prover, uint256(-bondDelta))
                        : _rw.creditBond(prover, uint256(bondDelta));
                } else if (prover == _batch.proposer) {
                    _rw.debitBond(
                        _conf, _batch.proposer, _conf.livenessBond + _conf.provabilityBond
                    );
                } else {
                    _rw.debitBond(_conf, _batch.proposer, _conf.provabilityBond);
                    _rw.debitBond(_conf, prover, _conf.livenessBond);

                    if (fee != 0) {
                        _rw.transferFee(feeToken, _batch.proposer, prover, fee);
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions - Authentication Validation
    // -------------------------------------------------------------------------

    /// @notice Validates the prover authentication signature and parameters
    /// @dev Decodes authentication data, validates signature, and checks constraints:
    ///      - Prover address must be non-zero
    ///      - Fee token must be non-zero (Ether not supported)
    ///      - Validity period must not be expired
    ///      - Batch ID must match (if specified)
    ///      - Signature must be valid for the computed digest
    /// @param _chainId Chain ID for signature domain separation
    /// @param _batchId Batch ID being proved
    /// @param _batchParamsHash Hash of batch parameters for signature verification
    /// @param _proverAuth Encoded prover authentication data
    /// @return prover Validated prover address
    /// @return feeToken_ Fee token address for payment
    /// @return fee_ Fee amount to be paid
    function _validateProverAuth(
        uint64 _chainId,
        uint64 _batchId,
        bytes32 _batchParamsHash,
        bytes memory _proverAuth
    )
        private
        view
        returns (address prover, address feeToken_, uint96 fee_)
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

    // -------------------------------------------------------------------------
    // Private Functions - Digest Computation
    // -------------------------------------------------------------------------

    /// @notice Computes the digest for prover authentication signature verification
    /// @dev Creates a deterministic hash from chain ID, batch parameters, and auth data.
    ///      The signature field must be empty when computing the digest.
    /// @param _chainId Chain ID for domain separation
    /// @param _batchParamsHash Hash of the batch parameters being proved
    /// @param _auth Prover authentication data (must have empty signature field)
    /// @return Computed digest for signature verification
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

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------
    error EtherAsFeeTokenNotSupportedYet();
    error InvalidBatchId();
    error InvalidProver();
    error InvalidSignature();
    error InvalidValidUntil();
    error SignatureNotEmpty();
}
