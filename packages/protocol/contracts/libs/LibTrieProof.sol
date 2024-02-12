// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.24;

import { RLPReader } from "../thirdparty/optimism/rlp/RLPReader.sol";
import { SecureMerkleTrie } from "../thirdparty/optimism/trie/SecureMerkleTrie.sol";
import "forge-std/console2.sol";
/**
 * @title LibTrieProof
 */

library LibTrieProof {
    // The consensus format representing account is RLP encoded in the
    // following order: nonce, balance, storageHash, codeHash.
    uint256 private constant ACCOUNT_FIELD_INDEX_STORAGE_HASH = 2;

    error LTP_INVALID_ACCOUNT_PROOF();
    error LTP_INVALID_STORAGE_PROOF();

    /**
     * Verifies that the value of a slot in the storage of an account is value.
     *
     * @param rootHash The merkle root of state tree.
     * @param addr The address of contract.
     * @param slot The slot in the contract.
     * @param value The value to be verified.
     * @param accountProof The account proof.
     * @param storageProof The storage proof.
     * @return storageRoot The storage root.
     */
    function verifyMerkleProof(
        bytes32 rootHash,
        address addr,
        bytes32 slot,
        bytes memory value,
        bytes[] memory accountProof,
        bytes[] memory storageProof
    )
        internal
        pure
        returns (bytes32 storageRoot)
    {
        if (accountProof.length == 0) {
            storageRoot = rootHash;
        } else {
            bytes memory rlpAccount =
                SecureMerkleTrie.get(abi.encodePacked(addr), accountProof, rootHash);

            if (rlpAccount.length == 0) revert LTP_INVALID_ACCOUNT_PROOF();

            RLPReader.RLPItem[] memory accountState = RLPReader.readList(rlpAccount);

            storageRoot =
                bytes32(RLPReader.readBytes(accountState[ACCOUNT_FIELD_INDEX_STORAGE_HASH]));
        }

        bool verified = SecureMerkleTrie.verifyInclusionProof(
            bytes.concat(slot), value, storageProof, bytes32(storageRoot)
        );

        if (!verified) revert LTP_INVALID_STORAGE_PROOF();
    }
}
