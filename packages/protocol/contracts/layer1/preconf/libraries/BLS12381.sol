// SPDX-License-Identifier: MIT
// Functions in this library have been adapted from:
// https://github.com/ethyla/bls12-381-hash-to-curve/blob/main/src/HashToCurve.sol
pragma solidity ^0.8.24;

library BLS12381 {
    using BLS12381 for *;

    struct FieldPoint2 {
        uint256[2] u;
        uint256[2] u_I;
    }

    struct G1Point {
        uint256[2] x;
        uint256[2] y;
    }

    struct G2Point {
        uint256[2] x;
        uint256[2] x_I;
        uint256[2] y;
        uint256[2] y_I;
    }

    /// @dev Referenced from https://eips.ethereum.org/EIPS/eip-2537#curve-parameters
    function baseFieldModulus() internal pure returns (uint256[2] memory) {
        return [
            0x000000000000000000000000000000001a0111ea397fe69a4b1ba7b6434bacd7,
            0x64774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
        ];
    }

    /// @dev Referenced from https://eips.ethereum.org/EIPS/eip-2537#curve-parameters
    function negGeneratorG1() internal pure returns (G1Point memory) {
        return G1Point({
            x: [
                0x0000000000000000000000000000000017f1d3a73197d7942695638c4fa9ac0f,
                0xc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb
            ],
            y: [
                0x00000000000000000000000000000000114d1d6855d545a8aa7d76c8cf2e21f2,
                0x67816aef1db507c96655b9d5caac42364e6f38ba0ecb751bad54dcd6b939c2ca
            ]
        });
    }

    /**
     * @notice Negates a G1 point, by reflecting it over the x-axis
     * @dev Assumes that the Y coordinate is always less than the field modulus
     * @param point The G1 point to negate
     */
    function negate(G1Point memory point) internal pure returns (G1Point memory) {
        uint256[2] memory fieldModulus = baseFieldModulus();
        uint256[2] memory yNeg;

        // Perform word-wise elementary subtraction
        if (fieldModulus[1] < point.y[1]) {
            yNeg[1] = type(uint256).max - (point.y[1] - fieldModulus[1]) + 1;
            fieldModulus[0] -= 1; // borrow
        } else {
            yNeg[1] = fieldModulus[1] - point.y[1];
        }
        yNeg[0] = fieldModulus[0] - point.y[0];

        return G1Point({x: point.x, y: yNeg});
    }

    /**
     * @notice Transforms a sequence of bytes into a G2 point
     * @dev Based on https://datatracker.ietf.org/doc/html/rfc9380
     * @param message The message to hash
     * @param dst The domain separation tag
     */
    function hashToCurveG2(bytes memory message, bytes memory dst) internal view returns (G2Point memory r) {
        // 1. u = hash_to_field(msg, 2)
        FieldPoint2[2] memory u = hashToFieldFp2(message, dst);
        // 2. Q0 = map_to_curve(u[0])
        G2Point memory q0 = u[0].mapToG2();
        // 3. Q1 = map_to_curve(u[1])
        G2Point memory q1 = u[1].mapToG2();
        // 4. R = Q0 + Q1
        r = q0.plus(q1);
        // 5. P = clear_cofactor(R)
        // Not needed as map fp to g2 already does it
    }

    /**
     * @notice Transforms a sequence of bytes into an element in the FP2 field
     * @dev Based on https://datatracker.ietf.org/doc/html/rfc9380
     * @param message The message to hash
     * @param dst The domain separation tag
     */
    function hashToFieldFp2(bytes memory message, bytes memory dst) internal view returns (FieldPoint2[2] memory) {
        // 1. len_in_bytes = count * m * L
        // so always 2 * 2 * 64 = 256
        uint16 lenInBytes = 256;
        // 2. uniform_bytes = expand_message(msg, DST, len_in_bytes)
        uint256[] memory pseudoRandomBytes = _expandMsgXmd(message, dst, lenInBytes);
        FieldPoint2[2] memory u;
        // No loop here saves 800 gas hardcoding offset an additional 300
        // 3. for i in (0, ..., count - 1):
        // 4.   for j in (0, ..., m - 1):
        // 5.     elm_offset = L * (j + i * m)
        // 6.     tv = substr(uniform_bytes, elm_offset, HTF_L)
        // uint8 HTF_L = 64;
        // bytes memory tv = new bytes(64);
        // 7.     e_j = OS2IP(tv) mod p
        // 8.   u_i = (e_0, ..., e_(m - 1))
        // tv = bytes.concat(pseudo_random_bytes[0], pseudo_random_bytes[1]);
        u[0].u = _modfield(pseudoRandomBytes[0], pseudoRandomBytes[1]);
        u[0].u_I = _modfield(pseudoRandomBytes[2], pseudoRandomBytes[3]);
        u[1].u = _modfield(pseudoRandomBytes[4], pseudoRandomBytes[5]);
        u[1].u_I = _modfield(pseudoRandomBytes[6], pseudoRandomBytes[7]);
        // 9. return (u_0, ..., u_(count - 1))
        return u;
    }

    /**
     * @notice Returns a G1Point in the compressed form
     * @dev Based on https://github.com/zcash/librustzcash/blob/6e0364cd42a2b3d2b958a54771ef51a8db79dd29/pairing/src/bls12_381/README.md#serialization
     * @param point The G1 point to compress
     */
    function compress(G1Point memory point) internal pure returns (uint256[2] memory) {
        uint256[2] memory r = point.x;

        // Set the first MSB
        r[0] = r[0] | (1 << 127);

        // Second MSB is left to be 0 since we are assuming that no infinity points are involved

        // Set the third MSB if point.y is lexicographically larger than the y in negated point
        if (_greaterThan(point.y, point.negate().y)) {
            r[0] = r[0] | (1 << 125);
        }

        return r;
    }

    //==================
    // Precompile calls
    //==================

    /**
     * @notice Adds two G2 points using the precompile at 0x0e
     */
    function plus(G2Point memory point1, G2Point memory point2) internal view returns (G2Point memory) {
        uint256[8] memory r;

        uint256[16] memory input = [
            point1.x[0],
            point1.x[1],
            point1.x_I[0],
            point1.x_I[1],
            point1.y[0],
            point1.y[1],
            point1.y_I[0],
            point1.y_I[1],
            point2.x[0],
            point2.x[1],
            point2.x_I[0],
            point2.x_I[1],
            point2.y[0],
            point2.y[1],
            point2.y_I[0],
            point2.y_I[1]
        ];

        // ABI for G2 addition precompile
        // G2 addition call expects 512 bytes as an input that is interpreted as byte concatenation of two G2 points (256 bytes each). Output is an encoding of addition operation result - single G2 point (256 bytes).
        assembly {
            let success :=
                staticcall(
                    sub(gas(), 2000),
                    /// gas should be 800
                    0x0e, // address of BLS12_G2ADD
                    input, //input offset
                    512, // input size
                    r, // output offset
                    256 // output size
                )
            if iszero(success) { revert(0, 0) }
        }

        return _resolveG2Point(r);
    }

    /**
     * @notice Maps an element of the FP2 field to a G2 point using the precompile at 0x13
     */
    function mapToG2(FieldPoint2 memory fp2) internal view returns (G2Point memory) {
        uint256[8] memory r;

        uint256[4] memory input = [fp2.u[0], fp2.u[1], fp2.u_I[0], fp2.u_I[1]];

        // ABI for mapping Fp2 element to G2 point precompile
        // Field-to-curve call expects 128 bytes an an input that is interpreted as a an element of the quadratic extension field. Output of this call is 256 bytes and is G2 point following respective encoding rules.
        assembly {
            let success :=
                staticcall(
                    sub(gas(), 2000),
                    /// gas should be 75000
                    0x13, // address of BLS12_MAP_FP2_TO_G2
                    input, //input offset
                    128, // input size
                    r, // output offset
                    256 // output size
                )
            if iszero(success) { revert(0, 0) }
        }

        return _resolveG2Point(r);
    }

    /**
     * @notice Pairing check using the precompile at 0x11
     */
    function pairing(G1Point memory a1, G2Point memory b1, G1Point memory a2, G2Point memory b2)
        internal
        view
        returns (bool)
    {
        bool[1] memory r;

        uint256[24] memory input = [
            a1.x[0],
            a1.x[1],
            a1.y[0],
            a1.y[1],
            b1.x[0],
            b1.x[1],
            b1.x_I[0],
            b1.x_I[1],
            b1.y[0],
            b1.y[1],
            b1.y_I[0],
            b1.y_I[1],
            a2.x[0],
            a2.x[1],
            a2.y[0],
            a2.y[1],
            b2.x[0],
            b2.x[1],
            b2.x_I[0],
            b2.x_I[1],
            b2.y[0],
            b2.y[1],
            b2.y_I[0],
            b2.y_I[1]
        ];

        // ABI for pairing precompile
        // Pairing expects 384 (G1Point = 128 bytes, G2Point = 256 bytes) * k bytes as input.
        // In this case, since two pairs of points are being passed, the input size is 384 * 2 = 768 bytes.
        assembly {
            let success :=
                staticcall(
                    sub(gas(), 2000),
                    /// gas should be 151000
                    0x11, // address of BLS12_PAIRING
                    input, //input offset
                    768, // input size
                    r, // output offset
                    32 // output size
                )
            if iszero(success) { revert(0, 0) }
        }

        return r[0];
    }

    //=========
    // Helpers
    //=========

    function _expandMsgXmd(bytes memory message, bytes memory dst, uint16 lenInBytes)
        internal
        pure
        returns (uint256[] memory)
    {
        // 1.  ell = ceil(len_in_bytes / b_in_bytes)
        // b_in_bytes seems to be 32 for sha256
        // ceil the division
        uint256 ell = (lenInBytes - 1) / 32 + 1;

        // 2.  ABORT if ell > 255 or len_in_bytes > 65535 or len(DST) > 255
        require(ell <= 255, "len_in_bytes too large for sha256");
        // Not really needed because of parameter type
        // require(lenInBytes <= 65535, "len_in_bytes too large");
        // no length normalizing via hashing
        require(dst.length <= 255, "dst too long");

        bytes memory dstPrime = bytes.concat(dst, bytes1(uint8(dst.length)));

        // 4.  Z_pad = I2OSP(0, s_in_bytes)
        // this should be sha256 blocksize so 64 bytes
        bytes memory zPad =
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        // 5.  l_i_b_str = I2OSP(len_in_bytes, 2)
        // length in byte string?
        bytes2 libStr = bytes2(lenInBytes);

        // 6.  msg_prime = Z_pad || msg || l_i_b_str || I2OSP(0, 1) || DST_prime
        bytes memory msgPrime = bytes.concat(zPad, message, libStr, hex"00", dstPrime);

        uint256 b_0;
        uint256[] memory b = new uint256[](ell);

        // 7.  b_0 = H(msg_prime)
        b_0 = uint256(sha256(msgPrime));

        // 8.  b_1 = H(b_0 || I2OSP(1, 1) || DST_prime)
        b[0] = uint256(sha256(bytes.concat(bytes32(b_0), hex"01", dstPrime)));

        // 9.  for i in (2, ..., ell):
        for (uint8 i = 2; i <= ell; i++) {
            // 10.    b_i = H(strxor(b_0, b_(i - 1)) || I2OSP(i, 1) || DST_prime)
            bytes memory tmp = abi.encodePacked(b_0 ^ b[i - 2], i, dstPrime);
            b[i - 1] = uint256(sha256(tmp));
        }
        // 11. uniform_bytes = b_1 || ... || b_ell
        // 12. return substr(uniform_bytes, 0, len_in_bytes)
        // Here we don't need the uniform_bytes because b is already properly formed
        return b;
    }

    function _modfield(uint256 _b1, uint256 _b2) internal view returns (uint256[2] memory r) {
        assembly {
            let bl := 0x40
            let ml := 0x40

            let freemem := mload(0x40) // Free memory pointer is always stored at 0x40

            // arg[0] = base.length @ +0
            mstore(freemem, bl)
            // arg[1] = exp.length @ +0x20
            mstore(add(freemem, 0x20), 0x20)
            // arg[2] = mod.length @ +0x40
            mstore(add(freemem, 0x40), ml)

            // arg[3] = base.bits @ + 0x60
            // places the first 32 bytes of _b1 and the last 32 bytes of _b2
            mstore(add(freemem, 0x60), _b1)
            mstore(add(freemem, 0x80), _b2)

            // arg[4] = exp.bits @ +0x60+base.length
            // exponent always 1
            mstore(add(freemem, 0xa0), 1)

            // arg[5] = mod.bits @ +96+base.length+exp.length
            // this field_modulus as hex 4002409555221667393417789825735904156556882819939007885332058136124031650490837864442687629129015664037894272559787
            // we add the 0 prefix so that the result will be exactly 64 bytes
            // saves 300 gas per call instead of sending it along every time
            // places the first 32 bytes and the last 32 bytes of the field modulus
            mstore(add(freemem, 0xc0), 0x000000000000000000000000000000001a0111ea397fe69a4b1ba7b6434bacd7)
            mstore(add(freemem, 0xe0), 0x64774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab)

            // Invoke contract 0x5, put return value right after mod.length, @ 0x60
            let success :=
                staticcall(
                    sub(gas(), 1350), // gas
                    0x5, // mpdexp precompile
                    freemem, //input offset
                    0x100, // input size  = 0x60+base.length+exp.length+mod.length
                    add(freemem, 0x60), // output offset
                    ml // output size
                )
            if iszero(success) { revert(0, 0) }

            // point to mod length, result was placed immediately after
            r := add(freemem, 0x60)
            //adjust freemem pointer
            mstore(0x40, add(add(freemem, 0x60), ml))
        }
    }

    /**
     * @notice Returns true if `a` is lexicographically greater than `b`
     * @dev It makes the comparison bit-wise.
     * This functions also assumes that the passed values are 48-byte long BLS pub keys that have
     * 16 functional bytes in the first word, and 32 bytes in the second.
     */
    function _greaterThan(uint256[2] memory a, uint256[2] memory b) internal pure returns (bool) {
        uint256 wordA;
        uint256 wordB;
        uint256 mask;

        // Only compare the unequal words
        if (a[0] == b[0]) {
            wordA = a[1];
            wordB = b[1];
            mask = 1 << 255;
        } else {
            wordA = a[0];
            wordB = b[0];
            mask = 1 << 127; // Only check for lower 16 bytes in the first word
        }

        // We may safely set the control value to be less than 256 since it is guaranteed that the
        // the loop returns if the first words are different.
        for (uint256 i; i < 256; ++i) {
            uint256 x = wordA & mask;
            uint256 y = wordB & mask;

            if (x == 0 && y != 0) return false;
            if (x != 0 && y == 0) return true;

            mask = mask >> 1;
        }

        return false;
    }

    function _resolveG2Point(uint256[8] memory flattened) internal pure returns (G2Point memory) {
        return G2Point({
            x: [flattened[0], flattened[1]],
            x_I: [flattened[2], flattened[3]],
            y: [flattened[4], flattened[5]],
            y_I: [flattened[6], flattened[7]]
        });
    }
}
