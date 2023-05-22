// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {TaikoData} from "./TaikoData.sol";
import {AddressResolver} from "../common/AddressResolver.sol";

interface IProofVerifier {
    /**
     * Verifying proof via the ProofVerifier contract
     *
     * @param instance Hashed public input
     * @param blockProofs Proof array
     * @param resolver Current (up-to-date) address resolver
     */
    function verifyProof(
        bytes32 instance, 
        TaikoData.TypedProof[] memory blockProofs,
        AddressResolver resolver
    ) external;
}
