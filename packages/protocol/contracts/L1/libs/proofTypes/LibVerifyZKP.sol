// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../../common/AddressResolver.sol";
import {LibUtils} from "../LibUtils.sol";
import {TaikoData} from "../../TaikoData.sol";

library LibVerifyZKP {

    bytes32 internal constant TAIKO_HASH = keccak256("taiko");

    error L1_INVALID_PROOF();

    function verifyProof(
        AddressResolver resolver,
        bytes memory proof,
        bytes32 inputHash,
        uint16 verifierId
    ) internal view {
        (bool verified, bytes memory ret) = resolver
            .resolve(LibUtils.getVerifierName(verifierId), false)
            .staticcall(bytes.concat(inputHash, proof));

        if (!verified || ret.length != 32 || bytes32(ret) != TAIKO_HASH)
            revert L1_INVALID_PROOF();
    }
}
