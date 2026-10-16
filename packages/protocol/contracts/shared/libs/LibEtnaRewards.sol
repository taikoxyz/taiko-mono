// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibEtnaRewards
/// @notice Defines canonical identifiers and storage locations for Etna L2 reward receipts.
/// @custom:security-contact security@taiko.xyz
library LibEtnaRewards {
    uint256 internal constant RECEIPTS_SLOT = 283;

    struct Receipt {
        uint256 l1ChainId;
        uint64 l2ChainId;
        address inbox;
        uint64 generation;
        uint64 parentHeight;
        bytes32 parentHash;
        uint64 lastHeight;
        bytes32 lastBlockHash;
        address l2RewardRecipient;
        uint256 baseFeeAmount;
    }

    /// @dev Computes the stable identifier for a contiguous L2 reward batch.
    /// @param _r The receipt whose chain, inbox, generation, and range identify the batch.
    /// @return id_ The canonical batch identifier.
    function batchId(Receipt memory _r) internal pure returns (bytes32 id_) {
        return keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_BATCH_V1"),
                _r.l1ChainId,
                _r.l2ChainId,
                _r.inbox,
                _r.generation,
                _r.parentHeight,
                _r.parentHash,
                _r.lastHeight,
                _r.lastBlockHash
            )
        );
    }

    /// @dev Computes the commitment to a batch identifier, recipient, and reward amount.
    /// @param _r The receipt whose batch, recipient, and amount are committed.
    /// @return hash_ The canonical receipt commitment.
    function commitment(Receipt memory _r) internal pure returns (bytes32 hash_) {
        return keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_RECEIPT_V1"),
                batchId(_r),
                _r.l2RewardRecipient,
                _r.baseFeeAmount
            )
        );
    }

    /// @dev Computes the mapping storage slot for a receipt identifier.
    /// @param _id The canonical receipt identifier.
    /// @return slot_ The storage slot at which the receipt is stored.
    function receiptSlot(bytes32 _id) internal pure returns (bytes32 slot_) {
        return keccak256(abi.encode(_id, RECEIPTS_SLOT));
    }
}
