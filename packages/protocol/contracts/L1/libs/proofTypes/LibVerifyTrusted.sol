// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../../common/AddressResolver.sol";
import {LibUtils} from "../LibUtils.sol";
import {TaikoData} from "../../TaikoData.sol";

library LibVerifyTrusted {
    error L1_INVALID_SGX_SIGNATURE();

    function verifyProof(
        AddressResolver resolver,
        bytes memory proof,
        bytes32 signedMsghash,
        uint16 verifierId
    ) internal view {
        address trustedVerifier = resolver.resolve(
            LibUtils.getVerifierName(verifierId),
            false
        );

        // The signature proof
        bytes memory data = proof;
        uint8 v;
        bytes32 r;
        bytes32 s;
        assembly {
            // Extract a uint8
            v := byte(0, mload(add(data, 32)))
            // Extract the first 32-byte chunk (after the uint8)
            r := mload(add(data, 33))
            // Extract the second 32-byte chunk
            s := mload(add(data, 65))
        }

        if (ecrecover(signedMsghash, v, r, s) != trustedVerifier)
            revert L1_INVALID_SGX_SIGNATURE();
    }
}
