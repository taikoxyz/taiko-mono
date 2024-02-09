// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.24;

import { RLPReader } from "../thirdparty/optimism/rlp/RLPReader.sol";
import { SecureMerkleTrie } from "../thirdparty/optimism/trie/SecureMerkleTrie.sol";

/**
 * @title LibTrieProof
 */
library LibTrieProof {
    // The consensus format representing account is RLP encoded in the
    // following order: nonce, balance, storageHash, codeHash.
    uint256 private constant ACCOUNT_FIELD_INDEX_STORAGE_HASH = 2;

    /**
     * Verifies that the value of a slot in the storage of an account is value.
     *
     * @param stateRoot The merkle root of state tree.
     * @param addr The address of contract.
     * @param slot The slot in the contract.
     * @param value The value to be verified.
     * @param mkproof The proof obtained by encoding storage proof.
     * @param cachedStorageRoot Cached storage root. If empty, we build it.
     * @return verified The verification result.
     */
    function verifyWithAccountProof(
        bytes32 stateRoot,
        address addr,
        bytes32 slot,
        bytes32 value,
        bytes calldata mkproof,
        bytes calldata cachedStorageRoot
    )
        public
        pure
        returns (bool verified, bytes memory storageRoot)
    {
        (bytes[] memory accountProof, bytes[] memory storageProof) =
            abi.decode(mkproof, (bytes[], bytes[]));

        if (cachedStorageRoot.length == 0) {
            bytes memory rlpAccount =
                SecureMerkleTrie.get(abi.encodePacked(addr), accountProof, stateRoot);

            require(rlpAccount.length != 0, "LTP:invalid account proof");

            RLPReader.RLPItem[] memory accountState = RLPReader.readList(rlpAccount);

            storageRoot = RLPReader.readBytes(accountState[ACCOUNT_FIELD_INDEX_STORAGE_HASH]);
        } else {
            storageRoot = cachedStorageRoot;
        }

        verified = SecureMerkleTrie.verifyInclusionProof(
            bytes.concat(slot), bytes.concat(value), storageProof, bytes32(storageRoot)
        );
    }
}
