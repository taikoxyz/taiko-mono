// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.24;

import {BaseScript} from "script/layer1/preconf/BaseScript.sol";
import {BLS12381} from "src/layer1/preconf/libraries/BLS12381.sol";
import {BLSSignatureChecker} from "src/layer1/preconf/avs/utils/BLSSignatureChecker.sol";

/**
 * @dev At the time of writing this (Sept, 2024) foundry does not support the BLS12381 precompile, thus
 * a traditional foundry test is not possible to verify a signature. Instead, we test it
 * manually by sending a transaction to a Pectra devnet and verify the outputs on the explorer.
 */
contract BLSVerifySignature is BaseScript {
    using BLS12381 for *;

    function run() external broadcast {
        Target target = new Target();
        target.verify();
    }
}

contract Target is BLSSignatureChecker {
    event Output(bool);

    function verify() external {
        BLS12381.G2Point memory sig = BLS12381.G2Point({
            x: [
                0x00000000000000000000000000000000075785f1ffe7faabd27259035731c4ff,
                0x881c38e87fc963a47425ce52f12f18c348370eaea53008bc683206d7770f5bdf
            ],
            x_I: [
                0x0000000000000000000000000000000002f8146bf138cbc35aeeccd4570d121c,
                0x8aec29661e8108e4094dc37b5a499272a6a680f015d0527c312a82457db8b979
            ],
            y: [
                0x000000000000000000000000000000000f5357626a9be51a0e689244b1a28d7b,
                0xe6132ad16f8d1852c2c75804fccf473902a5b8bbe6dd182d04643f34bb34fbe6
            ],
            y_I: [
                0x000000000000000000000000000000000544d2c2834eebb7cfbd5498cc0c328b,
                0x619d482161808b7e27dbb92941df85f704a6218ce9903af72eabdb3dbead70c7
            ]
        });

        BLS12381.G1Point memory pubkey = BLS12381.G1Point({
            x: [
                0x00000000000000000000000000000000101936a69d6fbd2feae29545220ad66e,
                0xb60c3171b8d15de582dd2c645f67cb32377de0c97666e4b4fc7fad8a1c9a81af
            ],
            y: [
                0x00000000000000000000000000000000056cde7adcc8f412efa58ee343569d76,
                0xa95176133a52fbf43979f46c0658010c573c093f3814a5d4dded92b52d197dff
            ]
        });

        /**
         * Expected output using DST as empty string "": 0x0000000000000000000000000000000000000000000000000000000000000001
         */
        emit Output(verifySignature("abc", sig, pubkey));
    }
}
