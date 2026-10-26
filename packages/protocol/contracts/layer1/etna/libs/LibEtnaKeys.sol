// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";

/// @title LibEtnaKeys
/// @notice The secp256k1 consensus-key and signature checks of the staking registry (spec 4.1,
/// appendix A).
/// @dev A consensus key is supplied as exactly 33 bytes of SEC1 compressed encoding,
/// `prefix ‖ X` with prefix 0x02 (even Y) or 0x03 (odd Y) and X big-endian with its leading
/// zeros. Decoding never reduces X modulo p and accepts only an input that recompresses to itself
/// byte for byte. A signature is exactly 65 bytes `R ‖ S ‖ V` with V in {0, 1}, 0 < R < n and
/// 0 < S ≤ n / 2 (low s), and must recover a nonzero address.
/// @custom:security-contact security@taiko.xyz
library LibEtnaKeys {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The secp256k1 field prime, 2^256 - 2^32 - 977.
    uint256 internal constant P =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    /// @dev The secp256k1 group order.
    uint256 internal constant N =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    /// @dev The square-root exponent (p + 1) / 4; a^((p + 1) / 4) is a square root of a whenever
    /// one exists, because p = 3 (mod 4).
    uint256 private constant _SQRT_EXPONENT = (P + 1) / 4;

    /// @dev The largest low s, floor(n / 2).
    uint256 private constant _HALF_N = N / 2;

    /// @dev The modular exponentiation precompile (EIP-198).
    address private constant _MODEXP = address(0x05);

    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Decodes a 33-byte compressed consensus key. Reverts with `InvalidPublicKey` unless
    /// the input is exactly 33 bytes and `decompress` accepts its prefix and X.
    /// @param _publicKey The compressed key, `prefix ‖ X`.
    /// @return prefix_ The SEC1 prefix, 0x02 or 0x03.
    /// @return x_ The X coordinate.
    /// @return y_ The Y coordinate of the encoded point.
    function parsePublicKey(bytes calldata _publicKey)
        internal
        view
        returns (uint8 prefix_, bytes32 x_, bytes32 y_)
    {
        if (_publicKey.length != 33) revert IEtnaStakingRegistry.InvalidPublicKey();
        prefix_ = uint8(_publicKey[0]);
        x_ = bytes32(_publicKey[1:33]);
        y_ = decompress(prefix_, x_);
    }

    /// @dev Derives the Y coordinate of the point with the given X and SEC1 prefix (appendix A).
    /// Reverts with `InvalidPublicKey` if the prefix is not 0x02 or 0x03, X is not below p (X is
    /// never reduced), x^3 + 7 has no square root mod p, or the modexp call fails or returns
    /// anything but one 32-byte root below p.
    /// @param _prefix The SEC1 prefix: 0x02 for an even Y, 0x03 for an odd Y.
    /// @param _x The X coordinate.
    /// @return y_ The Y coordinate, below p, whose parity matches the prefix.
    function decompress(uint8 _prefix, bytes32 _x) internal view returns (bytes32 y_) {
        uint256 x = uint256(_x);
        if ((_prefix != 2 && _prefix != 3) || x >= P) {
            revert IEtnaStakingRegistry.InvalidPublicKey();
        }
        uint256 a = addmod(mulmod(mulmod(x, x, P), x, P), 7, P);

        (bool ok, bytes memory out) =
            _MODEXP.staticcall(abi.encode(32, 32, 32, a, _SQRT_EXPONENT, P));
        if (!ok || out.length != 32) revert IEtnaStakingRegistry.InvalidPublicKey();
        uint256 y0 = abi.decode(out, (uint256));
        if (y0 >= P || mulmod(y0, y0, P) != a) revert IEtnaStakingRegistry.InvalidPublicKey();

        uint256 y = (y0 & 1) == _prefix - 2 ? y0 : P - y0;
        // Recompression (appendix A): Y is below p and its parity gives back the prefix; X is
        // used as given. The checks above already imply this; it is kept as the spec states it.
        if (y >= P || 2 + (y & 1) != _prefix) revert IEtnaStakingRegistry.InvalidPublicKey();
        y_ = bytes32(y);
    }

    /// @dev The address of a consensus key: the last 20 bytes of keccak256(X ‖ Y) over the two
    /// 32-byte coordinates (no 0x04 prefix).
    /// @param _x The X coordinate.
    /// @param _y The Y coordinate.
    /// @return The key's address.
    function ckAddr(bytes32 _x, bytes32 _y) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(_x, _y)))));
    }

    /// @dev The identity of a slot's occupant in recovery exclusions:
    /// keccak256(abi.encode(uint256(prefix), X)) (appendix A).
    /// @param _prefix The SEC1 prefix.
    /// @param _x The X coordinate.
    /// @return The entry key.
    function entryKey(uint8 _prefix, bytes32 _x) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(_prefix), _x));
    }

    /// @dev Recovers the signer of `_digest`. Reverts with `InvalidSignature` if `parseSignature`
    /// rejects the signature or `ecrecover` returns the zero address; never returns zero.
    /// @param _digest The signed digest.
    /// @param _sig The 65-byte signature `R ‖ S ‖ V`.
    /// @return signer_ The recovered address.
    function recoverSigner(
        bytes32 _digest,
        bytes memory _sig
    )
        internal
        pure
        returns (address signer_)
    {
        (uint8 v, bytes32 r, bytes32 s) = parseSignature(_sig);
        signer_ = ecrecover(_digest, v + 27, r, s);
        if (signer_ == address(0)) revert IEtnaStakingRegistry.InvalidSignature();
    }

    /// @dev Splits a signature and checks its encoding and ranges. Reverts with
    /// `InvalidSignature` unless it is exactly 65 bytes with V in {0, 1}, 0 < R < n and
    /// 0 < S ≤ n / 2.
    /// @param _sig The signature `R ‖ S ‖ V`.
    /// @return v_ The recovery id V, 0 or 1.
    /// @return r_ R.
    /// @return s_ S.
    function parseSignature(bytes memory _sig)
        internal
        pure
        returns (uint8 v_, bytes32 r_, bytes32 s_)
    {
        if (_sig.length != 65) revert IEtnaStakingRegistry.InvalidSignature();
        assembly ("memory-safe") {
            r_ := mload(add(_sig, 0x20))
            s_ := mload(add(_sig, 0x40))
            v_ := byte(0, mload(add(_sig, 0x60)))
        }
        if (v_ > 1 || r_ == 0 || uint256(r_) >= N || s_ == 0 || uint256(s_) > _HALF_N) {
            revert IEtnaStakingRegistry.InvalidSignature();
        }
    }
}
