// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibRLPReader } from "../thirdparty/LibRLPReader.sol";
import { LibRLPWriter } from "../thirdparty/LibRLPWriter.sol";
import { LibSecureMerkleTrie } from "../thirdparty/LibSecureMerkleTrie.sol";

/// @title LibTrieProof
/// @dev This library is used for verifying the proof of values within the
/// storage trie of an Ethereum account.
library LibTrieProof {
    // Constant defining the index for the storage hash in the RLP-encoded
    // account structure.
    // It follows the order: nonce, balance, storageHash, codeHash.
    uint256 private constant ACCOUNT_FIELD_INDEX_STORAGE_HASH = 2;

    error INVALID_ACCOUNT_PROOF();

    /// @dev Verifies that the value of a specific slot in the storage of an
    /// account equals the given value.
    /// @param stateRoot The merkle root of the state tree.
    /// @param addr The address of the account.
    /// @param slot The specific slot within the storage of the contract.
    /// @param value The value to be verified against the proof.
    /// @param mkproof The concatenated proof containing both account and
    /// storage proofs.
    /// @return verified Boolean result indicating if the proof is valid.
    function verifyWithFullMerkleProof(
        bytes32 stateRoot,
        address addr,
        bytes32 slot,
        bytes32 value,
        bytes calldata mkproof
    )
        public
        pure
        returns (bool)
    {
        // Decoding the proof into account and storage proofs
        (bytes memory accountProof, bytes memory storageProof) =
            abi.decode(mkproof, (bytes, bytes));

        // Retrieving the RLP-encoded account and verifying existence
        (bool exists, bytes memory rlpAccount) = LibSecureMerkleTrie.get(
            abi.encodePacked(addr), accountProof, stateRoot
        );

        if (!exists) revert INVALID_ACCOUNT_PROOF();

        // Reading the RLP-encoded account into a structured list
        LibRLPReader.RLPItem[] memory accountState =
            LibRLPReader.readList(rlpAccount);
        // Extracting the storage root from the RLP-encoded account
        bytes32 storageRoot = LibRLPReader.readBytes32(
            accountState[ACCOUNT_FIELD_INDEX_STORAGE_HASH]
        );

        // Verifying the inclusion proof for the value within the storage root
        return LibSecureMerkleTrie.verifyInclusionProof(
            abi.encodePacked(slot),
            LibRLPWriter.writeBytes32(value),
            storageProof,
            storageRoot
        );
    }
}
