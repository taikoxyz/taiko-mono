// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title LibData
/// @notice A library that offers helper functions.
/// @custom:security-contact security@taiko.xyz
library LibData {
    // = keccak256(abi.encode(new TaikoData.EthDeposit[](0)))
    bytes32 internal constant EMPTY_ETH_DEPOSIT_HASH =
        0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;

    error L1_INVALID_DATA_SIZE();

    function blockParamsV1ToV2(TaikoData.BlockParams memory _v1)
        internal
        pure
        returns (TaikoData.BlockParamsV2 memory)
    {
        return TaikoData.BlockParamsV2({
            coinbase: _v1.coinbase,
            extraData: _v1.extraData,
            parentMetaHash: _v1.parentMetaHash,
            anchorBlockId: 0,
            timestamp: 0,
            blobTxListOffset: 0,
            blobTxListLength: 0,
            blobIndex: 0
        });
    }

    function blockMetadataV2toV1(TaikoData.BlockMetadataV2 memory _v2)
        internal
        pure
        returns (TaikoData.BlockMetadata memory)
    {
        return TaikoData.BlockMetadata({
            l1Hash: _v2.anchorBlockHash,
            difficulty: _v2.difficulty,
            blobHash: _v2.blobHash,
            extraData: _v2.extraData,
            depositsHash: EMPTY_ETH_DEPOSIT_HASH,
            coinbase: _v2.coinbase,
            id: _v2.id,
            gasLimit: _v2.gasLimit,
            timestamp: _v2.timestamp,
            l1Height: _v2.anchorBlockId,
            minTier: _v2.minTier,
            blobUsed: _v2.blobUsed,
            parentMetaHash: _v2.parentMetaHash,
            sender: _v2.proposer
        });
    }

    function metadataV1toV2(
        TaikoData.BlockMetadata memory _v1,
        uint96 _livenessBond
    )
        internal
        pure
        returns (TaikoData.BlockMetadataV2 memory)
    {
        return TaikoData.BlockMetadataV2({
            anchorBlockHash: _v1.l1Hash,
            difficulty: _v1.difficulty,
            blobHash: _v1.blobHash,
            extraData: _v1.extraData,
            coinbase: _v1.coinbase,
            id: _v1.id,
            gasLimit: _v1.gasLimit,
            timestamp: _v1.timestamp,
            anchorBlockId: _v1.l1Height,
            minTier: _v1.minTier,
            blobUsed: _v1.blobUsed,
            parentMetaHash: _v1.parentMetaHash,
            proposer: _v1.sender,
            livenessBond: _livenessBond,
            proposedAt: 0,
            proposedIn: 0,
            blobTxListOffset: 0,
            blobTxListLength: 0,
            blobIndex: 0,
            basefeeAdjustmentQuotient: 0,
            basefeeSharingPctg: 0
        });
    }

    function hashMetadata(
        bool postFork,
        TaikoData.BlockMetadataV2 memory _meta
    )
        internal
        pure
        returns (bytes32)
    {
        return postFork
            ? keccak256(abi.encode(_meta)) //
            : keccak256(abi.encode(blockMetadataV2toV1(_meta)));
    }

    function encodeMetadataPacked(TaikoData.BlockMetadataV2 memory metadata_)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory part1 = abi.encodePacked(
            metadata_.anchorBlockHash,
            metadata_.difficulty,
            metadata_.blobHash,
            metadata_.extraData,
            metadata_.coinbase,
            metadata_.id,
            metadata_.gasLimit
        );

        bytes memory part2 = abi.encodePacked(
            metadata_.timestamp,
            metadata_.anchorBlockId,
            metadata_.minTier,
            metadata_.blobUsed,
            metadata_.parentMetaHash,
            metadata_.proposer,
            metadata_.livenessBond
        );

        bytes memory part3 = abi.encodePacked(
            metadata_.proposedAt,
            metadata_.proposedIn,
            metadata_.blobTxListOffset,
            metadata_.blobTxListLength,
            metadata_.blobIndex,
            metadata_.basefeeAdjustmentQuotient,
            metadata_.basefeeSharingPctg
        );

        return bytes.concat(part1, part2, part3);
    }

    function decodeMetadataPacked(bytes calldata _encoded)
        internal
        pure
        returns (TaikoData.BlockMetadataV2 memory metadata_, uint256 offset_)
    {
        if (_encoded.length < 270) revert L1_INVALID_DATA_SIZE();
        unchecked {
            // part 1
            metadata_.anchorBlockHash = bytes32(_encoded[offset_:offset_ + 32]);
            offset_ += 32;
            metadata_.difficulty = bytes32(_encoded[offset_:offset_ + 32]);
            offset_ += 32;
            metadata_.blobHash = bytes32(_encoded[offset_:offset_ + 32]);
            offset_ += 32;
            metadata_.extraData = bytes32(_encoded[offset_:offset_ + 32]);
            offset_ += 32;
            metadata_.coinbase = address(bytes20(_encoded[offset_:offset_ + 20]));
            offset_ += 20;
            metadata_.id = uint64(bytes8(_encoded[offset_:offset_ + 8]));
            offset_ += 8;
            metadata_.gasLimit = uint32(bytes4(_encoded[offset_:offset_ + 4]));

            offset_ += 4;
            // part 2
            metadata_.timestamp = uint64(bytes8(_encoded[offset_:offset_ + 8]));
            offset_ += 8;
            metadata_.anchorBlockId = uint64(bytes8(_encoded[offset_:offset_ + 8]));
            offset_ += 8;
            metadata_.minTier = uint16(bytes2(_encoded[offset_:offset_ + 2]));
            offset_ += 2;
            metadata_.blobUsed = uint8(bytes1(_encoded[offset_:offset_ + 1])) != 0;
            offset_ += 1;
            metadata_.parentMetaHash = bytes32(_encoded[offset_:offset_ + 32]);
            offset_ += 32;
            metadata_.proposer = address(bytes20(_encoded[offset_:offset_ + 20]));
            offset_ += 20;
            metadata_.livenessBond = uint96(bytes12(_encoded[offset_:offset_ + 12]));
            offset_ += 12;

            // part 3
            metadata_.proposedAt = uint64(bytes8(_encoded[offset_:offset_ + 8]));
            offset_ += 8;
            metadata_.proposedIn = uint64(bytes8(_encoded[offset_:offset_ + 8]));
            offset_ += 8;
            metadata_.blobTxListOffset = uint32(bytes4(_encoded[offset_:offset_ + 4]));
            offset_ += 4;
            metadata_.blobTxListLength = uint32(bytes4(_encoded[offset_:offset_ + 4]));
            offset_ += 4;
            metadata_.blobIndex = uint8(bytes1(_encoded[offset_:offset_ + 1]));
            offset_ += 1;
            metadata_.basefeeAdjustmentQuotient = uint8(bytes1(_encoded[offset_:offset_ + 1]));
            offset_ += 1;
            metadata_.basefeeSharingPctg = uint8(bytes1(_encoded[offset_:offset_ + 1]));
            offset_ += 1;
        }
    }
}
