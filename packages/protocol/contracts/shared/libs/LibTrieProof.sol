// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@optimism/packages/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import "@optimism/packages/contracts-bedrock/src/libraries/rlp/RLPWriter.sol";
import "@optimism/packages/contracts-bedrock/src/libraries/trie/SecureMerkleTrie.sol";

/// @title LibTrieProof
/// @custom:security-contact security@taiko.xyz
library LibTrieProof {
    // The consensus format representing account is RLP encoded in the
    // following order: nonce, balance, storageHash, codeHash.
    uint256 private constant _ACCOUNT_FIELD_INDEX_STORAGE_HASH = 2;

    error LTP_INVALID_ACCOUNT_PROOF();
    error LTP_INVALID_INCLUSION_PROOF();

    /// @notice Verifies that the value of a slot in the storage of an account is value,
    /// trying both a primary slot and a fallback slot.
    /// @dev This is used during migration periods where proofs may be generated against
    /// either the old or new slot calculation.
    /// @param _rootHash The merkle root of state tree or the account tree.
    /// @param _addr The address of contract.
    /// @param _slot The primary slot to try first.
    /// @param _fallbackSlot The fallback slot to try if primary fails.
    /// @param _value The value to be verified.
    /// @param _accountProof The account proof
    /// @param _storageProof The storage proof
    /// @return storageRoot_ The account's storage root
    function verifyMerkleProof(
        bytes32 _rootHash,
        address _addr,
        bytes32 _slot,
        bytes32 _fallbackSlot,
        bytes32 _value,
        bytes[] memory _accountProof,
        bytes[] memory _storageProof
    )
        internal
        pure
        returns (bytes32 storageRoot_)
    {
        storageRoot_ = _getStorageRoot(_rootHash, _addr, _accountProof);

        bytes memory encodedValue = RLPWriter.writeUint(uint256(_value));

        // Try primary slot first
        bool verified = SecureMerkleTrie.verifyInclusionProof(
            bytes.concat(_slot), encodedValue, _storageProof, storageRoot_
        );

        // If primary fails, try fallback slot
        if (!verified && _fallbackSlot != bytes32(0)) {
            verified = SecureMerkleTrie.verifyInclusionProof(
                bytes.concat(_fallbackSlot), encodedValue, _storageProof, storageRoot_
            );
        }

        require(verified, LTP_INVALID_INCLUSION_PROOF());
    }

    /// @dev Extracts the storage root from the account proof.
    function _getStorageRoot(
        bytes32 _rootHash,
        address _addr,
        bytes[] memory _accountProof
    )
        private
        pure
        returns (bytes32 storageRoot_)
    {
        if (_accountProof.length != 0) {
            bytes memory rlpAccount =
                SecureMerkleTrie.get(abi.encodePacked(_addr), _accountProof, _rootHash);

            require(rlpAccount.length != 0, LTP_INVALID_ACCOUNT_PROOF());

            RLPReader.RLPItem[] memory accountState = RLPReader.readList(rlpAccount);

            storageRoot_ =
                bytes32(RLPReader.readBytes(accountState[_ACCOUNT_FIELD_INDEX_STORAGE_HASH]));
        } else {
            storageRoot_ = _rootHash;
        }
    }
}
