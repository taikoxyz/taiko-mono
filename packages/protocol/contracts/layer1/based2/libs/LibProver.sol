// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { IInbox as I } from "../IInbox.sol";
import "./LibState.sol";

/// @title LibProver
/// @notice Library for prover authentication and comprehensive bond management in Taiko protocol
/// @dev Handles prover validation and complex bond/fee scenarios including:
///      - Prover authentication signature validation with digest verification
///      - Multiple prover scenarios (self-proving, external prover, bond token fees)
///      - Dynamic bond debiting/crediting based on fee arrangements
///      - Fee token transfers between proposers and provers
///      - Authentication parameter validation (addresses, timing, batch constraints)
/// @custom:security-contact security@taiko.xyz
library LibProver {
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
    /// @param _access Read/write access functions for bond and fee operations
    /// @param _config Protocol configuration parameters
    /// @param _summary Current protocol summary state
    /// @param _proverAuth Prover authentication data (signature + metadata)
    /// @param _batch The batch being proved
    function validateProver(
        LibState.Access memory _access,
        I.Config memory _config,
        I.Summary memory _summary,
        bytes memory _proverAuth,
        I.Batch memory _batch
    )
        internal
        returns (address prover_)
    {
        uint256 livenessBond = uint256(_config.livenessBond) * 1 gwei;
        uint256 provabilityBond = uint256(_config.provabilityBond) * 1 gwei;

        unchecked {
            if (_batch.proverAuth.length == 0) {
                prover_ = _batch.proposer;
                _access.debitBond(_config, prover_, livenessBond + provabilityBond);
            } else {
                // Circular dependency so zero it out. (Batch has proverAuth but
                // proverAuth has also batchHash)
                _batch.proverAuth = "";

                // Outsource the prover authentication to the LibAuth library to
                // reduce this contract's code size.
                address feeToken;
                uint256 fee;
                (prover_, feeToken, fee) = _validateProverAuth(
                    _config.chainId,
                    _summary.nextBatchId,
                    keccak256(abi.encode(_batch)),
                    _proverAuth
                );

                if (feeToken == _config.bondToken) {
                    // proposer pay the prover fee with bond tokens
                    _access.debitBond(_config, _batch.proposer, fee + provabilityBond);

                    // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                    // if not then add the diff to the bond balance
                    int256 bondDelta = int256(fee) - int256(livenessBond);

                    bondDelta < 0
                        ? _access.debitBond(_config, prover_, uint256(-bondDelta))
                        : _access.creditBond(prover_, uint256(bondDelta));
                } else if (prover_ == _batch.proposer) {
                    _access.debitBond(_config, _batch.proposer, livenessBond + provabilityBond);
                } else {
                    _access.debitBond(_config, _batch.proposer, provabilityBond);
                    _access.debitBond(_config, prover_, livenessBond);

                    if (fee != 0) {
                        _access.transferFee(feeToken, _batch.proposer, prover_, fee);
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
    /// @return prover_ Validated prover address
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
        returns (address prover_, address feeToken_, uint256 fee_)
    {
        I.ProverAuth memory auth = abi.decode(_proverAuth, (I.ProverAuth));

        // Supporting Ether as fee token will require making IInbox's proposing function
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
    // Errors
    // -------------------------------------------------------------------------

    error EtherAsFeeTokenNotSupportedYet();
    error InvalidBatchId();
    error InvalidProver();
    error InvalidSignature();
    error InvalidValidUntil();
    error SignatureNotEmpty();
}
