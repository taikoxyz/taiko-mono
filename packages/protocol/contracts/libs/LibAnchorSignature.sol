// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "./LibUint512Math.sol";

/// @author david <david@taiko.xyz>
library LibAnchorSignature {
    address public constant K_GOLDEN_TOUCH_ADDRESS =
        0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
    uint256 public constant K_GOLDEN_TOUCH_PRIVATEKEY =
        0x92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38;

    uint256 public constant GX =
        0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 public constant GY =
        0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    uint256 public constant GX2 =
        0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5;
    uint256 public constant GY2 =
        0x1ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a;

    uint256 public constant N =
        0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;

    // (
    //     uint256 GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW,
    //     uint256 GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH
    // ) = LibUint512Math.mul(GX, K_GOLDEN_TOUCH_PRIVATEKEY);
    uint256 public constant GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW =
        0xb4a95509ce05fe8d45987859a067780d16a367c0e2cacf79cd301b93fb717940;
    uint256 public constant GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH =
        0x45b59254b0320fd853f3f38ac574999e91bd75fd5e6cab9c22c5e71fc6d276e4;

    // (
    //     uint256 GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW,
    //     uint256 GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH
    // ) = LibUint512Math.mul(GX2, K_GOLDEN_TOUCH_PRIVATEKEY);
    uint256 public constant GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW =
        0xad77eceea844778cb4376153fc8f06f12f1695df4585bf75bfb17ec19ce90818;
    uint256 public constant GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH =
        0x71620584f61c57e688bbd3fd7a39a036e588d962c4c830f3dacbc15c917e02f2;

    // Invert K (= 2) in the field F(N)
    uint256 public constant K_2_INVM_N =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1;

    function signTransaction(
        bytes32 digest,
        uint8 k
    ) internal view returns (uint8 v, uint256 r, uint256 s) {
        require(k == 1 || k == 2, "invalid k value");

        r = k == 1 ? GX : GX2;

        uint256 low256 = k == 1
            ? GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW
            : GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_LOW;

        uint256 high256 = k == 1
            ? GX_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH
            : GX2_MUL_GOLDEN_TOUCH_PRIVATEKEY_HIGH;

        (low256, high256) = LibUint512Math.add(
            low256,
            high256,
            uint256(digest),
            0
        );

        if (k == 1) {
            s = expmod(low256, high256, 1, N);
        } else {
            (low256, high256) = LibUint512Math.mul(
                K_2_INVM_N,
                expmod(low256, high256, 1, N)
            );
            s = expmod(low256, high256, 1, N);
        }

        if (s > N >> 1) {
            s = N - s;
            v ^= 1;
        }
    }

    function expmod(
        uint256 baseLow,
        uint256 baseHigh,
        uint256 e,
        uint256 m
    ) internal view returns (uint256 o) {
        assembly {
            // define pointer
            let p := mload(0x40)
            // store data assembly-favouring ways
            mstore(p, 0x40) // Length of Base
            mstore(add(p, 0x20), 0x20) // Length of Exponent
            mstore(add(p, 0x40), 0x20) // Length of Modulus
            mstore(add(p, 0x60), baseHigh) // BaseHigh
            mstore(add(p, 0x80), baseLow) // BaseLow
            mstore(add(p, 0xa0), e) // Exponent
            mstore(add(p, 0xc0), m) // Modulus

            if iszero(staticcall(sub(gas(), 2000), 0x05, p, 0xe0, p, 0x20)) {
                revert(0, 0)
            }
            // data
            o := mload(p)
        }
    }
}
