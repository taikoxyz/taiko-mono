// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../thirdparty/Lib_EllipticCurve.sol";
import "../thirdparty/Lib_Uint512.sol";
import "hardhat/console.sol";

library LibECDSA {
    // TODO: change to 0x0000777735367b36bC9B61C50022d9D0700dB4Ec
    address public constant TAIKO_GOLDFINGER_ADDRESS =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;
    // TODO: change to 0x92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38
    uint256 public constant TAIKO_GOLDFINGURE_PRIVATEKEY =
        0x0000000000000000000000000000000000000000000000000000000000000001;
    uint256 public constant GX =
        0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 public constant GY =
        0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
    uint256 public constant K = 1;
    uint256 public constant N =
        115792089237316195423570985008687907852837564279074904382605163141518161494337;
    uint256 public constant P =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    function signWithGoldenFinger(bytes memory digest)
        internal
        view
        returns (
            uint8 v,
            uint256 r,
            uint256 s
        )
    {
        require(digest.length == 32, "invalid message digest");

        bytes32 z = bytes32(digest);

        (uint256 x1, uint256 y1) = EllipticCurve.ecMul(K, GX, GY, 0, P);

        r = x1 % N;

        require(r != 0, "invalid r value");

        (uint256 r0, uint256 r1) = Uint512.mul256x256(
            r,
            TAIKO_GOLDFINGURE_PRIVATEKEY
        );

        (r0, r1) = Uint512.add512x512(r0, r1, uint256(z), 0);

        s = expmod(r0, r1, 1, N);

        y1 % 2 == 0 ? v = 0 : v = 1;
        x1 == r ? v |= 0 : v |= 2;

        if (s > N >> 1) {
            s = N - s;
            v ^= 1;
        }

        require(s != 0, "invalid s value");
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
            mstore(p, 0x20) // Length of Base
            mstore(add(p, 0x20), 0x40) // Length of Exponent
            mstore(add(p, 0x40), 0x20) // Length of Modulus
            mstore(add(p, 0x60), baseLow) // BaseLow
            mstore(add(p, 0x80), baseHigh) // BaseHigh
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
