// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../common/AddressResolver.sol";
import {Proxied} from "../common/Proxied.sol";
import {TaikoErrors} from "./TaikoErrors.sol";
import {TaikoData} from "./TaikoData.sol";
import {LibVerifyTrusted} from "./libs/proofTypes/LibVerifyTrusted.sol";
import {LibVerifyZKP} from "./libs/proofTypes/LibVerifyZKP.sol";

library TaikoProofToggleMask {
    function getToggleMask() internal pure returns (uint16) {
        // BITMAP for efficient iteration and flexible additions later
        // ZKP_ONLY,            // 0000 0001
        // SGX_ONLY,            // 0000 0010
        // RESERVED_X_ONLY,     // 0000 0100
        // RESERVED_Y_ONLY,     // 0000 1000
        // ZKP_AND_SGX,         // 0000 0011
        // X_ZKP_SGX,           // 0000 0111
        return uint16(1); // ZKP ONLY by default
    }
}

/// @custom:security-contact hello@taiko.xyz
contract ProofVerifier is TaikoErrors {
    uint256[50] private __gap;

    function getToggleMask() public pure virtual returns (uint16) {
        return TaikoProofToggleMask.getToggleMask();
    }

    function verifyProofs(
        bytes32 instance, 
        TaikoData.TypedProof[] calldata blockProofs,
        AddressResolver resolver
    )
    external
    view
    {
        uint16 mask = getToggleMask();
        for (uint16 i; i < blockProofs.length;) {
            TaikoData.TypedProof memory proof = blockProofs[i];
            if (proof.proofType == 0) {
                revert L1_INVALID_PROOFTYPE();
            }

            uint16 bitMask = uint16(1 << (proof.proofType - 1));
            if ((mask & bitMask) == 0) {
                revert L1_NOT_ENABLED_PROOFTYPE();
            }

            verifyTypedProof(proof, instance, resolver);
            mask &= ~bitMask;

            unchecked {
                ++i;
            }
        }

        if(mask != 0) {
            revert L1_NOT_ALL_REQ_PROOF_VERIFIED();
        }
    }

    function verifyTypedProof(
        TaikoData.TypedProof memory proof,
        bytes32 instance,
        AddressResolver resolver
    ) internal view {
        if (proof.proofType == 1) {
            // This is the regular ZK proof and required based on the flag
            // in config.proofToggleMask
            LibVerifyZKP.verifyProof(
                resolver,
                proof.proof,
                instance,
                proof.verifierId
            );
        } else if (proof.proofType == 2) {
            // This is the SGX signature proof and required based on the flag
            // in config.proofToggleMask
            LibVerifyTrusted.verifyProof(
                resolver,
                proof.proof,
                instance,
                proof.verifierId
            );
        }
    }
}

contract ProxiedProofVerifier is Proxied, ProofVerifier {}
