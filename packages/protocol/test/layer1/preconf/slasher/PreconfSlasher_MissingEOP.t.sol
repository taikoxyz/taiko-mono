// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PreconfSlasherBase.sol";

contract TestPreconfSlasher_MissingEOP is PreconfSlasherBase {
    // Slashing
    // -------------------------------------------------------------------

    function test_slashesWhenLastPreconfedBlockIsMissingEOP()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build preconfirmation commitment with EOP false
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, false);

        // The next batch is proposed in the next preconf window
        _insertNextBatch(2, preconferSlotTimestamp + 1);

        // Slash missing EOP
        uint256 slashedAmount = _slashMissingEOP(commitment, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().missingEOP);
    }

    // Reverts
    // -------------------------------------------------------------------

    function test_revertsWhenPreconfedBlockHeaderIsInvalid()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header with EOP false
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, false);

        // Mess up the preconfed block header
        preconfedBlockHeader.nonce = 0x0000000000000002;

        // Attempt to slash reverts
        _slashMissingEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.InvalidBlockHeader.selector
        );
    }

    function test_revertsWhenEOPIsTrue()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // Attempt to slash reverts
        _slashMissingEOP(commitment, preconfedBlockHeader, IPreconfSlasher.EOPIsPresent.selector);
    }

    function test_revertsWhenBatchMetadataIsInvalid()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP false
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, false);

        // Mess up the batch metadata
        _cachedBatchMetadata.prover = address(1);

        // Attempt to slash reverts
        _slashMissingEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.InvalidBatchMetadata.selector
        );
    }

    function test_revertsWhenBlockIsNotLastInBatch()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP false
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, false);

        // Attempt to slash reverts
        _slashMissingEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.BlockNotLastInBatch.selector
        );
    }

    function test_revertsWhenNextBatchMetadataIsInvalid()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP false
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, false);

        // Insert an extra batch after the preconfed batch
        _insertNextBatch(2, preconferSlotTimestamp);

        // Mess up the next batch metadata
        _cachedNextBatchMetadata.proposedAt = 0;

        // Attempt to slash reverts
        _slashMissingEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.InvalidBatchMetadata.selector
        );
    }

    function test_revertsWhenAnotherBatchIsProposedInTheSamePreconfWindow()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP false
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, false);

        // Insert an extra batch in the same preconf window
        _insertNextBatch(2, preconferSlotTimestamp);

        // Attempt to slash reverts
        _slashMissingEOP(
            commitment,
            preconfedBlockHeader,
            IPreconfSlasher.NextBatchProposedInTheSamePreconfWindow.selector
        );
    }
}
