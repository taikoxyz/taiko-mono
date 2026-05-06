/**
 * Copyright 2023 Circle Internet Group, Inc. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity 0.6.12;

import { ECRecover } from "./ECRecover.sol";
import { IERC1271 } from "../interface/IERC1271.sol";

/**
 * @dev Signature verification helper that can be used instead of `ECRecover.recover` to seamlessly support both ECDSA
 * signatures from externally owned accounts (EOAs) as well as ERC1271 signatures from smart contract wallets.
 *
 * Adapted from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/21bb89ef5bfc789b9333eb05e3ba2b7b284ac77c/contracts/utils/cryptography/SignatureChecker.sol
 */
library SignatureChecker {
    /**
     * @dev Checks if a signature is valid for a given signer and data hash. If the signer is a smart contract, the
     * signature is validated against that smart contract using ERC1271, otherwise it's validated using `ECRecover.recover`.
     * @param signer        Address of the claimed signer
     * @param digest        Keccak-256 hash digest of the signed message
     * @param signature     Signature byte array associated with hash
     */
    function isValidSignatureNow(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) external view returns (bool) {
        if (!isContract(signer)) {
            return ECRecover.recover(digest, signature) == signer;
        }
        return isValidERC1271SignatureNow(signer, digest, signature);
    }

    /**
     * @dev Checks if a signature is valid for a given signer and data hash. The signature is validated
     * against the signer smart contract using ERC1271.
     * @param signer        Address of the claimed signer
     * @param digest        Keccak-256 hash digest of the signed message
     * @param signature     Signature byte array associated with hash
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidERC1271SignatureNow(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) internal view returns (bool) {
        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(
                IERC1271.isValidSignature.selector,
                digest,
                signature
            )
        );
        return (success &&
            result.length >= 32 &&
            abi.decode(result, (bytes32)) ==
            bytes32(IERC1271.isValidSignature.selector));
    }

    /**
     * @dev Checks if the input address is a smart contract.
     */
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
