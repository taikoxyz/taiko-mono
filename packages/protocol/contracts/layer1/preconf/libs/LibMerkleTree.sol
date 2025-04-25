// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Implementation based on https://github.com/eth-fabric/urc/blob/main/src/lib/MerkleTree.sol
// This is required to cloned here due to conflicts between Openzeppelin versions.

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title MerkleTree
 * @dev Implementation of a binary Merkle tree with proof generation and verification
 */
library LibMerkleTree {
    error EmptyLeaves();
    error IndexOutOfBounds();
    error LeavesTooLarge();
    /**
     * @dev Generates a complete Merkle tree from an array of leaves
     * @dev The tree size is limited to 256 leaves
     * @param leaves Array of leaf values
     * @return bytes32 Root hash of the Merkle tree
     */

    function generateTree(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) revert EmptyLeaves();
        if (leaves.length == 1) return leaves[0];
        if (leaves.length > 256) revert LeavesTooLarge();

        uint256 _nextPowerOfTwo = nextPowerOfTwo(leaves.length);
        bytes32[] memory nodes = new bytes32[](_nextPowerOfTwo);

        // Fill leaf nodes
        for (uint256 i = 0; i < leaves.length; i++) {
            nodes[i] = leaves[i];
        }

        // Build up the tree
        uint256 n = _nextPowerOfTwo;
        while (n > 1) {
            for (uint256 i = 0; i < n / 2; i++) {
                nodes[i] = _efficientKeccak256(nodes[2 * i], nodes[2 * i + 1]);
            }
            n = n / 2;
        }

        return nodes[0];
    }

    /**
     * @dev Generates a Merkle proof for a leaf at the given index
     * @param leaves Array of leaf values
     * @param index Index of the leaf to generate proof for
     * @return bytes32[] Array of proof elements
     */
    function generateProof(
        bytes32[] memory leaves,
        uint256 index
    )
        internal
        pure
        returns (bytes32[] memory)
    {
        if (index >= leaves.length) revert IndexOutOfBounds();
        if (leaves.length <= 1) return new bytes32[](0);

        uint256 _nextPowerOfTwo = nextPowerOfTwo(leaves.length);

        // Calculate height of tree (log2 of next power of 2)
        uint256 height = 0;
        uint256 size = _nextPowerOfTwo;
        while (size > 1) {
            height++;
            size /= 2;
        }

        bytes32[] memory nodes = new bytes32[](_nextPowerOfTwo);
        bytes32[] memory proof = new bytes32[](height); // <-- This is the key fix

        // Fill leaf nodes
        for (uint256 i = 0; i < leaves.length; i++) {
            nodes[i] = leaves[i];
        }
        // Fill remaining nodes with zero
        for (uint256 i = leaves.length; i < _nextPowerOfTwo; i++) {
            nodes[i] = bytes32(0);
        }

        uint256 proofIndex = 0;
        uint256 levelSize = _nextPowerOfTwo;
        uint256 currentIndex = index;

        // Build proof level by level
        while (levelSize > 1) {
            uint256 siblingIndex = currentIndex ^ 1; // Get sibling index
            proof[proofIndex++] = nodes[siblingIndex];

            // Calculate next level
            for (uint256 i = 0; i < levelSize / 2; i++) {
                nodes[i] = _efficientKeccak256(nodes[2 * i], nodes[2 * i + 1]);
            }
            levelSize /= 2;
            currentIndex /= 2;
        }

        return proof;
    }

    /**
     * @dev Verifies a Merkle proof for a leaf
     * @param root Root hash of the Merkle tree
     * @param leaf Leaf value being proved
     * @param index Index of the leaf in the tree
     * @param proof Array of proof elements
     * @return bool True if the proof is valid, false otherwise
     */
    function verifyProof(
        bytes32 root,
        bytes32 leaf,
        uint256 index,
        bytes32[] memory proof
    )
        internal
        pure
        returns (bool)
    {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            if (index % 2 == 0) {
                computedHash = _efficientKeccak256(computedHash, proof[i]);
            } else {
                computedHash = _efficientKeccak256(proof[i], computedHash);
            }
            index = index / 2;
        }

        return computedHash == root;
    }

    /**
     * @dev Verifies a Merkle proof for a leaf
     * @param root Root hash of the Merkle tree
     * @param leaf Leaf value being proved
     * @param index Index of the leaf in the tree
     * @param proof Array of proof elements
     * @return bool True if the proof is valid, false otherwise
     */
    function verifyProofCalldata(
        bytes32 root,
        bytes32 leaf,
        uint256 index,
        bytes32[] calldata proof
    )
        internal
        pure
        returns (bool)
    {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            if (index % 2 == 0) {
                computedHash = _efficientKeccak256(computedHash, proof[i]);
            } else {
                computedHash = _efficientKeccak256(proof[i], computedHash);
            }
            index = index / 2;
        }

        return computedHash == root;
    }

    /**
     * @dev Implementation of keccak256(abi.encode(a, b)) that doesn't allocate or expand memory.
     * @dev From
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/Hashes.sol
     */
    function _efficientKeccak256(bytes32 a, bytes32 b) public pure returns (bytes32 value) {
        assembly ("memory-safe") {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev Returns the next power of 2 larger than the input
     * @param x The number to find the next power of 2 for
     * @return The next power of 2
     */
    function nextPowerOfTwo(uint256 x) internal pure returns (uint256) {
        if (x <= 1) return 1;
        return 1 << Math.log2(x, Math.Rounding.Up);
    }
}
