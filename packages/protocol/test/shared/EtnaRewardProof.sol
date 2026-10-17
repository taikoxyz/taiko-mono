// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@optimism/packages/contracts-bedrock/src/libraries/rlp/RLPWriter.sol";

/// @title EtnaRewardProof
/// @notice Builds a valid single-leaf account and storage proof for shared protocol tests.
library EtnaRewardProof {
    /// @dev Constructs the account and storage proof for one storage slot.
    /// @param _inbox The account address committed in the state trie.
    /// @param _slot The storage slot committed in the storage trie.
    /// @param _value The storage value committed in the storage trie.
    /// @return root_ The state root used to verify the account proof.
    /// @return account_ The single-leaf account proof.
    /// @return storage_ The single-leaf storage proof.
    function _proof(
        address _inbox,
        bytes32 _slot,
        bytes32 _value
    )
        internal
        pure
        returns (bytes32 root_, bytes[] memory account_, bytes[] memory storage_)
    {
        storage_ = new bytes[](1);
        storage_[0] =
            _leaf(keccak256(abi.encodePacked(_slot)), RLPWriter.writeUint(uint256(_value)));

        bytes[] memory fields = new bytes[](4);
        fields[0] = RLPWriter.writeUint(0);
        fields[1] = RLPWriter.writeUint(0);
        fields[2] = RLPWriter.writeBytes(abi.encodePacked(keccak256(storage_[0])));
        fields[3] = RLPWriter.writeBytes(abi.encodePacked(keccak256("")));
        account_ = new bytes[](1);
        account_[0] = _leaf(keccak256(abi.encodePacked(_inbox)), RLPWriter.writeList(fields));
        root_ = keccak256(account_[0]);
    }

    /// @dev RLP-encodes a compact leaf node for a pre-hashed trie key.
    /// @param _key The hashed trie key.
    /// @param _value The RLP-encoded trie value.
    /// @return node_ The RLP-encoded leaf node.
    function _leaf(bytes32 _key, bytes memory _value) private pure returns (bytes memory node_) {
        bytes[] memory parts = new bytes[](2);
        parts[0] = RLPWriter.writeBytes(abi.encodePacked(hex"20", _key));
        parts[1] = RLPWriter.writeBytes(_value);
        return RLPWriter.writeList(parts);
    }
}
