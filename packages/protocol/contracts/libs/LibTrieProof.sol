// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.24;

import "../thirdparty/optimism/rlp/RLPReader.sol";
import "../thirdparty/optimism/rlp/RLPWriter.sol";
import "../thirdparty/optimism/trie/SecureMerkleTrie.sol";

/// @title LibTrieProof
/// @custom:security-contact security@taiko.xyz
library LibTrieProof {
    // The consensus format representing account is RLP encoded in the
    // following order: nonce, balance, storageHash, codeHash.
    uint256 private constant ACCOUNT_FIELD_INDEX_STORAGE_HASH = 2;

    error LTP_INVALID_ACCOUNT_PROOF();
    error LTP_INVALID_INCLUSION_PROOF();

    /// @notice Verifies that the value of a slot in the storage of an account is value.
    ///
    /// @param rootHash The merkle root of state tree or the account tree. If accountProof's length
    /// is zero, it is used as the account's storage root, otherwise it will be used as the state
    /// root.
    /// @param addr The address of contract.
    /// @param slot The slot in the contract.
    /// @param value The value to be verified.
    /// @param accountProof The account proof
    /// @param storageProof The storage proof
    /// @return storageRoot The account's storage root
    function verifyMerkleProof(
        bytes32 rootHash,
        address addr,
        bytes32 slot,
        bytes32 value,
        bytes[] memory accountProof,
        bytes[] memory storageProof
    )
        internal
        pure
        returns (bytes32 storageRoot)
    {
        if (accountProof.length != 0) {
            bytes memory rlpAccount =
                SecureMerkleTrie.get(abi.encodePacked(addr), accountProof, rootHash);

            if (rlpAccount.length == 0) revert LTP_INVALID_ACCOUNT_PROOF();

            RLPReader.RLPItem[] memory accountState = RLPReader.readList(rlpAccount);

            storageRoot =
                bytes32(RLPReader.readBytes(accountState[ACCOUNT_FIELD_INDEX_STORAGE_HASH]));
        } else {
            storageRoot = rootHash;
        }

        bool verified = SecureMerkleTrie.verifyInclusionProof(
            bytes.concat(slot),
            RLPWriter.writeUint(uint256(value)),
            storageProof,
            bytes32(storageRoot)
        );

        if (!verified) revert LTP_INVALID_INCLUSION_PROOF();
    }
}
