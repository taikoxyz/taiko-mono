// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.24;

import {RLPReader} from "../thirdparty/optimism/rlp/RLPReader.sol";
import {RLPWriter} from "../thirdparty/optimism/rlp/RLPWriter.sol";
import {SecureMerkleTrie} from "../thirdparty/optimism/trie/SecureMerkleTrie.sol";

import "forge-std/console2.sol";
/**
 * @title LibTrieProof
 */
library LibTrieProof {
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
    ) public view returns (bool verified) {
        (bytes[] memory accountProof, bytes[] memory storageProof) = abi.decode(
            mkproof,
            (bytes[], bytes[])
        );

        /// @dev Previous (OP) version we have from the .get() function (taiko-mono/main branch commit hash: 523f95b2077dbe119f406d635a96376c169723b1) had an exists boolen return value, but in this new format we shall check for empty bytes and if something is wrong, it would revert.
        bytes memory rlpAccount = SecureMerkleTrie.get(
            abi.encodePacked(addr),
            accountProof,
            stateRoot
        );

        console2.log("It seems we stuck before here");
        require(rlpAccount.length != 0, "LTP:invalid account proof");
        console2.log("rlpAccount is:");
        console2.logBytes(rlpAccount);
        RLPReader.RLPItem[] memory accountState = RLPReader.readList(
            rlpAccount
        );

        bytes memory storageRoot = RLPReader.readBytes(
            accountState[ACCOUNT_FIELD_INDEX_STORAGE_HASH]
        );

        verified = SecureMerkleTrie.verifyInclusionProof(
            bytes.concat(slot),
            bytes.concat(value),
            storageProof,
            bytes32(storageRoot)
        );
    }
}
