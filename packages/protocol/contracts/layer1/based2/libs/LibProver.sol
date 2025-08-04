// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "../IInbox.sol";
import "./LibBinding.sol";

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
    /// @param _bindings Read/write bindings functions for bond and fee operations
    /// @param _config Protocol configuration parameters
    /// @param _summary Current protocol summary state
    /// @param _batch The batch being proved
    function validateProver(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.Summary memory _summary,
        IInbox.Batch memory _batch
    )
        internal
        returns (address prover_)
    {
        uint256 livenessBond = uint256(_config.livenessBond) * 1 gwei;
        uint256 provabilityBond = uint256(_config.provabilityBond) * 1 gwei;

        unchecked {
            if (_batch.proverAuth.length == 0) {
                prover_ = msg.sender;
                _bindings.debitBond(_config, prover_, livenessBond + provabilityBond);
            } else {
                // Circular dependency so zero it out. (Batch has proverAuth but
                // proverAuth has also batchHash)
                bytes memory proverAuth = _batch.proverAuth;
                _batch.proverAuth = "";

                // Outsource the prover authentication to the LibAuth library to
                // reduce this contract's code size.
                address feeToken;
                uint256 fee;
                (prover_, feeToken, fee) = _validateProverAuth(
                    _bindings,
                    _config.chainId,
                    _summary.nextBatchId,
                    keccak256(abi.encode(_batch)),
                    proverAuth
                );

                if (feeToken == _config.bondToken) {
                    // proposer pay the prover fee with bond tokens
                    _bindings.debitBond(_config, msg.sender, fee + provabilityBond);

                    // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                    // if not then add the diff to the bond balance
                    int256 bondDelta = int256(fee) - int256(livenessBond);

                    bondDelta < 0
                        ? _bindings.debitBond(_config, prover_, uint256(-bondDelta))
                        : _bindings.creditBond(prover_, uint256(bondDelta));
                } else if (prover_ == msg.sender) {
                    _bindings.debitBond(_config, msg.sender, livenessBond + provabilityBond);
                } else {
                    _bindings.debitBond(_config, msg.sender, provabilityBond);
                    _bindings.debitBond(_config, prover_, livenessBond);

                    if (fee != 0) {
                        _bindings.transferFee(feeToken, msg.sender, prover_, fee);
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
    /// @param _batchHash Hash of batch parameters for signature verification
    /// @param _proverAuth Encoded prover authentication data
    /// @return prover_ Validated prover address
    /// @return feeToken_ Fee token address for payment
    /// @return fee_ Fee amount to be paid
    function _validateProverAuth(
        LibBinding.Bindings memory _bindings,
        uint64 _chainId,
        uint64 _batchId,
        bytes32 _batchHash,
        bytes memory _proverAuth
    )
        private
        view
        returns (address prover_, address feeToken_, uint256 fee_)
    {
        IInbox.ProverAuth memory auth = _bindings.decodeProverAuth(_proverAuth);

        // Supporting Ether as fee token will require making IInbox's proposing function
        // payable. We try to avoid this as much as possible. And since most proposers may simply
        // use USD stablecoins as fee token, we decided not to support Ether as fee token for now.
        if (auth.feeToken == address(0)) revert EtherAsFeeTokenNotSupportedYet();
        if (auth.prover == address(0)) revert InvalidProver();
        if (auth.validUntil != 0 && auth.validUntil < block.timestamp) revert InvalidValidUntil();
        if (auth.batchId != 0 && auth.batchId != _batchId) revert InvalidBatchId();

        // Save and use later, before nullifying in computeProverAuthDigest()
        bytes memory signature = auth.signature;
        auth.signature = "";
        bytes32 digest = _computeProverAuthDigest(_chainId, _batchHash, auth);

        if (!auth.prover.isValidSignatureNow(digest, signature)) revert InvalidSignature();

        return (auth.prover, auth.feeToken, auth.fee);
    }

    // -------------------------------------------------------------------------
    // Private Functions - Digest Computation
    // -------------------------------------------------------------------------

    /// @notice Computes the digest for prover authentication signature verification
    /// @dev Creates a deterministic hash from chain ID, batch parameters, and auth data.
    ///      The signature field must be empty when computing the digest.
    /// @param _chainId Chain ID for domain separation
    /// @param _batchHash Hash of the batch parameters being proved
    /// @param _auth Prover authentication data (must have empty signature field)
    /// @return Computed digest for signature verification
    function _computeProverAuthDigest(
        uint64 _chainId,
        bytes32 _batchHash,
        IInbox.ProverAuth memory _auth
    )
        private
        pure
        returns (bytes32)
    {
        if (_auth.signature.length != 0) revert SignatureNotEmpty();
        return keccak256(abi.encode("PROVER_AUTHENTICATION", _chainId, _batchHash, _auth));
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
