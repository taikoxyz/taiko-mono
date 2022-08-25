// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../thirdparty/Lib_RLPReader.sol";
import "../thirdparty/Lib_RLPWriter.sol";
import "../thirdparty/Lib_SecureMerkleTrie.sol";

/// @author dantaik <dan@taiko.xyz>
library LibMerkleProof {
    /*********************
     * Structs           *
     *********************/

    struct Account {
        uint256 nonce;
        uint256 balance;
        bytes32 storageRoot;
        bytes32 codeHash;
    }

    /*********************
     * Constants         *
     *********************/

    // The consensus format representing account is RLP encoded in the following order:
    // nonce, balance, storageHash, codeHash.
    uint256 private constant ACCOUNT_FIELD_INDEX_STORAGE_HASH = 2;

    /*********************
     * Public Functions  *
     *********************/

    /**
     * @notice Verifies that the value of a slot `key` in the storage tree of `addr` is `value`
     * @param stateRoot The merkle root of state tree.
     * @param addr The contract address.
     * @param account The account
     * @param mkproof The proof obtained by encoding state proof and storage proof.
     */
    function verifyAccount(
        bytes32 stateRoot,
        address addr,
        Account calldata account,
        bytes calldata mkproof
    ) public pure {
        // TODO
    }

    /**
     * @notice Verifies that the value of a slot `key` in the storage tree of `addr` is `value`
     * @param stateRoot The merkle root of state tree.
     * @param addr The contract address.
     * @param key The slot in the contract.
     * @param value The value to be verified.
     * @param mkproof The proof obtained by encoding state proof and storage proof.
     */
    function verifyStorage(
        bytes32 stateRoot,
        address addr,
        bytes32 key,
        bytes32 value,
        bytes calldata mkproof
    ) public pure {
        (bytes memory accountProof, bytes memory storageProof) = abi.decode(
            mkproof,
            (bytes, bytes)
        );

        (bool exists, bytes memory rlpAccount) = Lib_SecureMerkleTrie.get(
            abi.encodePacked(addr),
            accountProof,
            stateRoot
        );

        require(exists, "LTP:invalid account proof");

        Lib_RLPReader.RLPItem[] memory accountState = Lib_RLPReader.readList(
            rlpAccount
        );
        bytes32 storageRoot = Lib_RLPReader.readBytes32(
            accountState[ACCOUNT_FIELD_INDEX_STORAGE_HASH]
        );

        bool verified = Lib_SecureMerkleTrie.verifyInclusionProof(
            abi.encodePacked(key),
            Lib_RLPWriter.writeBytes32(value),
            storageProof,
            storageRoot
        );

        require(verified, "LTP:invalid storage proof");
    }
}
