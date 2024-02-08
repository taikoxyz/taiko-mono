// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibRLPReader_old} from "../thirdparty/LibRLPReader_old.sol";
import {LibRLPWriter_old} from "../thirdparty/LibRLPWriter_old.sol";
import {LibSecureMerkleTrie_old} from "../thirdparty/LibSecureMerkleTrie_old.sol";

/**
 * @title LibTrieProof
 */
library LibTrieProof_old {
    /*********************
     * Constants         *
     *********************/

    // The consensus format representing account is RLP encoded in the
    // following order: nonce, balance, storageHash, codeHash.
    uint256 private constant ACCOUNT_FIELD_INDEX_STORAGE_HASH = 2;

    /*********************
     * Public Functions  *
     *********************/

    /**
     * Verifies that the value of a slot in the storage of an account is value.
     *
     * @param stateRoot The merkle root of state tree..
     * @param slot The slot in the contract.
     * @param value The value to be verified.
     * @param mkproof The proof obtained by encoding storage proof.
     * @return verified The verification result.
     */
    function verifyWithAccountProof(
        bytes32 stateRoot,
        address addr,
        bytes32 slot,
        bytes32 value,
        bytes calldata mkproof
    ) public pure returns (bool verified) {
        (bytes memory accountProof, bytes memory storageProof) = abi.decode(
            mkproof,
            (bytes, bytes)
        );

        (bool exists, bytes memory rlpAccount) = LibSecureMerkleTrie_old.get(
            abi.encodePacked(addr),
            accountProof,
            stateRoot
        );

        require(exists, "LTP:invalid account proof");

        LibRLPReader_old.RLPItem[] memory accountState = LibRLPReader_old.readList(
            rlpAccount
        );
        bytes32 storageRoot = LibRLPReader_old.readBytes32(
            accountState[ACCOUNT_FIELD_INDEX_STORAGE_HASH]
        );

        verified = LibSecureMerkleTrie_old.verifyInclusionProof(
            abi.encodePacked(slot),
            LibRLPWriter_old.writeBytes32(value),
            storageProof,
            storageRoot
        );
    }
}
