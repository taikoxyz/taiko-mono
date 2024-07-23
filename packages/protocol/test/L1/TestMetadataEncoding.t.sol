// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../TaikoTest.sol";

contract MyContract {
    function encodeMetadataPacked(TaikoData.BlockMetadataV2 memory metadata_)
        external
        pure
        returns (bytes memory)
    {
        return LibData.encodeMetadataPacked(metadata_);
    }

    function decodeMetadataPacked(bytes calldata _encoded)
        external
        pure
        returns (TaikoData.BlockMetadataV2 memory metadata_, uint256 offset_)
    {
        return LibData.decodeMetadataPacked(_encoded);
    }
}

contract BlockMetadataTest is TaikoTest {
    MyContract public target;

    function setUp() public {
        target = new MyContract();
    }

    function testMetadataEncodeDecode() public {
        TaikoData.BlockMetadataV2 memory m1 = TaikoData.BlockMetadataV2({
            anchorBlockHash: bytes32(uint256(1)),
            difficulty: bytes32(uint256(2)),
            blobHash: bytes32(uint256(3)),
            extraData: bytes32(uint256(4)),
            coinbase: address(0x1234567890123456789012345678901234567890),
            id: 5,
            gasLimit: 6,
            timestamp: 7,
            anchorBlockId: 8,
            minTier: 9,
            blobUsed: true,
            parentMetaHash: bytes32(uint256(10)),
            proposer: address(0x9876543210987654321098765432109876543210),
            livenessBond: 11,
            proposedAt: 12,
            proposedIn: 13,
            blobTxListOffset: 14,
            blobTxListLength: 15,
            blobIndex: 16,
            basefeeAdjustmentQuotient: 17,
            basefeeSharingPctg: 18
        });

        // Encode the struct
        bytes memory encoded = target.encodeMetadataPacked(m1);

        // Ensure the encoded length is correct
        assertEq(encoded.length, 270, "Encoded length should be 270 bytes");

        // Decode the encoded data
        (TaikoData.BlockMetadataV2 memory m2, uint256 offset) = target.decodeMetadataPacked(encoded);

        assertEq(offset, 270, "offset");
        // Compare the original and decoded structs
        assertEq(m2.anchorBlockHash, m1.anchorBlockHash, "anchorBlockHash mismatch");
        assertEq(m2.difficulty, m1.difficulty, "difficulty mismatch");
        assertEq(m2.blobHash, m1.blobHash, "blobHash mismatch");
        assertEq(m2.extraData, m1.extraData, "extraData mismatch");
        assertEq(m2.coinbase, m1.coinbase, "coinbase mismatch");
        assertEq(m2.id, m1.id, "id mismatch");
        assertEq(m2.gasLimit, m1.gasLimit, "gasLimit mismatch");
        assertEq(m2.timestamp, m1.timestamp, "timestamp mismatch");
        assertEq(m2.anchorBlockId, m1.anchorBlockId, "anchorBlockId mismatch");
        assertEq(m2.minTier, m1.minTier, "minTier mismatch");
        assertEq(m2.blobUsed, m1.blobUsed, "blobUsed mismatch");
        assertEq(m2.parentMetaHash, m1.parentMetaHash, "parentMetaHash mismatch");
        assertEq(m2.proposer, m1.proposer, "proposer mismatch");
        assertEq(m2.livenessBond, m1.livenessBond, "livenessBond mismatch");
        assertEq(m2.proposedAt, m1.proposedAt, "proposedAt mismatch");
        assertEq(m2.proposedIn, m1.proposedIn, "proposedIn mismatch");
        assertEq(m2.blobTxListOffset, m1.blobTxListOffset, "blobTxListOffset mismatch");
        assertEq(m2.blobTxListLength, m1.blobTxListLength, "blobTxListLength mismatch");
        assertEq(m2.blobIndex, m1.blobIndex, "blobIndex mismatch");
        assertEq(
            m2.basefeeAdjustmentQuotient,
            m1.basefeeAdjustmentQuotient,
            "basefeeAdjustmentQuotient mismatch"
        );
        assertEq(m2.basefeeSharingPctg, m1.basefeeSharingPctg, "basefeeSharingPctg mismatch");
    }
}
