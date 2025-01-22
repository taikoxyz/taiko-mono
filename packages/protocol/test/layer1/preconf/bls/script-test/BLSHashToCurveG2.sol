// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.24;

import "script/layer1/preconf/BaseScript.sol";
import "src/layer1/preconf/libs/LibBLS12381.sol";

/**
 * @dev At the time of writing this (Sept, 2024) foundry does not support the LibBLS12381
 * precompile,
 * thus
 * a traditional foundry test is not possible for hash to curve functionality. Instead, we test it
 * manually by sending a transaction to a Pectra devnet and verify the outputs on the explorer.
 */
contract BLSHashToCurveG2 is BaseScript {
    function run() external broadcast {
        Target target = new Target();
        target.hashToCurveG2();
    }
}

contract Target {
    bytes internal HASH_TO_G2_DST = "QUUX-V01-CS02-with-LibBLS12381G2_XMD:SHA-256_SSWU_RO_";

    event Output(LibBLS12381.G2Point);

    function hashToCurveG2() external {
        /**
         * Expected output:
         * 0x0000000000000000000000000000000002c2d18e033b960562aae3cab37a27ce00d80ccd5ba4b7fe0e7a210245129dbec7780ccc7954725f4168aff2787776e600000000000000000000000000000000139cddbccdc5e91b9623efd38c49f81a6f83f175e80b06fc374de9eb4b41dfe4ca3a230ed250fbe3a2acf73a41177fd8000000000000000000000000000000001787327b68159716a37440985269cf584bcb1e621d3a7202be6ea05c4cfe244aeb197642555a0645fb87bf7466b2ba480000000000000000000000000000000000aa65dae3c8d732d10ecd2c50f8a1baf3001578f71c694e03866e9f3d49ac1e1ce70dd94a733534f106d4cec0eddd16
         */
        emit Output(LibBLS12381.hashToCurveG2("abc", HASH_TO_G2_DST));
    }
}
