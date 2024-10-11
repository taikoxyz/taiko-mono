// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BLS12381} from "../../libraries/BLS12381.sol";

contract BLSSignatureChecker {
    using BLS12381 for *;

    /// @dev The domain separation tag for the BLS signature
    function dst() internal pure returns (bytes memory) {
        // Set based on the recommendations of RFC9380
        return bytes("Taiko Based Rollup Preconfirmation v0.1.0");
    }

    /**
     * @notice Returns `true` if the BLS signature on the message matches against the public key
     * @param message The message bytes
     * @param sig The BLS signature
     * @param pubkey The BLS public key of the expected signer
     */
    function verifySignature(bytes memory message, BLS12381.G2Point memory sig, BLS12381.G1Point memory pubkey)
        internal
        view
        returns (bool)
    {
        // Hash the message bytes into a G2 point
        BLS12381.G2Point memory msgG2 = message.hashToCurveG2(dst());

        // Return the pairing check that denotes the correctness of the signature
        return BLS12381.pairing(pubkey, msgG2, BLS12381.negGeneratorG1(), sig);
    }
}
