// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain canonical ECDSA signatures
/// @custom:security-contact security@taiko.xyz
library LibSlotChainSignatures {
    uint256 internal constant SIGNATURE_LENGTH = 65;
    uint256 internal constant SECP256K1N_HALF =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    /// @dev Recovers the nonzero signer of one exact 65-byte `r || s || v` signature.
    /// @param _digest The already domain-separated EIP-712 signing digest.
    /// @param _signature The exact canonical signature without a suffix.
    /// @return signer_ The nonzero recovered signer.
    function recoverSigner(
        bytes32 _digest,
        bytes calldata _signature
    )
        internal
        pure
        returns (address signer_)
    {
        if (_signature.length != SIGNATURE_LENGTH) revert InvalidSignatureLength();
        return recoverSignerAt(_digest, _signature, 0);
    }

    /// @dev Recovers a signer from one exact 65-byte slice inside a larger canonical wire record.
    /// @param _digest The already domain-separated EIP-712 signing digest.
    /// @param _encoded The containing canonical bytes.
    /// @param _offset The exact byte offset of the signature slice.
    /// @return signer_ The nonzero recovered signer.
    function recoverSignerAt(
        bytes32 _digest,
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (address signer_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < SIGNATURE_LENGTH) {
            revert InvalidSignatureLength();
        }

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(add(_encoded.offset, _offset))
            s := calldataload(add(add(_encoded.offset, _offset), 32))
            v := byte(0, calldataload(add(add(_encoded.offset, _offset), 64)))
        }
        return recoverSigner(_digest, r, s, v);
    }

    /// @dev Recovers the nonzero signer after enforcing nonzero `r`/`s`, low-`s`, and canonical
    ///      `v` in {27, 28}. Compact and transaction-style recovery IDs are rejected.
    function recoverSigner(
        bytes32 _digest,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    )
        internal
        pure
        returns (address signer_)
    {
        if (
            _r == bytes32(0) || _s == bytes32(0) || uint256(_s) > SECP256K1N_HALF
                || (_v != 27 && _v != 28)
        ) {
            revert InvalidSignature();
        }
        signer_ = ecrecover(_digest, _v, _r, _s);
        if (signer_ == address(0)) revert InvalidSignature();
    }

    /// @dev Requires an exact signature to recover the caller-derived expected nonzero signer.
    function requireSigner(
        bytes32 _digest,
        bytes calldata _signature,
        address _expectedSigner
    )
        internal
        pure
    {
        if (_expectedSigner == address(0) || recoverSigner(_digest, _signature) != _expectedSigner)
        {
            revert SignerMismatch();
        }
    }

    error InvalidSignature();
    error InvalidSignatureLength();
    error SignerMismatch();
}
