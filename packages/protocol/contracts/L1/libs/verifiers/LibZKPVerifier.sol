// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

// Taiko System Dependencies
import { AddressResolver } from "../../../common/AddressResolver.sol";
import { LibUtils } from "../LibUtils.sol";
import { TaikoData } from "../../TaikoData.sol";

/**
 * @title LibZKPVerifier Library
 * @notice A library for verifying Zero-Knowledge Proofs (ZKP) in the Taiko
 * system.
 */
library LibZKPVerifier {
    // Custom error to signal an invalid proof.
    error L1_INVALID_PROOF();

    /**
     * @notice Verifies the provided proof using the designated verifier.
     * @param resolver The AddressResolver instance to resolve the verifier's
     * address.
     * @param proof The ZKP to verify.
     * @param verifierId The identifier of the ZKP verifier.
     */
    function verifyProof(
        AddressResolver resolver,
        bytes memory proof,
        uint16 verifierId
    )
        internal
        view
    {
        // Resolve the verifier's name and obtain its address.
        address verifierAddress =
            resolver.resolve(LibUtils.getVerifierName(verifierId), false);

        // Call the verifier contract with the provided proof.
        (bool verified, bytes memory ret) =
            verifierAddress.staticcall(bytes.concat(proof));

        // Check if the proof is valid.
        if (!verified || ret.length != 32 || bytes32(ret) != keccak256("taiko"))
        {
            revert L1_INVALID_PROOF();
        }
    }
}
