// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title LibBeaconMerkleUtils
/// @dev This library is used specifically for beacon state merkle proofs.
/// @custom:security-contact security@taiko.xyz
library LibBeaconMerkleUtils {
    uint256 internal constant CHUNKS_LENGTH = 8;
    uint256 internal constant TMP_LENGTH = 4;

    function hash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        // TODO: reuse word with assembly
        return sha256(abi.encodePacked(a, b));
    }

    // TODO: use calldata for chunks
    /// @dev This is optimised to merkle-ize 8-chunks of beacon data
    function merkleize(bytes32[CHUNKS_LENGTH] memory chunks) internal pure returns (bytes32) {
        bytes32[] memory tmp = new bytes32[](TMP_LENGTH);

        for (uint256 i; i < CHUNKS_LENGTH; ++i) {
            merge(tmp, i, chunks[i]);
        }

        return tmp[TMP_LENGTH - 1];
    }

    function merge(bytes32[] memory tmp, uint256 index, bytes32 chunk) internal pure {
        bytes32 h = chunk;
        uint256 j = 0;
        while (true) {
            /// forge-lint: disable-next-line(incorrect-shift)
            if (index & 1 << j == 0) {
                break;
            } else {
                h = hash(tmp[j], h);
            }
            j += 1;
        }
        tmp[j] = h;
    }

    function verifyProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 leafIndex
    )
        internal
        pure
        returns (bool)
    {
        bytes32 h = leaf;
        uint256 index = leafIndex;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (index % 2 == 0) {
                h = sha256(bytes.concat(h, proofElement));
            } else {
                h = sha256(bytes.concat(proofElement, h));
            }

            index = index / 2;
        }

        return h == root;
    }

    function toLittleEndian(uint256 n) internal pure returns (bytes32) {
        uint256 v = n;
        v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8)
            | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
        v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16)
            | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
        v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32)
            | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);
        v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64)
            | ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);
        v = (v >> 128) | (v << 128);
        return bytes32(v);
    }
}
